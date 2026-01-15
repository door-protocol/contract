// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IEpochManager} from "./interfaces/IEpochManager.sol";
import {ICoreVault} from "../core/interfaces/ICoreVault.sol";
import {ISeniorTranche, IJuniorTranche} from "../tranches/interfaces/ITranche.sol";

/**
 * @title EpochManager
 * @notice Manages epoch-based deposits and withdrawals with penalties
 * @dev Implements a weekly epoch system for better liquidity management
 *
 * Key features:
 * - Weekly epochs (configurable)
 * - Queued withdrawals processed at epoch end
 * - Early withdrawal penalty (distributed to remaining users)
 * - Lock period enforcement
 */
contract EpochManager is IEpochManager, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Roles ============
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // ============ Constants ============
    uint256 public constant DEFAULT_EPOCH_DURATION = 7 days;
    uint256 public constant BASIS_POINTS = 10_000;

    // ============ State Variables ============

    /// @notice The underlying asset
    IERC20 public immutable ASSET;

    /// @notice The CoreVault contract
    ICoreVault public immutable CORE_VAULT;

    /// @notice The Senior vault
    ISeniorTranche public immutable SENIOR_VAULT;

    /// @notice The Junior vault
    IJuniorTranche public immutable JUNIOR_VAULT;

    /// @notice Current epoch duration
    uint256 public epochDuration;

    /// @notice Early withdrawal penalty in basis points (100 = 1%)
    uint256 public earlyWithdrawPenalty;

    /// @notice Current epoch ID
    uint256 public override currentEpochId;

    /// @notice Mapping of epoch ID to epoch data
    mapping(uint256 => Epoch) public epochs;

    /// @notice Mapping of user to their withdrawal requests
    mapping(address => WithdrawRequest[]) public userWithdrawRequests;

    /// @notice All pending withdrawal requests for current epoch
    WithdrawRequest[] public pendingWithdrawals;

    /// @notice Accumulated penalties to distribute
    uint256 public accumulatedPenalties;

    /// @notice Whether the manager is initialized
    bool public initialized;

    // ============ Errors ============
    error AlreadyInitialized();
    error NotInitialized();
    error EpochNotEnded();
    error EpochNotOpen();
    error EpochNotLocked();
    error InvalidPenalty();
    error InsufficientShares();
    error NoSharesRequested();
    error InvalidDuration();

    // ============ Modifiers ============

    modifier whenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Constructor
     * @param asset_ The underlying asset
     * @param coreVault_ The CoreVault contract
     * @param seniorVault_ The Senior vault
     * @param juniorVault_ The Junior vault
     */
    constructor(
        address asset_,
        address coreVault_,
        address seniorVault_,
        address juniorVault_
    ) {
        ASSET = IERC20(asset_);
        CORE_VAULT = ICoreVault(coreVault_);
        SENIOR_VAULT = ISeniorTranche(seniorVault_);
        JUNIOR_VAULT = IJuniorTranche(juniorVault_);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);

        epochDuration = DEFAULT_EPOCH_DURATION;
        earlyWithdrawPenalty = 100; // 1% default penalty
    }

    // ============ Initialization ============

    /**
     * @notice Initialize and start the first epoch
     */
    function initialize() external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (initialized) revert AlreadyInitialized();

        initialized = true;
        _startNewEpoch();
    }

    // ============ View Functions ============

    /**
     * @notice Get the current epoch state
     */
    function getCurrentState() external view override returns (EpochState) {
        return epochs[currentEpochId].state;
    }

    /**
     * @notice Get epoch data
     */
    function getEpoch(uint256 epochId) external view override returns (Epoch memory) {
        return epochs[epochId];
    }

    /**
     * @notice Get the duration of a specific epoch
     */
    function getEpochDuration(uint256) external view override returns (uint256) {
        return epochDuration;
    }

    /**
     * @notice Get time until next epoch
     */
    function timeUntilNextEpoch() external view override returns (uint256) {
        Epoch storage currentEpoch = epochs[currentEpochId];
        if (block.timestamp >= currentEpoch.endTime) return 0;
        return currentEpoch.endTime - block.timestamp;
    }

    /**
     * @notice Get user's pending withdrawal requests
     */
    function getUserWithdrawRequests(address user) external view returns (WithdrawRequest[] memory) {
        return userWithdrawRequests[user];
    }

    /**
     * @notice Get number of pending withdrawals
     */
    function pendingWithdrawalsCount() external view returns (uint256) {
        return pendingWithdrawals.length;
    }

    /**
     * @notice Calculate early withdrawal penalty amount
     */
    function calculatePenalty(bool isSenior, uint256 shares) external view returns (uint256) {
        uint256 assets;
        if (isSenior) {
            assets = SENIOR_VAULT.previewRedeem(shares);
        } else {
            assets = JUNIOR_VAULT.previewRedeem(shares);
        }
        return (assets * earlyWithdrawPenalty) / BASIS_POINTS;
    }

    // ============ User Functions ============

    /**
     * @notice Request a withdrawal for the next epoch
     * @param isSenior Whether withdrawing from Senior vault
     * @param shares Number of shares to withdraw
     */
    function requestWithdraw(
        bool isSenior,
        uint256 shares
    ) external override nonReentrant whenInitialized {
        if (shares == 0) revert NoSharesRequested();
        if (epochs[currentEpochId].state != EpochState.OPEN) revert EpochNotOpen();

        // Check user has enough shares
        uint256 userShares = isSenior
            ? SENIOR_VAULT.balanceOf(msg.sender)
            : JUNIOR_VAULT.balanceOf(msg.sender);

        if (shares > userShares) revert InsufficientShares();

        // Create withdrawal request
        WithdrawRequest memory request = WithdrawRequest({
            user: msg.sender,
            isSenior: isSenior,
            shares: shares,
            epochId: currentEpochId,
            processed: false
        });

        pendingWithdrawals.push(request);
        userWithdrawRequests[msg.sender].push(request);

        // Update epoch stats
        epochs[currentEpochId].totalWithdrawRequests += shares;

        emit WithdrawRequested(msg.sender, currentEpochId, isSenior, shares);
    }

    /**
     * @notice Early withdraw with penalty
     * @param isSenior Whether withdrawing from Senior vault
     * @param shares Number of shares to withdraw
     * @return assets The amount of assets received after penalty
     */
    function earlyWithdraw(
        bool isSenior,
        uint256 shares
    ) external override nonReentrant whenInitialized returns (uint256 assets) {
        if (shares == 0) revert NoSharesRequested();

        // Check user has enough shares
        uint256 userShares = isSenior
            ? SENIOR_VAULT.balanceOf(msg.sender)
            : JUNIOR_VAULT.balanceOf(msg.sender);

        if (shares > userShares) revert InsufficientShares();

        // Calculate assets before penalty
        uint256 assetsBeforePenalty;
        if (isSenior) {
            assetsBeforePenalty = SENIOR_VAULT.previewRedeem(shares);
        } else {
            assetsBeforePenalty = JUNIOR_VAULT.previewRedeem(shares);
        }

        // Calculate penalty
        uint256 penalty = (assetsBeforePenalty * earlyWithdrawPenalty) / BASIS_POINTS;
        assets = assetsBeforePenalty - penalty;

        // Process the withdrawal
        if (isSenior) {
            IERC20(address(SENIOR_VAULT)).safeTransferFrom(msg.sender, address(this), shares);
            SENIOR_VAULT.redeem(shares, address(this), address(this));
        } else {
            IERC20(address(JUNIOR_VAULT)).safeTransferFrom(msg.sender, address(this), shares);
            JUNIOR_VAULT.redeem(shares, address(this), address(this));
        }

        // Accumulate penalty for distribution
        accumulatedPenalties += penalty;

        // Transfer assets (minus penalty) to user
        ASSET.safeTransfer(msg.sender, assets);

        emit EarlyWithdraw(msg.sender, isSenior, assets, penalty);
    }

    // ============ Epoch Management ============

    /**
     * @notice Lock the current epoch
     * @param epochId Epoch ID to lock
     */
    function lockEpoch(uint256 epochId) external override onlyRole(KEEPER_ROLE) whenInitialized {
        Epoch storage epoch = epochs[epochId];
        if (epoch.state != EpochState.OPEN) revert EpochNotOpen();

        epoch.state = EpochState.LOCKED;
        emit EpochLocked(epochId, block.timestamp);
    }

    /**
     * @notice Settle an epoch after yield distribution
     * @param epochId The epoch ID to settle
     */
    function settleEpoch(uint256 epochId) external override onlyRole(KEEPER_ROLE) whenInitialized {
        Epoch storage epoch = epochs[epochId];
        if (epoch.state != EpochState.LOCKED) revert EpochNotLocked();

        // Harvest yield
        CORE_VAULT.harvest();

        // Process withdrawals
        _processWithdrawals();

        // Distribute penalties
        _distributePenalties();

        epoch.state = EpochState.SETTLED;
        epoch.settled = true;

        emit EpochSettled(epochId, 0);
    }

    /**
     * @notice Process the current epoch and start a new one
     */
    function processEpoch() external override nonReentrant whenInitialized onlyRole(KEEPER_ROLE) {
        Epoch storage currentEpoch = epochs[currentEpochId];

        // Check if epoch has ended
        if (block.timestamp < currentEpoch.endTime) revert EpochNotEnded();

        // Harvest yield before processing
        CORE_VAULT.harvest();

        // Process all pending withdrawals
        _processWithdrawals();

        // Distribute accumulated penalties
        _distributePenalties();

        // Mark epoch as settled
        currentEpoch.state = EpochState.SETTLED;
        currentEpoch.settled = true;

        emit EpochSettled(currentEpochId, 0);

        // Start new epoch
        _startNewEpoch();
    }

    // ============ Internal Functions ============

    /**
     * @notice Start a new epoch
     */
    function _startNewEpoch() internal {
        currentEpochId++;

        epochs[currentEpochId] = Epoch({
            id: currentEpochId,
            startTime: block.timestamp,
            endTime: block.timestamp + epochDuration,
            state: EpochState.OPEN,
            totalDeposits: 0,
            totalWithdrawRequests: 0,
            settled: false
        });

        // Clear pending withdrawals array
        delete pendingWithdrawals;

        emit EpochStarted(currentEpochId, block.timestamp, block.timestamp + epochDuration);
    }

    /**
     * @notice Process all pending withdrawals
     */
    function _processWithdrawals() internal {
        for (uint256 i = 0; i < pendingWithdrawals.length; i++) {
            WithdrawRequest storage request = pendingWithdrawals[i];

            if (request.processed) continue;

            if (request.isSenior) {
                uint256 userShares = SENIOR_VAULT.balanceOf(request.user);
                uint256 sharesToRedeem = request.shares > userShares ? userShares : request.shares;

                if (sharesToRedeem > 0) {
                    SENIOR_VAULT.redeem(sharesToRedeem, request.user, request.user);
                }
            } else {
                uint256 userShares = JUNIOR_VAULT.balanceOf(request.user);
                uint256 sharesToRedeem = request.shares > userShares ? userShares : request.shares;

                if (sharesToRedeem > 0) {
                    JUNIOR_VAULT.redeem(sharesToRedeem, request.user, request.user);
                }
            }

            request.processed = true;
        }
    }

    /**
     * @notice Distribute accumulated penalties to remaining users
     */
    function _distributePenalties() internal {
        if (accumulatedPenalties == 0) return;

        uint256 totalPenalties = accumulatedPenalties;
        accumulatedPenalties = 0;

        // Distribute proportionally to Senior and Junior vaults based on TVL
        uint256 seniorTVL = SENIOR_VAULT.totalAssets();
        uint256 juniorTVL = JUNIOR_VAULT.totalAssets();
        uint256 totalTVL = seniorTVL + juniorTVL;

        if (totalTVL == 0) {
            accumulatedPenalties = totalPenalties;
            return;
        }

        uint256 seniorShare = (totalPenalties * seniorTVL) / totalTVL;
        uint256 juniorShare = totalPenalties - seniorShare;

        if (seniorShare > 0) {
            ASSET.forceApprove(address(SENIOR_VAULT), seniorShare);
            SENIOR_VAULT.addYield(seniorShare);
        }

        if (juniorShare > 0) {
            ASSET.forceApprove(address(JUNIOR_VAULT), juniorShare);
            JUNIOR_VAULT.addYield(juniorShare);
        }

        emit PenaltyDistributed(totalPenalties);
    }

    // ============ Admin Functions ============

    /**
     * @notice Set epoch duration
     * @param newDuration New epoch duration in seconds
     */
    function setEpochDuration(uint256 newDuration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newDuration < 1 days || newDuration > 30 days) revert InvalidDuration();
        epochDuration = newDuration;
    }

    /**
     * @notice Set early withdrawal penalty
     * @param newPenalty New penalty in basis points
     */
    function setEarlyWithdrawPenalty(uint256 newPenalty) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newPenalty > 1000) revert InvalidPenalty(); // Max 10%
        earlyWithdrawPenalty = newPenalty;
    }
}
