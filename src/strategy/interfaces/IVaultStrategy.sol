// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IVaultStrategy
 * @notice Interface for the VaultStrategy contract
 */
interface IVaultStrategy {
    // ============ Structs ============

    /**
     * @notice Asset allocation ratios
     */
    struct Allocation {
        uint256 mEthRatio;   // mETH allocation in bps
        uint256 usdcRatio;   // USDC allocation in bps
        uint256 rwaRatio;    // RWA allocation in bps
    }

    // ============ Events ============

    /// @notice Emitted when rebalancing occurs
    event Rebalanced(
        uint256 indexed mEthAmount,
        uint256 indexed usdcAmount,
        uint256 indexed rwaAmount,
        uint256 timestamp
    );

    /// @notice Emitted when allocation is updated
    event AllocationUpdated(
        uint256 indexed mEthRatio,
        uint256 indexed usdcRatio,
        uint256 indexed rwaRatio
    );

    /// @notice Emitted when assets are deposited
    event AssetsDeposited(uint256 indexed amount);

    /// @notice Emitted when assets are withdrawn
    event AssetsWithdrawn(uint256 indexed amount);

    /// @notice Emitted when yield is harvested
    event YieldHarvested(uint256 indexed amount);

    // ============ Core Functions ============

    /**
     * @notice Deposit assets into the strategy
     * @param amount The amount to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraw assets from the strategy
     * @param amount The amount to withdraw
     * @return The actual amount withdrawn
     */
    function withdraw(uint256 amount) external returns (uint256);

    /**
     * @notice Harvest accrued yield
     * @return yieldAmount The amount of yield harvested
     */
    function harvest() external returns (uint256 yieldAmount);

    /**
     * @notice Execute rebalancing
     */
    function rebalance() external;

    // ============ View Functions ============

    /**
     * @notice Get current asset allocation
     * @return Current Allocation struct
     */
    function getCurrentAllocation() external view returns (Allocation memory);

    /**
     * @notice Get target asset allocation
     * @return Target Allocation struct
     */
    function getTargetAllocation() external view returns (Allocation memory);

    /**
     * @notice Check if rebalancing is needed
     * @return True if rebalancing should be triggered
     */
    function needsRebalancing() external view returns (bool);

    /**
     * @notice Get total assets under management
     * @return Total assets
     */
    function totalAssets() external view returns (uint256);

    /**
     * @notice Calculate expected weighted APY
     * @return Expected APY in basis points
     */
    function calculateExpectedApy() external view returns (uint256);

    /**
     * @notice Get pending yield to be harvested
     * @return The pending yield amount
     */
    function getPendingYield() external view returns (uint256);
}
