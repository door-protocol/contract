// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ISafetyModule} from "./interfaces/ISafetyModule.sol";
import {ICoreVault} from "../core/interfaces/ICoreVault.sol";
import {SafetyLib} from "../libraries/SafetyLib.sol";

/**
 * @title SafetyModule
 * @notice Safety mechanisms for DOOR Protocol
 * @dev Monitors protocol health and enforces safety thresholds with 5-level system
 *
 * Features:
 * - 5-level safety classification (HEALTHY to CRITICAL)
 * - Junior ratio monitoring
 * - Deposit caps enforcement
 * - Auto-pause on critical state
 * - Health reporting
 */
contract SafetyModule is ISafetyModule, AccessControl {
    using SafetyLib for uint256;

    // ============ Roles ============
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // ============ State Variables ============

    /// @notice The CoreVault contract
    ICoreVault public immutable CORE_VAULT;

    /// @notice Current safety level
    SafetyLib.SafetyLevel public currentLevel;

    /// @notice Configuration per safety level
    mapping(SafetyLib.SafetyLevel => SafetyConfig) public levelConfigs;

    /// @notice Maximum Senior TVL cap (0 = no cap)
    uint256 public seniorDepositCap;

    /// @notice Whether Senior deposits are paused
    bool public seniorDepositsPaused;

    /// @notice Whether Junior deposits are paused
    bool public juniorDepositsPaused;

    /// @notice Auto-pause Senior on critical ratio
    bool public autoPauseEnabled;

    // ============ Errors ============
    error InvalidThreshold();
    error DepositsArePaused();
    error DepositCapExceeded();

    // ============ Constructor ============

    constructor(address coreVault_) {
        CORE_VAULT = ICoreVault(coreVault_);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KEEPER_ROLE, msg.sender);

        currentLevel = SafetyLib.SafetyLevel.HEALTHY;
        autoPauseEnabled = true;

        // Initialize level configurations
        _initializeLevelConfigs();
    }

    /**
     * @notice Initialize default configurations for each safety level
     */
    function _initializeLevelConfigs() internal {
        // HEALTHY: >= 20% Junior ratio
        levelConfigs[SafetyLib.SafetyLevel.HEALTHY] = SafetyConfig({
            minJuniorRatio: 2000,
            maxSeniorDeposit: type(uint256).max,
            seniorTargetAPY: 600, // 6%
            seniorDepositsEnabled: true,
            juniorDepositsEnabled: true
        });

        // CAUTION: 15-20% Junior ratio
        levelConfigs[SafetyLib.SafetyLevel.CAUTION] = SafetyConfig({
            minJuniorRatio: 1500,
            maxSeniorDeposit: type(uint256).max,
            seniorTargetAPY: 550, // 5.5%
            seniorDepositsEnabled: true,
            juniorDepositsEnabled: true
        });

        // WARNING: 10-15% Junior ratio
        levelConfigs[SafetyLib.SafetyLevel.WARNING] = SafetyConfig({
            minJuniorRatio: 1000,
            maxSeniorDeposit: 100_000e6, // $100K limit
            seniorTargetAPY: 500, // 5%
            seniorDepositsEnabled: true,
            juniorDepositsEnabled: true
        });

        // DANGER: 5-10% Junior ratio
        levelConfigs[SafetyLib.SafetyLevel.DANGER] = SafetyConfig({
            minJuniorRatio: 500,
            maxSeniorDeposit: 0, // No new Senior deposits
            seniorTargetAPY: 400, // 4%
            seniorDepositsEnabled: false,
            juniorDepositsEnabled: true
        });

        // CRITICAL: < 5% Junior ratio
        levelConfigs[SafetyLib.SafetyLevel.CRITICAL] = SafetyConfig({
            minJuniorRatio: 0,
            maxSeniorDeposit: 0,
            seniorTargetAPY: 300, // 3%
            seniorDepositsEnabled: false,
            juniorDepositsEnabled: false
        });
    }

    // ============ Core Functions ============

    /**
     * @notice Update safety level based on current Junior ratio
     * @param juniorRatio Current Junior ratio in basis points
     */
    function updateSafetyLevel(uint256 juniorRatio) external override onlyRole(KEEPER_ROLE) {
        SafetyLib.SafetyLevel newLevel = SafetyLib.calculateSafetyLevel(juniorRatio);

        if (newLevel != currentLevel) {
            SafetyLib.SafetyLevel oldLevel = currentLevel;
            currentLevel = newLevel;

            // Auto-pause on critical if enabled
            if (autoPauseEnabled && SafetyLib.isCritical(newLevel)) {
                seniorDepositsPaused = true;
                juniorDepositsPaused = true;
            }

            emit SafetyLevelChanged(oldLevel, newLevel);
        }
    }

    /**
     * @notice Perform a health check and take action if needed
     */
    function performHealthCheck()
        external
        override
        onlyRole(KEEPER_ROLE)
        returns (bool isHealthy, bool isCritical)
    {
        (bool healthy, bool critical, uint256 currentRatio) = _getHealthStatus();

        if (critical && autoPauseEnabled && !seniorDepositsPaused) {
            seniorDepositsPaused = true;
            emit SeniorDepositsPaused("Critical junior ratio");
        }

        // Update safety level
        SafetyLib.SafetyLevel newLevel = SafetyLib.calculateSafetyLevel(currentRatio);
        if (newLevel != currentLevel) {
            emit SafetyLevelChanged(currentLevel, newLevel);
            currentLevel = newLevel;
        }

        emit HealthCheckPerformed(currentRatio, healthy, critical);

        return (healthy, critical);
    }

    // ============ View Functions ============

    /**
     * @notice Get current safety level
     */
    function getCurrentLevel() external view override returns (SafetyLib.SafetyLevel) {
        return currentLevel;
    }

    /**
     * @notice Get current safety configuration
     */
    function getCurrentConfig() external view override returns (SafetyConfig memory) {
        return levelConfigs[currentLevel];
    }

    /**
     * @notice Check if deposit is allowed
     */
    function isDepositAllowed(bool isSenior) external view override returns (bool) {
        if (isSenior) {
            return !seniorDepositsPaused && levelConfigs[currentLevel].seniorDepositsEnabled;
        } else {
            return !juniorDepositsPaused && levelConfigs[currentLevel].juniorDepositsEnabled;
        }
    }

    /**
     * @notice Check if a Senior deposit is allowed
     */
    function canDepositSenior(
        uint256 amount
    ) external view override returns (bool allowed, string memory reason) {
        if (seniorDepositsPaused) {
            return (false, "Senior deposits paused");
        }

        SafetyConfig memory config = levelConfigs[currentLevel];

        if (!config.seniorDepositsEnabled) {
            return (false, "Senior deposits disabled at current safety level");
        }

        // Get stats once for all checks
        (uint256 seniorPrincipal, uint256 juniorPrincipal, , , , ) = CORE_VAULT.getStats();

        if (seniorDepositCap > 0) {
            if (seniorPrincipal + amount > seniorDepositCap) {
                return (false, "Deposit cap exceeded");
            }
        }

        if (config.maxSeniorDeposit > 0 && amount > config.maxSeniorDeposit) {
            return (false, "Amount exceeds max deposit for current safety level");
        }

        // Check if deposit would make ratio unhealthy
        uint256 newSeniorPrincipal = seniorPrincipal + amount;
        uint256 totalPrincipal = newSeniorPrincipal + juniorPrincipal;

        if (totalPrincipal > 0) {
            uint256 newJuniorRatio = (juniorPrincipal * 10_000) / totalPrincipal;
            if (newJuniorRatio < config.minJuniorRatio) {
                return (false, "Would make junior ratio too low");
            }
        }

        return (true, "");
    }

    /**
     * @notice Check if a Junior deposit is allowed
     */
    function canDepositJunior() external view override returns (bool allowed, string memory reason) {
        if (juniorDepositsPaused) {
            return (false, "Junior deposits paused");
        }

        if (!levelConfigs[currentLevel].juniorDepositsEnabled) {
            return (false, "Junior deposits disabled at current safety level");
        }

        return (true, "");
    }

    /**
     * @notice Get Senior target APY for current level
     */
    function getSeniorTargetAPY() external view override returns (uint256) {
        return levelConfigs[currentLevel].seniorTargetAPY;
    }

    /**
     * @notice Get minimum Junior ratio for current level
     */
    function getMinJuniorRatio() external view override returns (uint256) {
        return levelConfigs[currentLevel].minJuniorRatio;
    }

    /**
     * @notice Get current protocol health status
     */
    function getHealthStatus()
        external
        view
        override
        returns (bool isHealthy, bool isCritical, uint256 currentRatio)
    {
        return _getHealthStatus();
    }

    /**
     * @notice Calculate required Junior deposit to reach target ratio
     * @param targetRatio Target Junior ratio in basis points
     */
    function calculateRequiredJuniorDeposit(uint256 targetRatio) external view returns (uint256) {
        (uint256 seniorPrincipal, uint256 juniorPrincipal, , , , ) = CORE_VAULT.getStats();

        if (seniorPrincipal == 0) return 0;

        uint256 totalPrincipal = seniorPrincipal + juniorPrincipal;
        uint256 numerator;

        if (targetRatio * totalPrincipal > juniorPrincipal * 10_000) {
            numerator = targetRatio * totalPrincipal - juniorPrincipal * 10_000;
            return numerator / (10_000 - targetRatio);
        }

        return 0;
    }

    // ============ Internal Functions ============

    function _getHealthStatus()
        internal
        view
        returns (bool isHealthy, bool isCritical, uint256 currentRatio)
    {
        currentRatio = _getCurrentJuniorRatio();
        SafetyLib.SafetyLevel level = SafetyLib.calculateSafetyLevel(currentRatio);
        isHealthy = level == SafetyLib.SafetyLevel.HEALTHY || level == SafetyLib.SafetyLevel.CAUTION;
        isCritical = SafetyLib.isCritical(level);
    }

    function _getCurrentJuniorRatio() internal view returns (uint256) {
        (uint256 seniorPrincipal, uint256 juniorPrincipal, , , , ) = CORE_VAULT.getStats();

        uint256 totalPrincipal = seniorPrincipal + juniorPrincipal;
        if (totalPrincipal == 0) return 10_000;

        return (juniorPrincipal * 10_000) / totalPrincipal;
    }

    // ============ Admin Functions ============

    /**
     * @notice Pause Senior deposits
     */
    function pauseSeniorDeposits(string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        seniorDepositsPaused = true;
        emit SeniorDepositsPaused(reason);
    }

    /**
     * @notice Resume Senior deposits
     */
    function resumeSeniorDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        seniorDepositsPaused = false;
        emit SeniorDepositsResumed();
    }

    /**
     * @notice Pause Junior deposits
     */
    function pauseJuniorDeposits(string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        juniorDepositsPaused = true;
        emit JuniorDepositsPaused(reason);
    }

    /**
     * @notice Resume Junior deposits
     */
    function resumeJuniorDeposits() external onlyRole(DEFAULT_ADMIN_ROLE) {
        juniorDepositsPaused = false;
        emit JuniorDepositsResumed();
    }

    /**
     * @notice Set Senior deposit cap
     */
    function setSeniorDepositCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldCap = seniorDepositCap;
        seniorDepositCap = newCap;
        emit DepositCapUpdated(oldCap, newCap);
    }

    /**
     * @notice Enable/disable auto pause
     */
    function setAutoPause(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        autoPauseEnabled = enabled;
    }

    /**
     * @notice Update configuration for a specific safety level
     */
    function setLevelConfig(
        SafetyLib.SafetyLevel level,
        SafetyConfig calldata config
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        levelConfigs[level] = config;
        emit ConfigUpdated(level);
    }
}
