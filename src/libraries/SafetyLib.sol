// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title SafetyLib
 * @notice Library for safety calculations and Junior buffer management
 * @dev Provides 5-level safety classification and related utilities
 */
library SafetyLib {
    uint256 private constant BASIS_POINTS = 10_000;

    /**
     * @notice Safety levels based on Junior buffer ratio
     */
    enum SafetyLevel {
        HEALTHY,   // >= 20%
        CAUTION,   // 15-20%
        WARNING,   // 10-15%
        DANGER,    // 5-10%
        CRITICAL   // < 5%
    }

    /**
     * @notice Safety thresholds in basis points
     */
    uint256 private constant HEALTHY_THRESHOLD = 2000;   // 20%
    uint256 private constant CAUTION_THRESHOLD = 1500;   // 15%
    uint256 private constant WARNING_THRESHOLD = 1000;   // 10%
    uint256 private constant DANGER_THRESHOLD = 500;     // 5%

    /**
     * @notice Calculate safety level based on Junior ratio
     * @param juniorRatio Junior ratio in basis points
     * @return The corresponding SafetyLevel
     */
    function calculateSafetyLevel(uint256 juniorRatio) internal pure returns (SafetyLevel) {
        if (juniorRatio >= HEALTHY_THRESHOLD) return SafetyLevel.HEALTHY;
        if (juniorRatio >= CAUTION_THRESHOLD) return SafetyLevel.CAUTION;
        if (juniorRatio >= WARNING_THRESHOLD) return SafetyLevel.WARNING;
        if (juniorRatio >= DANGER_THRESHOLD) return SafetyLevel.DANGER;
        return SafetyLevel.CRITICAL;
    }

    /**
     * @notice Check if Senior deposits should be allowed based on safety level
     * @param level Current safety level
     * @return True if Senior deposits are allowed
     */
    function isSeniorDepositAllowed(SafetyLevel level) internal pure returns (bool) {
        return level != SafetyLevel.DANGER && level != SafetyLevel.CRITICAL;
    }

    /**
     * @notice Check if Junior deposits should be allowed based on safety level
     * @param level Current safety level
     * @return True if Junior deposits are allowed
     */
    function isJuniorDepositAllowed(SafetyLevel level) internal pure returns (bool) {
        return level != SafetyLevel.CRITICAL;
    }

    /**
     * @notice Get recommended Senior target APY based on safety level
     * @param level Current safety level
     * @return Target APY in basis points
     */
    function getRecommendedSeniorAPY(SafetyLevel level) internal pure returns (uint256) {
        if (level == SafetyLevel.HEALTHY) return 600;   // 6%
        if (level == SafetyLevel.CAUTION) return 550;   // 5.5%
        if (level == SafetyLevel.WARNING) return 500;   // 5%
        if (level == SafetyLevel.DANGER) return 400;    // 4%
        return 300; // 3% for CRITICAL
    }

    /**
     * @notice Get maximum Senior deposit limit based on safety level
     * @param level Current safety level
     * @param defaultLimit Default limit when no restriction
     * @return Maximum deposit amount (0 means deposits disabled)
     */
    function getMaxSeniorDeposit(SafetyLevel level, uint256 defaultLimit) internal pure returns (uint256) {
        if (level == SafetyLevel.HEALTHY || level == SafetyLevel.CAUTION) {
            return defaultLimit;
        }
        if (level == SafetyLevel.WARNING) {
            return 100_000e6; // $100K limit
        }
        return 0; // Disabled for DANGER and CRITICAL
    }

    /**
     * @notice Calculate the minimum Junior principal needed to maintain a target ratio
     * @param seniorPrincipal Current or projected Senior principal
     * @param targetRatio Target Junior ratio in basis points
     * @return Minimum Junior principal needed
     */
    function calculateMinJuniorPrincipal(
        uint256 seniorPrincipal,
        uint256 targetRatio
    ) internal pure returns (uint256) {
        if (targetRatio >= BASIS_POINTS) return type(uint256).max;
        return (targetRatio * seniorPrincipal) / (BASIS_POINTS - targetRatio);
    }

    /**
     * @notice Calculate the maximum Senior principal allowed for a given Junior principal
     * @param juniorPrincipal Current Junior principal
     * @param minJuniorRatio Minimum Junior ratio in basis points
     * @return Maximum Senior principal allowed
     */
    function calculateMaxSeniorPrincipal(
        uint256 juniorPrincipal,
        uint256 minJuniorRatio
    ) internal pure returns (uint256) {
        if (minJuniorRatio == 0) return type(uint256).max;
        return (juniorPrincipal * (BASIS_POINTS - minJuniorRatio)) / minJuniorRatio;
    }

    /**
     * @notice Get the threshold for a specific safety level
     * @param level The safety level
     * @return The threshold in basis points
     */
    function getThreshold(SafetyLevel level) internal pure returns (uint256) {
        if (level == SafetyLevel.HEALTHY) return HEALTHY_THRESHOLD;
        if (level == SafetyLevel.CAUTION) return CAUTION_THRESHOLD;
        if (level == SafetyLevel.WARNING) return WARNING_THRESHOLD;
        if (level == SafetyLevel.DANGER) return DANGER_THRESHOLD;
        return 0;
    }

    /**
     * @notice Check if safety level is critical (requires immediate action)
     * @param level The safety level
     * @return True if critical
     */
    function isCritical(SafetyLevel level) internal pure returns (bool) {
        return level == SafetyLevel.CRITICAL;
    }

    /**
     * @notice Check if safety level requires caution (warnings enabled)
     * @param level The safety level
     * @return True if requires caution
     */
    function requiresCaution(SafetyLevel level) internal pure returns (bool) {
        return level >= SafetyLevel.CAUTION;
    }
}
