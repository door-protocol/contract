// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SafetyLib} from "../../libraries/SafetyLib.sol";

/**
 * @title ISafetyModule
 * @notice Interface for the SafetyModule contract
 */
interface ISafetyModule {
    // ============ Structs ============

    /**
     * @notice Safety configuration per level
     */
    struct SafetyConfig {
        uint256 minJuniorRatio;        // Minimum Junior ratio in bps
        uint256 maxSeniorDeposit;      // Daily Senior deposit limit
        uint256 seniorTargetAPY;       // Target Senior APY in bps
        bool seniorDepositsEnabled;    // Senior deposits allowed
        bool juniorDepositsEnabled;    // Junior deposits allowed
    }

    // ============ Events ============

    /// @notice Emitted when safety level changes
    event SafetyLevelChanged(
        SafetyLib.SafetyLevel indexed oldLevel,
        SafetyLib.SafetyLevel indexed newLevel
    );

    /// @notice Emitted when configuration is updated
    event ConfigUpdated(SafetyLib.SafetyLevel indexed level);

    /// @notice Emitted when health check is performed
    event HealthCheckPerformed(
        uint256 juniorRatio,
        bool isHealthy,
        bool isCritical
    );

    /// @notice Emitted when Senior deposits are paused
    event SeniorDepositsPaused(string reason);

    /// @notice Emitted when Senior deposits are resumed
    event SeniorDepositsResumed();

    /// @notice Emitted when Junior deposits are paused
    event JuniorDepositsPaused(string reason);

    /// @notice Emitted when Junior deposits are resumed
    event JuniorDepositsResumed();

    /// @notice Emitted when deposit cap is updated
    event DepositCapUpdated(uint256 oldCap, uint256 newCap);

    // ============ Core Functions ============

    /**
     * @notice Update safety level based on current Junior ratio
     * @param juniorRatio Current Junior ratio in basis points
     */
    function updateSafetyLevel(uint256 juniorRatio) external;

    /**
     * @notice Perform a health check and take action if needed
     * @return isHealthy Whether the protocol is in a healthy state
     * @return isCritical Whether the protocol is in a critical state
     */
    function performHealthCheck() external returns (bool isHealthy, bool isCritical);

    // ============ View Functions ============

    /**
     * @notice Get current safety level
     * @return Current SafetyLevel
     */
    function getCurrentLevel() external view returns (SafetyLib.SafetyLevel);

    /**
     * @notice Get current safety configuration
     * @return Current SafetyConfig
     */
    function getCurrentConfig() external view returns (SafetyConfig memory);

    /**
     * @notice Check if deposit is allowed
     * @param isSenior True if Senior deposit
     * @return True if deposit is allowed
     */
    function isDepositAllowed(bool isSenior) external view returns (bool);

    /**
     * @notice Check if a Senior deposit is allowed
     * @param amount The deposit amount
     * @return allowed Whether the deposit is allowed
     * @return reason Reason if not allowed
     */
    function canDepositSenior(uint256 amount) external view returns (bool allowed, string memory reason);

    /**
     * @notice Check if a Junior deposit is allowed
     * @return allowed Whether the deposit is allowed
     * @return reason Reason if not allowed
     */
    function canDepositJunior() external view returns (bool allowed, string memory reason);

    /**
     * @notice Get Senior target APY for current level
     * @return Target APY in basis points
     */
    function getSeniorTargetAPY() external view returns (uint256);

    /**
     * @notice Get minimum Junior ratio for current level
     * @return Minimum ratio in basis points
     */
    function getMinJuniorRatio() external view returns (uint256);

    /**
     * @notice Get current protocol health status
     */
    function getHealthStatus()
        external
        view
        returns (
            bool isHealthy,
            bool isCritical,
            uint256 currentRatio
        );
}
