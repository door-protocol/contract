// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultStrategy} from "./interfaces/IVaultStrategy.sol";

/**
 * @title MockYieldStrategy
 * @notice Mock strategy for testing yield generation
 * @dev Simulates yield with configurable rate - for testing only
 */
contract MockYieldStrategy is IVaultStrategy {
    using SafeERC20 for IERC20;

    /// @notice The asset token (e.g., USDC)
    IERC20 public immutable asset;

    /// @notice Total assets deployed to this strategy
    uint256 public totalDeployed;

    /// @notice Simulated yield rate in basis points (annual)
    uint256 public simulatedYieldRate;

    /// @notice Last harvest timestamp
    uint256 public lastHarvestTime;

    /// @notice Pending yield to be harvested
    uint256 public pendingYield;

    /// @notice Owner address (CoreVault)
    address public owner;

    event Deposited(uint256 amount);
    event Withdrawn(uint256 amount);
    event YieldRateSet(uint256 newRate);
    event ManualYieldAdded(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "MockYieldStrategy: caller is not owner");
        _;
    }

    constructor(address _asset) {
        asset = IERC20(_asset);
        owner = msg.sender;
        simulatedYieldRate = 800; // 8% APY default
        lastHarvestTime = block.timestamp;
    }

    /**
     * @notice Set the owner (CoreVault)
     */
    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    /**
     * @notice Set the simulated yield rate
     */
    function setYieldRate(uint256 newRate) external onlyOwner {
        simulatedYieldRate = newRate;
        emit YieldRateSet(newRate);
    }

    /**
     * @notice Manually add yield (for testing)
     */
    function addManualYield(uint256 amount) external onlyOwner {
        pendingYield += amount;
        emit ManualYieldAdded(amount);
    }

    /**
     * @notice Simulate a loss scenario (for testing)
     */
    function simulateLoss(uint256 lossAmount) external onlyOwner {
        require(lossAmount <= totalDeployed, "MockYieldStrategy: loss exceeds deployed");
        totalDeployed -= lossAmount;
        asset.safeTransfer(address(0xdead), lossAmount);
    }

    /**
     * @notice Deposit assets into the strategy
     */
    function deposit(uint256 amount) external override onlyOwner {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        totalDeployed += amount;
        emit Deposited(amount);
        emit AssetsDeposited(amount);
    }

    /**
     * @notice Withdraw assets from the strategy
     */
    function withdraw(uint256 amount) external override onlyOwner returns (uint256) {
        uint256 available = asset.balanceOf(address(this));
        uint256 toWithdraw = amount > available ? available : amount;

        if (toWithdraw > 0) {
            totalDeployed = totalDeployed > toWithdraw ? totalDeployed - toWithdraw : 0;
            asset.safeTransfer(msg.sender, toWithdraw);
            emit Withdrawn(toWithdraw);
            emit AssetsWithdrawn(toWithdraw);
        }

        return toWithdraw;
    }

    /**
     * @notice Harvest accrued yield
     */
    function harvest() external override onlyOwner returns (uint256 yieldAmount) {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        if (timeElapsed > 0 && totalDeployed > 0) {
            uint256 timeBasedYield = (totalDeployed * simulatedYieldRate * timeElapsed) / (365 days * 10_000);
            pendingYield += timeBasedYield;
        }

        yieldAmount = pendingYield;
        pendingYield = 0;
        lastHarvestTime = block.timestamp;

        if (yieldAmount > 0) {
            asset.safeTransfer(msg.sender, yieldAmount);
            emit YieldHarvested(yieldAmount);
        }
    }

    /**
     * @notice Execute rebalancing (no-op for mock)
     */
    function rebalance() external override {
        // No-op for mock strategy
    }

    // ============ View Functions ============

    function getCurrentAllocation() external pure override returns (Allocation memory) {
        return Allocation({mEthRatio: 10_000, usdcRatio: 0, rwaRatio: 0});
    }

    function getTargetAllocation() external pure override returns (Allocation memory) {
        return Allocation({mEthRatio: 10_000, usdcRatio: 0, rwaRatio: 0});
    }

    function needsRebalancing() external pure override returns (bool) {
        return false;
    }

    function totalAssets() external view override returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        uint256 timeBasedYield = 0;
        if (timeElapsed > 0 && totalDeployed > 0) {
            timeBasedYield = (totalDeployed * simulatedYieldRate * timeElapsed) / (365 days * 10_000);
        }
        return totalDeployed + pendingYield + timeBasedYield;
    }

    function calculateExpectedApy() external view override returns (uint256) {
        return simulatedYieldRate;
    }

    function getPendingYield() external view override returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        uint256 timeBasedYield = 0;
        if (timeElapsed > 0 && totalDeployed > 0) {
            timeBasedYield = (totalDeployed * simulatedYieldRate * timeElapsed) / (365 days * 10_000);
        }
        return pendingYield + timeBasedYield;
    }
}
