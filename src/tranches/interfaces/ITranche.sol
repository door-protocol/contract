// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title ITranche
 * @notice Interface for tranche vaults (Senior and Junior)
 */
interface ITranche is IERC4626 {
    /**
     * @notice Add yield to the vault
     * @dev Only callable by CoreVault
     * @param amount The amount of yield to add
     */
    function addYield(uint256 amount) external;

    /**
     * @notice Get the total principal deposited
     * @return The total principal amount
     */
    function totalPrincipal() external view returns (uint256);

    /**
     * @notice Get the CoreVault address
     * @return The CoreVault contract address
     */
    function coreVault() external view returns (address);

    /**
     * @notice Get the accumulated yield
     * @return The accumulated yield amount
     */
    function accumulatedYield() external view returns (uint256);
}

/**
 * @title ISeniorTranche
 * @notice Interface for Senior tranche with fixed rate
 */
interface ISeniorTranche is ITranche {
    /**
     * @notice Get the fixed rate for Senior tranche
     * @return The fixed rate in basis points
     */
    function fixedRate() external view returns (uint256);

    /**
     * @notice Set the fixed rate (only CoreVault)
     * @param newRate The new rate in basis points
     */
    function setFixedRate(uint256 newRate) external;

    /**
     * @notice Emitted when fixed rate is updated
     */
    event FixedRateUpdated(uint256 oldRate, uint256 newRate);
}

/**
 * @title IJuniorTranche
 * @notice Interface for Junior tranche with slash capability
 */
interface IJuniorTranche is ITranche {
    /**
     * @notice Slash the Junior tranche principal to cover Senior obligations
     * @dev Only callable by CoreVault
     * @param amount The amount to slash
     * @return The actual amount slashed
     */
    function slashPrincipal(uint256 amount) external returns (uint256);

    /**
     * @notice Get the current slash deficit (unrecovered losses)
     * @return The slash deficit amount
     */
    function slashDeficit() external view returns (uint256);

    /**
     * @notice Emitted when principal is slashed
     */
    event PrincipalSlashed(uint256 amount, uint256 newDeficit);

    /**
     * @notice Emitted when deficit is recovered
     */
    event DeficitRecovered(uint256 amount);
}
