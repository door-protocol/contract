// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ICoreVault
 * @notice Interface for the CoreVault contract
 */
interface ICoreVault {
    // ============ Enums ============

    /**
     * @notice Tranche types for deposit/withdrawal
     */
    enum TrancheType {
        SENIOR,
        JUNIOR
    }

    // ============ Events ============

    /// @notice Emitted when a user deposits into a tranche
    event Deposited(
        address indexed user,
        TrancheType indexed tranche,
        uint256 amount,
        uint256 shares,
        uint256 epochId
    );

    /// @notice Emitted when a user withdraws from a tranche
    event Withdrawn(
        address indexed user,
        TrancheType indexed tranche,
        uint256 shares,
        uint256 amountReceived,
        uint256 epochId
    );

    /// @notice Emitted when yield is harvested and distributed
    event YieldDistributed(
        uint256 indexed epochId,
        uint256 totalYield,
        uint256 seniorYield,
        uint256 juniorYield,
        uint256 juniorSlash,
        uint256 protocolFee
    );

    /// @notice Emitted when fixed rate is adjusted
    event SeniorRateUpdated(uint256 newRate, uint256 epochId);

    /// @notice Emitted when protocol fee rate is updated
    event ProtocolFeeUpdated(uint256 newFeeRate);

    /// @notice Emitted when minimum Junior ratio is updated
    event MinJuniorRatioUpdated(uint256 newRatio);

    /// @notice Emitted when emergency mode is triggered
    event EmergencyModeActivated(string reason);

    /// @notice Emitted when principal is registered
    event PrincipalRegistered(bool isSenior, uint256 amount);

    /// @notice Emitted when principal is deregistered
    event PrincipalDeregistered(bool isSenior, uint256 amount);

    // ============ Core Functions ============

    /**
     * @notice Harvest yield from strategy and distribute via waterfall
     */
    function harvest() external;

    /**
     * @notice Register new principal deposit
     * @param isSenior Whether this is Senior principal
     * @param amount The amount deposited
     */
    function registerPrincipal(bool isSenior, uint256 amount) external;

    /**
     * @notice Deregister principal withdrawal
     * @param isSenior Whether this is Senior principal
     * @param amount The amount withdrawn
     */
    function deregisterPrincipal(bool isSenior, uint256 amount) external;

    // ============ View Functions ============

    /**
     * @notice Get current protocol statistics
     */
    function getStats()
        external
        view
        returns (
            uint256 seniorPrincipal,
            uint256 juniorPrincipal,
            uint256 totalAssets,
            uint256 currentSeniorRate,
            uint256 juniorRatio,
            bool isHealthy
        );

    /**
     * @notice Get the current Senior fixed rate
     */
    function seniorFixedRate() external view returns (uint256);

    /**
     * @notice Get the current Junior ratio
     * @return The Junior ratio in basis points (1% = 100)
     */
    function getJuniorRatio() external view returns (uint256);

    /**
     * @notice Get the Senior vault address
     */
    function seniorVault() external view returns (address);

    /**
     * @notice Get the Junior vault address
     */
    function juniorVault() external view returns (address);
}
