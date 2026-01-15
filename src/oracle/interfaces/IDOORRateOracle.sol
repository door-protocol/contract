// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IDOORRateOracle
 * @notice Interface for DOOR Rate Oracle - Synthetic Rate Oracle for DeFi
 * @dev DOR = Weighted average of multiple rate sources
 */
interface IDOORRateOracle {
    // ============ Structs ============

    /// @notice Rate source data structure
    struct RateSource {
        string name;           // Source name (e.g., "mETH", "TESR")
        uint256 weight;        // Weight in basis points (e.g., 3000 = 30%)
        uint256 rate;          // Current rate in basis points (e.g., 450 = 4.50%)
        uint256 lastUpdate;    // Last update timestamp
        bool isActive;         // Whether this source is active
    }

    // ============ Events ============

    /// @notice Rate update event
    event RateUpdated(
        uint256 indexed sourceId,
        string name,
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );

    /// @notice Rate challenge initiated (for large deviations)
    event RateChallengeInitiated(
        uint256 indexed sourceId,
        uint256 oldRate,
        uint256 proposedRate,
        uint256 challengeDeadline
    );

    /// @notice DOR value updated
    event DORUpdated(uint256 oldDOR, uint256 newDOR, uint256 timestamp);

    /// @notice Batch update completed
    event BatchUpdateCompleted(uint256 sourcesUpdated, uint256 newDOR, uint256 timestamp);

    // ============ Core Functions ============

    /**
     * @notice Get the current DOR (DOOR Optimized Rate)
     * @return DOR value in basis points (e.g., 460 = 4.60%)
     */
    function getDOR() external view returns (uint256);

    /**
     * @notice Calculate the Senior tranche fixed rate based on DOR
     * @return The Senior APY in basis points
     */
    function calculateSeniorRate() external view returns (uint256);

    /**
     * @notice Get a specific rate source
     * @param sourceId The ID of the rate source
     * @return The rate source data
     */
    function getRateSource(uint256 sourceId) external view returns (RateSource memory);

    /**
     * @notice Get all rate sources
     * @return Array of all rate sources
     */
    function getAllRateSources() external view returns (RateSource[] memory);

    /**
     * @notice Update a single rate source (only authorized updater)
     * @param sourceId The ID of the rate source
     * @param newRate The new rate in basis points
     */
    function updateRate(uint256 sourceId, uint256 newRate) external;

    /**
     * @notice Batch update multiple rate sources
     * @param sourceIds Array of source IDs
     * @param newRates Array of new rates
     */
    function batchUpdateRates(uint256[] calldata sourceIds, uint256[] calldata newRates) external;

    /**
     * @notice Update rate with signature verification
     * @param sourceId Source ID to update
     * @param newRate New rate value
     * @param timestamp Update timestamp
     * @param signature Backend signature
     */
    function updateRateWithSignature(
        uint256 sourceId,
        uint256 newRate,
        uint256 timestamp,
        bytes calldata signature
    ) external;

    /**
     * @notice Get the target Senior APY based on DOR
     * @return Target APY for Senior tranche in basis points
     */
    function getSeniorTargetAPY() external view returns (uint256);

    /**
     * @notice Check if DOR data is fresh (within staleness threshold)
     * @return True if data is fresh
     */
    function isFresh() external view returns (bool);
}
