// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IEpochManager
 * @notice Interface for the EpochManager contract
 */
interface IEpochManager {
    // ============ Enums ============

    /**
     * @notice Epoch states
     */
    enum EpochState {
        OPEN,     // Deposits allowed
        LOCKED,   // No deposits/withdrawals, funds being managed
        SETTLED   // Withdrawals allowed after yield distribution
    }

    // ============ Structs ============

    /// @notice Epoch data structure
    struct Epoch {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        EpochState state;
        uint256 totalDeposits;
        uint256 totalWithdrawRequests;
        bool settled;
    }

    /// @notice Withdrawal request structure
    struct WithdrawRequest {
        address user;
        bool isSenior;
        uint256 shares;
        uint256 epochId;
        bool processed;
    }

    // ============ Events ============

    /// @notice Emitted when a new epoch starts
    event EpochStarted(uint256 indexed epochId, uint256 startTime, uint256 endTime);

    /// @notice Emitted when an epoch is locked
    event EpochLocked(uint256 indexed epochId, uint256 lockTime);

    /// @notice Emitted when an epoch is settled
    event EpochSettled(uint256 indexed epochId, uint256 totalYield);

    /// @notice Emitted when a withdrawal is requested
    event WithdrawRequested(
        address indexed user,
        uint256 indexed epochId,
        bool isSenior,
        uint256 shares
    );

    /// @notice Emitted when an early withdrawal is made
    event EarlyWithdraw(
        address indexed user,
        bool isSenior,
        uint256 assets,
        uint256 penalty
    );

    /// @notice Emitted when penalty is distributed
    event PenaltyDistributed(uint256 amount);

    // ============ Core Functions ============

    /**
     * @notice Request a withdrawal for the next epoch
     * @param isSenior Whether withdrawing from Senior vault
     * @param shares Number of shares to withdraw
     */
    function requestWithdraw(bool isSenior, uint256 shares) external;

    /**
     * @notice Process withdrawals and start new epoch
     */
    function processEpoch() external;

    /**
     * @notice Lock the current epoch
     * @param epochId Epoch ID to lock
     */
    function lockEpoch(uint256 epochId) external;

    /**
     * @notice Settle an epoch after yield distribution
     * @param epochId The epoch ID to settle
     */
    function settleEpoch(uint256 epochId) external;

    /**
     * @notice Early withdraw with penalty
     * @param isSenior Whether withdrawing from Senior vault
     * @param shares Number of shares to withdraw
     * @return assets The amount of assets received after penalty
     */
    function earlyWithdraw(bool isSenior, uint256 shares) external returns (uint256 assets);

    // ============ View Functions ============

    /**
     * @notice Get the current epoch state
     * @return The current EpochState
     */
    function getCurrentState() external view returns (EpochState);

    /**
     * @notice Get current epoch ID
     */
    function currentEpochId() external view returns (uint256);

    /**
     * @notice Get epoch data
     */
    function getEpoch(uint256 epochId) external view returns (Epoch memory);

    /**
     * @notice Get the duration of a specific epoch
     * @param epochId The epoch ID
     * @return The epoch duration in seconds
     */
    function getEpochDuration(uint256 epochId) external view returns (uint256);

    /**
     * @notice Get time until next epoch
     */
    function timeUntilNextEpoch() external view returns (uint256);
}
