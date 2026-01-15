// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ISeniorTranche} from "./interfaces/ITranche.sol";

/**
 * @title SeniorVault
 * @notice Senior tranche vault (DOOR-FIX) that provides fixed-rate yields
 * @dev ERC-4626 compliant vault with priority yield distribution
 *
 * Senior depositors receive:
 * - Fixed yield rate (e.g., 5% APY)
 * - First priority in waterfall distribution
 * - Principal protection via Junior tranche buffer
 */
contract SeniorVault is ERC4626, AccessControl, ISeniorTranche {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ============ Roles ============
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    // ============ State Variables ============

    /// @notice The CoreVault that manages this tranche
    address public override coreVault;

    /// @notice Total principal deposited (excluding yield)
    uint256 public override totalPrincipal;

    /// @notice Fixed annual rate in basis points (500 = 5%)
    uint256 public override fixedRate;

    /// @notice Accumulated yield from CoreVault
    uint256 public override accumulatedYield;

    /// @notice Whether the vault is initialized with CoreVault
    bool public initialized;

    /// @notice Mapping of user to auto-compound preference
    mapping(address => bool) public autoCompound;

    // ============ Events ============
    event CoreVaultSet(address indexed coreVault);
    event YieldAdded(uint256 amount);
    event AutoCompoundSet(address indexed user, bool enabled);

    // ============ Errors ============
    error NotCoreVault();
    error AlreadyInitialized();
    error NotInitialized();
    error ZeroAddress();

    // ============ Modifiers ============
    modifier onlyCoreVault() {
        if (msg.sender != coreVault) revert NotCoreVault();
        _;
    }

    modifier whenInitialized() {
        if (!initialized) revert NotInitialized();
        _;
    }

    // ============ Constructor ============

    /**
     * @notice Constructor
     * @param asset_ The underlying asset (e.g., USDC)
     */
    constructor(
        IERC20 asset_
    ) ERC4626(asset_) ERC20("DOOR Fixed Income", "DOOR-FIX") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        fixedRate = 500; // 5% default
    }

    // ============ Initialization ============

    /**
     * @notice Initialize the vault with CoreVault address
     * @param coreVault_ The CoreVault contract address
     */
    function initialize(address coreVault_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (initialized) revert AlreadyInitialized();
        if (coreVault_ == address(0)) revert ZeroAddress();

        coreVault = coreVault_;
        _grantRole(VAULT_ROLE, coreVault_);
        initialized = true;

        emit CoreVaultSet(coreVault_);
    }

    // ============ Core Functions ============

    /**
     * @notice Add yield to the vault from CoreVault
     * @param amount The amount of yield to add
     */
    function addYield(uint256 amount) external override onlyCoreVault {
        if (amount == 0) return;

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        accumulatedYield += amount;

        emit YieldAdded(amount);
    }

    /**
     * @notice Update the fixed rate (only CoreVault)
     * @param newRate The new rate in basis points
     */
    function setFixedRate(uint256 newRate) external override onlyCoreVault {
        uint256 oldRate = fixedRate;
        fixedRate = newRate;
        emit FixedRateUpdated(oldRate, newRate);
    }

    // ============ ERC-4626 Overrides ============

    /**
     * @notice Get total assets in the vault (principal + yield)
     * @return Total assets
     */
    function totalAssets() public view virtual override(ERC4626, IERC4626) returns (uint256) {
        return totalPrincipal + accumulatedYield;
    }

    /**
     * @notice Deposit assets and receive shares
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override(ERC4626, IERC4626) whenInitialized returns (uint256 shares) {
        shares = super.deposit(assets, receiver);
        totalPrincipal += assets;
    }

    /**
     * @notice Mint shares by depositing assets
     */
    function mint(
        uint256 shares,
        address receiver
    ) public virtual override(ERC4626, IERC4626) whenInitialized returns (uint256 assets) {
        assets = super.mint(shares, receiver);
        totalPrincipal += assets;
    }

    /**
     * @notice Withdraw assets by burning shares
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner_
    ) public virtual override(ERC4626, IERC4626) whenInitialized returns (uint256 shares) {
        uint256 totalAssetsBefore = totalAssets();
        uint256 principalPortion = assets.mulDiv(totalPrincipal, totalAssetsBefore, Math.Rounding.Ceil);
        uint256 yieldPortion = assets.mulDiv(accumulatedYield, totalAssetsBefore, Math.Rounding.Floor);

        shares = super.withdraw(assets, receiver, owner_);

        totalPrincipal = totalPrincipal > principalPortion ? totalPrincipal - principalPortion : 0;
        accumulatedYield = accumulatedYield > yieldPortion ? accumulatedYield - yieldPortion : 0;
    }

    /**
     * @notice Redeem shares for assets
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner_
    ) public virtual override(ERC4626, IERC4626) whenInitialized returns (uint256 assets) {
        uint256 totalSharesBefore = totalSupply();
        uint256 principalPortion = shares.mulDiv(totalPrincipal, totalSharesBefore, Math.Rounding.Ceil);
        uint256 yieldPortion = shares.mulDiv(accumulatedYield, totalSharesBefore, Math.Rounding.Floor);

        assets = super.redeem(shares, receiver, owner_);

        totalPrincipal = totalPrincipal > principalPortion ? totalPrincipal - principalPortion : 0;
        accumulatedYield = accumulatedYield > yieldPortion ? accumulatedYield - yieldPortion : 0;
    }

    // ============ View Functions ============

    /**
     * @notice Calculate the expected annual yield for a given principal
     * @param principal The principal amount
     * @return The expected annual yield
     */
    function expectedAnnualYield(uint256 principal) external view returns (uint256) {
        return (principal * fixedRate) / 10_000;
    }

    /**
     * @notice Get the current APY for Senior depositors
     * @return The APY in basis points
     */
    function currentAPY() external view returns (uint256) {
        return fixedRate;
    }

    // ============ User Preferences ============

    /**
     * @notice Set auto-compound preference for the caller
     * @param enabled Whether to enable auto-compounding
     */
    function setAutoCompound(bool enabled) external {
        autoCompound[msg.sender] = enabled;
        emit AutoCompoundSet(msg.sender, enabled);
    }

    /**
     * @notice Check if an address has auto-compound enabled
     * @param user The address to check
     * @return Whether auto-compound is enabled
     */
    function isAutoCompoundEnabled(address user) external view returns (bool) {
        return autoCompound[user];
    }

    // ============ AccessControl Override ============

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
