// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockMETH
 * @notice Mock Mantle mETH token for testing purposes
 * @dev Simulates yield-bearing mETH with configurable yield rate
 */
contract MockMETH is ERC20 {
    /// @notice Annual yield rate in basis points (e.g., 500 = 5%)
    uint256 public yieldRate;

    /// @notice Last time yield was accrued
    uint256 public lastAccrualTime;

    /// @notice Total yield accrued (for simulation)
    uint256 public accruedYield;

    constructor() ERC20("Mantle Staked Ether", "mETH") {
        yieldRate = 500; // 5% APY default
        lastAccrualTime = block.timestamp;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @notice Set the annual yield rate
     * @param newRate The new yield rate in basis points
     */
    function setYieldRate(uint256 newRate) external {
        yieldRate = newRate;
    }

    /**
     * @notice Mint tokens to any address (for testing only)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from any address (for testing only)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /**
     * @notice Simulate yield accrual based on time elapsed
     * @dev This mints new tokens to simulate staking rewards
     * @param to The address to receive the accrued yield
     * @return yieldAmount The amount of yield accrued
     */
    function accrueYield(address to) external returns (uint256 yieldAmount) {
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        if (timeElapsed == 0) return 0;

        // Calculate yield: principal * rate * time / (365 days * 10000)
        uint256 principal = balanceOf(to);
        yieldAmount = (principal * yieldRate * timeElapsed) / (365 days * 10_000);

        if (yieldAmount > 0) {
            _mint(to, yieldAmount);
            accruedYield += yieldAmount;
        }

        lastAccrualTime = block.timestamp;
    }

    /**
     * @notice Get pending yield for an address
     * @param account The address to check
     * @return The pending yield amount
     */
    function pendingYield(address account) external view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastAccrualTime;
        if (timeElapsed == 0) return 0;

        uint256 principal = balanceOf(account);
        return (principal * yieldRate * timeElapsed) / (365 days * 10_000);
    }
}
