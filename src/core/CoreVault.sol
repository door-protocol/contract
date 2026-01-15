// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICoreVault} from "./interfaces/ICoreVault.sol";
import {ISeniorTranche, IJuniorTranche} from "../tranches/interfaces/ITranche.sol";
import {IVaultStrategy} from "../strategy/interfaces/IVaultStrategy.sol";
import {IDOORRateOracle} from "../oracle/interfaces/IDOORRateOracle.sol";
import {WaterfallMath} from "../libraries/WaterfallMath.sol";

/**
 * @title CoreVault
 * @notice Central controller for DOOR Protocol
 * @dev Manages waterfall distribution between Senior and Junior tranches
 *
 * Key responsibilities:
 * - Track Senior and Junior principal
 * - Harvest yield from strategy
 * - Distribute via waterfall (Protocol Fee -> Senior -> Junior)
 * - Dynamically adjust Senior rate based on Junior buffer
 * - Enforce safety thresholds
 */
contract CoreVault is ICoreVault, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Roles ============
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant STRATEGY_ROLE = keccak256("STRATEGY_ROLE");

    // ============ Constants ============
    uint256 private constant BASIS_POINTS = 10_000;

    // ============ State Variables ============

    /// @notice The underlying asset (e.g., USDC)
    IERC20 public immutable ASSET;

    /// @notice The Senior tranche vault
    ISeniorTranche public immutable SENIOR_VAULT;

    /// @notice The Junior tranche vault
    IJuniorTranche public immutable JUNIOR_VAULT;

    /// @notice The yield strategy
    IVaultStrategy public strategy;

    /// @notice The rate oracle
    IDOORRateOracle public rateOracle;

    /// @notice Treasury address for protocol fees
    address public treasury;

    /// @notice Total Senior principal registered
    uint256 public seniorPrincipal;

    /// @notice Total Junior principal registered
    uint256 public juniorPrincipal;

    /// @notice Current Senior fixed rate in basis points
    uint256 public override seniorFixedRate;

    /// @notice Base rate for Senior (when healthy)
    uint256 public baseRate;

    /// @notice Minimum rate for Senior (emergency)
    uint256 public minRate;

    /// @notice Protocol fee rate in basis points
    uint256 public protocolFeeRate;

    /// @notice Minimum Junior ratio for healthy state
    uint256 public minJuniorRatio;

    /// @notice Last harvest timestamp
    uint256 public lastHarvestTime;

    /// @notice Current epoch ID
    uint256 public currentEpochId;

    /// @notice Whether protocol is in emergency mode
    bool public emergencyMode;

    /// @notice Whether protocol is initialized
    bool public initialized;

    // ============ Errors ============
    error NotTranche();
    error AlreadyInitialized();
    error NotInitialized();
    error EmergencyModeActive();
    error ZeroAddress();
    error InvalidRate();
    error InvalidFeeRate();

    // ============ Modifiers ============

    modifier onlyTranche() {
        if (msg.sender != address(SENIOR_VAULT) && msg.sender != address(JUNIOR_VAULT)) {
            revert NotTranche();
        }
        _;
    }

    modifier whenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    modifier notEmergency() {
        if (emergencyMode) revert EmergencyModeActive();
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Constructor
     * @param asset_ The underlying asset
     * @param seniorVault_ The Senior vault
     * @param juniorVault_ The Junior vault
     */
    constructor(address asset_, address seniorVault_, address juniorVault_) {
        if (asset_ == address(0) || seniorVault_ == address(0) || juniorVault_ == address(0)) {
            revert ZeroAddress();
        }

        ASSET = IERC20(asset_);
        SENIOR_VAULT = ISeniorTranche(seniorVault_);
        JUNIOR_VAULT = IJuniorTranche(juniorVault_);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        baseRate = 500;           // 5% default
        minRate = 200;            // 2% minimum
        seniorFixedRate = baseRate;
        protocolFeeRate = 100;    // 1% protocol fee
        minJuniorRatio = 1000;    // 10% minimum Junior buffer

        lastHarvestTime = block.timestamp;
    }

    // ============ Initialization ============

    /**
     * @notice Initialize the CoreVault with strategy and oracle
     * @param strategy_ The yield strategy contract
     * @param rateOracle_ The rate oracle contract
     * @param treasury_ The treasury address for fees
     */
    function initialize(
        address strategy_,
        address rateOracle_,
        address treasury_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (initialized) revert AlreadyInitialized();
        if (strategy_ == address(0) || treasury_ == address(0)) revert ZeroAddress();

        strategy = IVaultStrategy(strategy_);
        rateOracle = IDOORRateOracle(rateOracle_);
        treasury = treasury_;
        initialized = true;
    }

    // ============ Principal Management ============

    /**
     * @notice Register new principal deposit from a tranche
     * @param isSenior Whether this is Senior principal
     * @param amount The amount deposited
     */
    function registerPrincipal(
        bool isSenior,
        uint256 amount
    ) external override onlyTranche whenInitialized {
        if (isSenior) {
            seniorPrincipal += amount;
        } else {
            juniorPrincipal += amount;
        }

        _adjustRate();

        emit PrincipalRegistered(isSenior, amount);
    }

    /**
     * @notice Deregister principal withdrawal from a tranche
     * @param isSenior Whether this is Senior principal
     * @param amount The amount withdrawn
     */
    function deregisterPrincipal(
        bool isSenior,
        uint256 amount
    ) external override onlyTranche whenInitialized {
        if (isSenior) {
            seniorPrincipal = seniorPrincipal > amount ? seniorPrincipal - amount : 0;
        } else {
            juniorPrincipal = juniorPrincipal > amount ? juniorPrincipal - amount : 0;
        }

        _adjustRate();

        emit PrincipalDeregistered(isSenior, amount);
    }

    // ============ Harvest & Distribution ============

    /**
     * @notice Harvest yield from strategy and distribute via waterfall
     */
    function harvest()
        external
        override
        nonReentrant
        whenInitialized
        notEmergency
        onlyRole(KEEPER_ROLE)
    {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        if (timeElapsed == 0) return;

        // Get yield from strategy
        uint256 yieldAmount = strategy.harvest();

        // Read principal directly from vaults for accurate tracking
        uint256 currentSeniorPrincipal = SENIOR_VAULT.totalPrincipal();
        uint256 currentJuniorPrincipal = JUNIOR_VAULT.totalPrincipal();

        // Calculate distribution using WaterfallMath
        WaterfallMath.DistributionParams memory params = WaterfallMath.DistributionParams({
            seniorPrincipal: currentSeniorPrincipal,
            juniorPrincipal: currentJuniorPrincipal,
            seniorFixedRate: seniorFixedRate,
            protocolFeeRate: protocolFeeRate,
            timeElapsed: timeElapsed,
            totalProfit: int256(yieldAmount)
        });

        WaterfallMath.DistributionResult memory result = WaterfallMath.calculateDistribution(params);

        // Send protocol fee to treasury
        if (result.protocolFee > 0 && treasury != address(0)) {
            ASSET.safeTransfer(treasury, result.protocolFee);
        }

        // Distribute to Senior
        if (result.seniorYield > 0) {
            ASSET.forceApprove(address(SENIOR_VAULT), result.seniorYield);
            SENIOR_VAULT.addYield(result.seniorYield);
        }

        // Distribute to Junior or slash
        if (result.juniorYield > 0) {
            ASSET.forceApprove(address(JUNIOR_VAULT), result.juniorYield);
            JUNIOR_VAULT.addYield(result.juniorYield);
        } else if (result.juniorSlash > 0) {
            uint256 actualSlash = JUNIOR_VAULT.slashPrincipal(result.juniorSlash);

            // If we got funds back from slashing, send to Senior
            if (actualSlash > 0 && result.seniorYield > yieldAmount) {
                uint256 fromSlash = result.seniorYield - yieldAmount;
                if (fromSlash > 0) {
                    ASSET.forceApprove(address(SENIOR_VAULT), fromSlash);
                    SENIOR_VAULT.addYield(fromSlash);
                }
            }
        }

        // Check if Senior was not fully paid - emergency mode
        if (!result.seniorFullyPaid) {
            emergencyMode = true;
            emit EmergencyModeActivated("Senior obligation not met");
        }

        lastHarvestTime = block.timestamp;
        currentEpochId++;

        _adjustRate();

        emit YieldDistributed(
            currentEpochId,
            yieldAmount,
            result.seniorYield,
            result.juniorYield,
            result.juniorSlash,
            result.protocolFee
        );
    }

    // ============ Rate Management ============

    /**
     * @notice Adjust Senior rate based on Junior buffer
     */
    function _adjustRate() internal {
        uint256 newRate = WaterfallMath.calculateDynamicRate(
            seniorPrincipal,
            juniorPrincipal,
            baseRate,
            minRate
        );

        if (newRate != seniorFixedRate) {
            seniorFixedRate = newRate;
            SENIOR_VAULT.setFixedRate(newRate);
            emit SeniorRateUpdated(newRate, currentEpochId);
        }
    }

    /**
     * @notice Sync Senior rate from oracle
     */
    function syncSeniorRateFromOracle() external onlyRole(KEEPER_ROLE) whenInitialized {
        if (address(rateOracle) == address(0)) return;

        uint256 oracleRate = rateOracle.calculateSeniorRate();
        if (oracleRate > 0) {
            baseRate = oracleRate;
            _adjustRate();
        }
    }

    /**
     * @notice Set base rate manually
     * @param newBaseRate The new base rate
     */
    function setBaseRate(uint256 newBaseRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newBaseRate == 0 || newBaseRate > 2000) revert InvalidRate();
        baseRate = newBaseRate;
        _adjustRate();
    }

    /**
     * @notice Set minimum rate
     * @param newMinRate The new minimum rate
     */
    function setMinRate(uint256 newMinRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMinRate == 0 || newMinRate > baseRate) revert InvalidRate();
        minRate = newMinRate;
        _adjustRate();
    }

    /**
     * @notice Set protocol fee rate
     * @param newFeeRate The new fee rate
     */
    function setProtocolFeeRate(uint256 newFeeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newFeeRate > 500) revert InvalidFeeRate(); // Max 5%
        protocolFeeRate = newFeeRate;
        emit ProtocolFeeUpdated(newFeeRate);
    }

    /**
     * @notice Set minimum Junior ratio
     * @param newRatio The new minimum ratio
     */
    function setMinJuniorRatio(uint256 newRatio) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRatio > 5000) revert InvalidRate(); // Max 50%
        minJuniorRatio = newRatio;
        emit MinJuniorRatioUpdated(newRatio);
    }

    // ============ Strategy Management ============

    /**
     * @notice Deploy funds to strategy
     * @param amount The amount to deploy
     */
    function deployToStrategy(uint256 amount) external onlyRole(STRATEGY_ROLE) whenInitialized {
        ASSET.forceApprove(address(strategy), amount);
        strategy.deposit(amount);
    }

    /**
     * @notice Withdraw funds from strategy
     * @param amount The amount to withdraw
     */
    function withdrawFromStrategy(uint256 amount) external onlyRole(STRATEGY_ROLE) whenInitialized {
        strategy.withdraw(amount);
    }

    // ============ Emergency Functions ============

    /**
     * @notice Disable emergency mode
     */
    function disableEmergencyMode() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = false;
    }

    /**
     * @notice Emergency withdraw all funds
     */
    function emergencyWithdraw() external onlyRole(EMERGENCY_ROLE) {
        emergencyMode = true;
        emit EmergencyModeActivated("Manual emergency withdrawal");

        // Withdraw all from strategy
        uint256 strategyBalance = strategy.totalAssets();
        if (strategyBalance > 0) {
            strategy.withdraw(strategyBalance);
        }

        // Transfer all to treasury
        uint256 balance = ASSET.balanceOf(address(this));
        if (balance > 0 && treasury != address(0)) {
            ASSET.safeTransfer(treasury, balance);
        }
    }

    // ============ View Functions ============

    /**
     * @notice Get current protocol statistics
     */
    function getStats()
        external
        view
        override
        returns (
            uint256 _seniorPrincipal,
            uint256 _juniorPrincipal,
            uint256 totalAssets,
            uint256 currentSeniorRate,
            uint256 juniorRatio,
            bool isHealthy
        )
    {
        // Read directly from vaults for accurate principal tracking
        _seniorPrincipal = SENIOR_VAULT.totalPrincipal();
        _juniorPrincipal = JUNIOR_VAULT.totalPrincipal();
        totalAssets = _seniorPrincipal + _juniorPrincipal;
        currentSeniorRate = seniorFixedRate;

        if (totalAssets > 0) {
            juniorRatio = (_juniorPrincipal * BASIS_POINTS) / totalAssets;
        }

        (isHealthy, ) = WaterfallMath.checkHealth(_juniorPrincipal, _seniorPrincipal, minJuniorRatio);
    }

    /**
     * @notice Get the current Junior ratio
     * @return The Junior ratio in basis points
     */
    function getJuniorRatio() external view override returns (uint256) {
        uint256 _seniorPrincipal = SENIOR_VAULT.totalPrincipal();
        uint256 _juniorPrincipal = JUNIOR_VAULT.totalPrincipal();
        return WaterfallMath.calculateJuniorRatio(_seniorPrincipal, _juniorPrincipal);
    }

    /**
     * @notice Get the Senior vault address
     */
    function seniorVault() external view override returns (address) {
        return address(SENIOR_VAULT);
    }

    /**
     * @notice Get the Junior vault address
     */
    function juniorVault() external view override returns (address) {
        return address(JUNIOR_VAULT);
    }

    /**
     * @notice Get expected Senior yield for a time period
     * @param timeElapsed The time period in seconds
     */
    function expectedSeniorYield(uint256 timeElapsed) external view returns (uint256) {
        return WaterfallMath.calculateSeniorObligation(seniorPrincipal, seniorFixedRate, timeElapsed);
    }

    /**
     * @notice Get current Junior leverage
     */
    function juniorLeverage() external view returns (uint256) {
        return WaterfallMath.calculateLeverage(seniorPrincipal, juniorPrincipal);
    }
}
