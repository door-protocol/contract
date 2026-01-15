// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title WaterfallMath
 * @notice Library for calculating waterfall distribution between Senior and Junior tranches
 * @dev Implements the core distribution logic with protocol fee and dynamic rate support
 *
 * Waterfall Priority:
 * 1. Protocol fee from total yield
 * 2. Senior receives fixed yield
 * 3. If sufficient: Junior receives remaining
 * 4. If insufficient: Junior principal is slashed to cover Senior
 */
library WaterfallMath {
    uint256 private constant YEAR = 365 days;
    uint256 private constant BASIS_POINTS = 10_000;

    /// @notice Result of waterfall distribution calculation
    struct DistributionResult {
        uint256 protocolFee;
        uint256 seniorYield;
        uint256 juniorYield;
        uint256 juniorSlash;
        bool seniorFullyPaid;
    }

    /// @notice Parameters for distribution calculation
    struct DistributionParams {
        uint256 seniorPrincipal;
        uint256 juniorPrincipal;
        uint256 seniorFixedRate;
        uint256 protocolFeeRate;
        uint256 timeElapsed;
        int256 totalProfit;
    }

    /**
     * @notice Calculate the waterfall distribution
     * @param params The distribution parameters
     * @return result The distribution result
     */
    function calculateDistribution(
        DistributionParams memory params
    ) internal pure returns (DistributionResult memory result) {
        // Handle zero or negative profit
        if (params.totalProfit <= 0) {
            return _handleLossScenario(params, result);
        }

        uint256 totalYield = uint256(params.totalProfit);

        // 1. Calculate protocol fee (from total yield)
        result.protocolFee = (totalYield * params.protocolFeeRate) / BASIS_POINTS;
        uint256 distributable = totalYield - result.protocolFee;

        // 2. Calculate Senior obligation
        uint256 seniorObligation = calculateSeniorObligation(
            params.seniorPrincipal,
            params.seniorFixedRate,
            params.timeElapsed
        );

        // 3. Waterfall distribution
        if (distributable >= seniorObligation) {
            // Normal scenario: Senior gets full target, Junior gets remainder
            result.seniorYield = seniorObligation;
            result.juniorYield = distributable - seniorObligation;
            result.seniorFullyPaid = true;
        } else {
            // Shortfall scenario
            uint256 deficit = seniorObligation - distributable;

            if (params.juniorPrincipal >= deficit) {
                // Junior covers the deficit
                result.seniorYield = seniorObligation;
                result.juniorSlash = deficit;
                result.seniorFullyPaid = true;
            } else {
                // Junior cannot fully cover
                result.seniorYield = distributable + params.juniorPrincipal;
                result.juniorSlash = params.juniorPrincipal;
                result.seniorFullyPaid = false;
            }
        }
    }

    /**
     * @notice Handle loss scenario (negative or zero profit)
     */
    function _handleLossScenario(
        DistributionParams memory params,
        DistributionResult memory result
    ) internal pure returns (DistributionResult memory) {
        uint256 loss = params.totalProfit < 0 ? uint256(-params.totalProfit) : 0;
        uint256 seniorObligation = calculateSeniorObligation(
            params.seniorPrincipal,
            params.seniorFixedRate,
            params.timeElapsed
        );

        uint256 totalDeficit = seniorObligation + loss;

        if (params.juniorPrincipal >= totalDeficit) {
            result.seniorYield = seniorObligation;
            result.juniorSlash = totalDeficit;
            result.seniorFullyPaid = true;
        } else {
            result.seniorYield = params.juniorPrincipal > loss ? params.juniorPrincipal - loss : 0;
            result.juniorSlash = params.juniorPrincipal;
            result.seniorFullyPaid = false;
        }

        return result;
    }

    /**
     * @notice Calculate the Senior obligation (fixed yield owed)
     * @param principal The Senior principal
     * @param fixedRate The fixed rate in basis points
     * @param timeElapsed The time elapsed in seconds
     * @return The obligation amount
     */
    function calculateSeniorObligation(
        uint256 principal,
        uint256 fixedRate,
        uint256 timeElapsed
    ) internal pure returns (uint256) {
        if (principal == 0 || fixedRate == 0 || timeElapsed == 0) {
            return 0;
        }
        return (principal * fixedRate * timeElapsed) / (YEAR * BASIS_POINTS);
    }

    /**
     * @notice Calculate dynamic Senior rate based on Junior buffer
     * @dev Lower Junior ratio = higher risk = lower Senior rate
     * @param seniorPrincipal The Senior principal
     * @param juniorPrincipal The Junior principal
     * @param baseRate The base rate in basis points
     * @param minRate The minimum rate in basis points
     * @return adjustedRate The adjusted rate in basis points
     */
    function calculateDynamicRate(
        uint256 seniorPrincipal,
        uint256 juniorPrincipal,
        uint256 baseRate,
        uint256 minRate
    ) internal pure returns (uint256 adjustedRate) {
        if (seniorPrincipal == 0 && juniorPrincipal == 0) {
            return baseRate;
        }

        uint256 totalPrincipal = seniorPrincipal + juniorPrincipal;
        uint256 juniorRatio = (juniorPrincipal * BASIS_POINTS) / totalPrincipal;

        // Rate adjustment tiers:
        // >= 20% Junior: Full rate (100%)
        // 15-20% Junior: 90% of rate
        // 10-15% Junior: 80% of rate
        // 5-10% Junior: 60% of rate
        // < 5% Junior: Minimum rate
        if (juniorRatio >= 2000) {
            adjustedRate = baseRate;
        } else if (juniorRatio >= 1500) {
            adjustedRate = (baseRate * 90) / 100;
        } else if (juniorRatio >= 1000) {
            adjustedRate = (baseRate * 80) / 100;
        } else if (juniorRatio >= 500) {
            adjustedRate = (baseRate * 60) / 100;
        } else {
            adjustedRate = minRate;
        }

        // Ensure we don't go below minimum
        if (adjustedRate < minRate) {
            adjustedRate = minRate;
        }
    }

    /**
     * @notice Calculate Junior leverage factor
     * @param seniorPrincipal The Senior principal
     * @param juniorPrincipal The Junior principal
     * @return leverage The leverage in basis points (10000 = 1x)
     */
    function calculateLeverage(
        uint256 seniorPrincipal,
        uint256 juniorPrincipal
    ) internal pure returns (uint256 leverage) {
        if (juniorPrincipal == 0) {
            return 0;
        }
        return ((seniorPrincipal + juniorPrincipal) * BASIS_POINTS) / juniorPrincipal;
    }

    /**
     * @notice Calculate Junior ratio from principal amounts
     * @param seniorPrincipal Senior principal amount
     * @param juniorPrincipal Junior principal amount
     * @return Junior ratio in basis points
     */
    function calculateJuniorRatio(
        uint256 seniorPrincipal,
        uint256 juniorPrincipal
    ) internal pure returns (uint256) {
        uint256 total = seniorPrincipal + juniorPrincipal;
        if (total == 0) return 0;
        return (juniorPrincipal * BASIS_POINTS) / total;
    }

    /**
     * @notice Calculate projected Junior ratio after a deposit
     * @param seniorPrincipal Current Senior principal
     * @param juniorPrincipal Current Junior principal
     * @param amount Deposit amount
     * @param isSeniorDeposit True if depositing to Senior tranche
     * @return Projected Junior ratio in basis points
     */
    function calculateProjectedJuniorRatio(
        uint256 seniorPrincipal,
        uint256 juniorPrincipal,
        uint256 amount,
        bool isSeniorDeposit
    ) internal pure returns (uint256) {
        uint256 projectedSenior = seniorPrincipal;
        uint256 projectedJunior = juniorPrincipal;

        if (isSeniorDeposit) {
            projectedSenior += amount;
        } else {
            projectedJunior += amount;
        }

        return calculateJuniorRatio(projectedSenior, projectedJunior);
    }

    /**
     * @notice Check if the protocol is in a healthy state
     * @param juniorPrincipal The Junior principal
     * @param seniorPrincipal The Senior principal
     * @param minJuniorRatio The minimum Junior ratio in basis points
     * @return isHealthy Whether the protocol is healthy
     * @return currentRatio The current Junior ratio in basis points
     */
    function checkHealth(
        uint256 juniorPrincipal,
        uint256 seniorPrincipal,
        uint256 minJuniorRatio
    ) internal pure returns (bool isHealthy, uint256 currentRatio) {
        if (seniorPrincipal == 0 && juniorPrincipal == 0) {
            return (true, 0);
        }

        currentRatio = calculateJuniorRatio(seniorPrincipal, juniorPrincipal);
        isHealthy = currentRatio >= minJuniorRatio;
    }
}
