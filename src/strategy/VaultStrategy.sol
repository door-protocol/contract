// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IVaultStrategy} from "./interfaces/IVaultStrategy.sol";

/**
 * @title VaultStrategy
 * @notice Multi-asset yield strategy for DOOR Protocol
 * @dev Manages allocation across mETH, USDC, and RWA assets
 *
 * Features:
 * - 3-asset allocation (mETH, USDC, RWA)
 * - Automatic rebalancing
 * - Configurable allocation ratios
 * - Yield harvesting
 */
contract VaultStrategy is IVaultStrategy, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Roles ============
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    // ============ Constants ============
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant REBALANCE_THRESHOLD = 500; // 5% deviation triggers rebalance

    // ============ State Variables ============

    /// @notice The base asset (USDC)
    IERC20 public immutable ASSET;

    /// @notice The mETH token
    IERC20 public immutable METH;

    /// @notice Target allocation ratios
    Allocation public targetAllocation;

    /// @notice Total assets deployed
    uint256 public totalDeployed;

    /// @notice mETH holdings
    uint256 public mEthBalance;

    /// @notice USDC holdings (in lending/yield)
    uint256 public usdcBalance;

    /// @notice RWA holdings
    uint256 public rwaBalance;

    /// @notice Pending yield to harvest
    uint256 public pendingYield;

    /// @notice Last harvest timestamp
    uint256 public lastHarvestTime;

    /// @notice Simulated APY for each asset (for testing)
    uint256 public mEthApy;
    uint256 public usdcApy;
    uint256 public rwaApy;

    /// @notice CoreVault address
    address public coreVault;

    // ============ Events ============
    event StrategyInitialized(address indexed coreVault);
    event ApyUpdated(uint256 mEthApy, uint256 usdcApy, uint256 rwaApy);

    // ============ Errors ============
    error NotCoreVault();
    error AlreadyInitialized();
    error NotInitialized();
    error ZeroAddress();
    error InvalidAllocation();
    error InsufficientBalance();

    // ============ Modifiers ============

    modifier onlyCoreVault() {
        if (msg.sender != coreVault) revert NotCoreVault();
        _;
    }

    // ============ Constructor ============

    constructor(address asset_, address meth_) {
        if (asset_ == address(0) || meth_ == address(0)) revert ZeroAddress();

        ASSET = IERC20(asset_);
        METH = IERC20(meth_);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);

        // Default allocation: 60% mETH, 30% USDC, 10% RWA
        targetAllocation = Allocation({mEthRatio: 6000, usdcRatio: 3000, rwaRatio: 1000});

        // Default APYs for simulation
        mEthApy = 450;  // 4.5%
        usdcApy = 600;  // 6%
        rwaApy = 800;   // 8%

        lastHarvestTime = block.timestamp;
    }

    // ============ Initialization ============

    /**
     * @notice Initialize the strategy with CoreVault
     * @param coreVault_ The CoreVault address
     */
    function initialize(address coreVault_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (coreVault != address(0)) revert AlreadyInitialized();
        if (coreVault_ == address(0)) revert ZeroAddress();

        coreVault = coreVault_;
        _grantRole(VAULT_ROLE, coreVault_);

        emit StrategyInitialized(coreVault_);
    }

    // ============ Core Functions ============

    /**
     * @notice Deposit assets into the strategy
     * @param amount The amount to deposit
     */
    function deposit(uint256 amount) external override onlyRole(VAULT_ROLE) nonReentrant {
        ASSET.safeTransferFrom(msg.sender, address(this), amount);
        totalDeployed += amount;

        // Allocate according to target ratios
        uint256 toMeth = (amount * targetAllocation.mEthRatio) / BASIS_POINTS;
        uint256 toUsdc = (amount * targetAllocation.usdcRatio) / BASIS_POINTS;
        uint256 toRwa = amount - toMeth - toUsdc;

        mEthBalance += toMeth;
        usdcBalance += toUsdc;
        rwaBalance += toRwa;

        emit AssetsDeposited(amount);
    }

    /**
     * @notice Withdraw assets from the strategy
     * @param amount The amount to withdraw
     * @return The actual amount withdrawn
     */
    function withdraw(uint256 amount) external override onlyRole(VAULT_ROLE) nonReentrant returns (uint256) {
        uint256 available = ASSET.balanceOf(address(this));
        uint256 toWithdraw = amount > available ? available : amount;

        if (toWithdraw > totalDeployed) {
            toWithdraw = totalDeployed;
        }

        // Reduce balances proportionally
        uint256 ratio = (toWithdraw * BASIS_POINTS) / totalDeployed;
        mEthBalance = mEthBalance - (mEthBalance * ratio) / BASIS_POINTS;
        usdcBalance = usdcBalance - (usdcBalance * ratio) / BASIS_POINTS;
        rwaBalance = rwaBalance - (rwaBalance * ratio) / BASIS_POINTS;

        totalDeployed -= toWithdraw;

        ASSET.safeTransfer(msg.sender, toWithdraw);

        emit AssetsWithdrawn(toWithdraw);
        return toWithdraw;
    }

    /**
     * @notice Harvest accrued yield
     * @return yieldAmount The amount of yield harvested
     */
    function harvest() external override onlyRole(VAULT_ROLE) nonReentrant returns (uint256 yieldAmount) {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        if (timeElapsed == 0) return 0;

        // Calculate yield from each asset class
        uint256 mEthYield = (mEthBalance * mEthApy * timeElapsed) / (365 days * BASIS_POINTS);
        uint256 usdcYield = (usdcBalance * usdcApy * timeElapsed) / (365 days * BASIS_POINTS);
        uint256 rwaYield = (rwaBalance * rwaApy * timeElapsed) / (365 days * BASIS_POINTS);

        yieldAmount = mEthYield + usdcYield + rwaYield + pendingYield;
        pendingYield = 0;
        lastHarvestTime = block.timestamp;

        if (yieldAmount > 0) {
            // In production, this would come from actual protocol rewards
            // For testing, we assume the yield is already available
            uint256 available = ASSET.balanceOf(address(this));
            if (yieldAmount > available) {
                yieldAmount = available;
            }

            ASSET.safeTransfer(msg.sender, yieldAmount);
            emit YieldHarvested(yieldAmount);
        }
    }

    /**
     * @notice Execute rebalancing
     */
    function rebalance() external override onlyRole(KEEPER_ROLE) nonReentrant {
        if (!needsRebalancing()) return;

        uint256 total = mEthBalance + usdcBalance + rwaBalance;
        if (total == 0) return;

        // Calculate new target balances
        uint256 targetMeth = (total * targetAllocation.mEthRatio) / BASIS_POINTS;
        uint256 targetUsdc = (total * targetAllocation.usdcRatio) / BASIS_POINTS;
        uint256 targetRwa = total - targetMeth - targetUsdc;

        // Update balances (simplified - in production would involve actual swaps)
        mEthBalance = targetMeth;
        usdcBalance = targetUsdc;
        rwaBalance = targetRwa;

        emit Rebalanced(mEthBalance, usdcBalance, rwaBalance, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get current asset allocation
     */
    function getCurrentAllocation() external view override returns (Allocation memory) {
        uint256 total = mEthBalance + usdcBalance + rwaBalance;
        if (total == 0) {
            return Allocation({mEthRatio: 0, usdcRatio: 0, rwaRatio: 0});
        }

        return
            Allocation({
                mEthRatio: (mEthBalance * BASIS_POINTS) / total,
                usdcRatio: (usdcBalance * BASIS_POINTS) / total,
                rwaRatio: (rwaBalance * BASIS_POINTS) / total
            });
    }

    /**
     * @notice Get target asset allocation
     */
    function getTargetAllocation() external view override returns (Allocation memory) {
        return targetAllocation;
    }

    /**
     * @notice Check if rebalancing is needed
     */
    function needsRebalancing() public view override returns (bool) {
        uint256 total = mEthBalance + usdcBalance + rwaBalance;
        if (total == 0) return false;

        uint256 currentMethRatio = (mEthBalance * BASIS_POINTS) / total;
        uint256 currentUsdcRatio = (usdcBalance * BASIS_POINTS) / total;
        uint256 currentRwaRatio = (rwaBalance * BASIS_POINTS) / total;

        uint256 mEthDev = _absDiff(currentMethRatio, targetAllocation.mEthRatio);
        uint256 usdcDev = _absDiff(currentUsdcRatio, targetAllocation.usdcRatio);
        uint256 rwaDev = _absDiff(currentRwaRatio, targetAllocation.rwaRatio);

        return mEthDev > REBALANCE_THRESHOLD || usdcDev > REBALANCE_THRESHOLD || rwaDev > REBALANCE_THRESHOLD;
    }

    /**
     * @notice Get total assets under management
     */
    function totalAssets() external view override returns (uint256) {
        return mEthBalance + usdcBalance + rwaBalance + pendingYield;
    }

    /**
     * @notice Calculate expected weighted APY
     */
    function calculateExpectedApy() external view override returns (uint256) {
        uint256 weightedApy = (mEthApy * targetAllocation.mEthRatio +
            usdcApy * targetAllocation.usdcRatio +
            rwaApy * targetAllocation.rwaRatio) / BASIS_POINTS;

        return weightedApy;
    }

    /**
     * @notice Get pending yield to be harvested
     */
    function getPendingYield() external view override returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        if (timeElapsed == 0) return pendingYield;

        uint256 mEthYield = (mEthBalance * mEthApy * timeElapsed) / (365 days * BASIS_POINTS);
        uint256 usdcYield = (usdcBalance * usdcApy * timeElapsed) / (365 days * BASIS_POINTS);
        uint256 rwaYield = (rwaBalance * rwaApy * timeElapsed) / (365 days * BASIS_POINTS);

        return mEthYield + usdcYield + rwaYield + pendingYield;
    }

    // ============ Admin Functions ============

    /**
     * @notice Set target allocation
     */
    function setTargetAllocation(Allocation calldata newAllocation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAllocation.mEthRatio + newAllocation.usdcRatio + newAllocation.rwaRatio != BASIS_POINTS) {
            revert InvalidAllocation();
        }

        targetAllocation = newAllocation;
        emit AllocationUpdated(newAllocation.mEthRatio, newAllocation.usdcRatio, newAllocation.rwaRatio);
    }

    /**
     * @notice Set simulated APYs (for testing)
     */
    function setApys(uint256 mEth, uint256 usdc, uint256 rwa) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mEthApy = mEth;
        usdcApy = usdc;
        rwaApy = rwa;
        emit ApyUpdated(mEth, usdc, rwa);
    }

    /**
     * @notice Add manual yield (for testing)
     */
    function addManualYield(uint256 amount) external onlyRole(KEEPER_ROLE) {
        pendingYield += amount;
    }

    // ============ Internal Functions ============

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}
