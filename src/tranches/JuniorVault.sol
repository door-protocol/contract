// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IJuniorTranche} from "./interfaces/ITranche.sol";

/**
 * @title JuniorVault
 * @notice Junior tranche vault (DOOR-BOOST) that provides leveraged yields
 * @dev ERC-4626 compliant vault with residual yield distribution and slashing
 *
 * Junior depositors receive:
 * - All excess yield after Senior obligations are met
 * - Leveraged returns in good market conditions
 * - Principal at risk to protect Senior in bad conditions
 */
contract JuniorVault is ERC4626, AccessControl, IJuniorTranche {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ============ Roles ============
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");

    // ============ State Variables ============

    /// @notice The CoreVault that manages this tranche
    address public override coreVault;

    /// @notice Total principal deposited (excluding yield)
    uint256 public override totalPrincipal;

    /// @notice Cumulative slash deficit (losses not yet recovered)
    uint256 public override slashDeficit;

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
    error InsufficientPrincipal();

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
    ) ERC4626(asset_) ERC20("DOOR Boosted Yield", "DOOR-BOOST") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
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

        // If there's a deficit, use yield to recover it first
        if (slashDeficit > 0) {
            uint256 recovery = amount > slashDeficit ? slashDeficit : amount;
            slashDeficit -= recovery;
            amount -= recovery;
            emit DeficitRecovered(recovery);
        }

        accumulatedYield += amount;
        emit YieldAdded(amount);
    }

    /**
     * @notice Slash principal to cover Senior obligations
     * @param amount The amount to slash
     * @return actualSlash The actual amount slashed
     */
    function slashPrincipal(uint256 amount) external override onlyCoreVault returns (uint256 actualSlash) {
        // First use accumulated yield
        if (accumulatedYield > 0) {
            uint256 yieldUsed = amount > accumulatedYield ? accumulatedYield : amount;
            accumulatedYield -= yieldUsed;
            amount -= yieldUsed;
            actualSlash += yieldUsed;
        }

        // Then slash principal if needed
        if (amount > 0) {
            uint256 principalSlash = amount > totalPrincipal ? totalPrincipal : amount;
            totalPrincipal -= principalSlash;
            actualSlash += principalSlash;

            // Track deficit if we couldn't cover the full amount
            if (amount > principalSlash) {
                uint256 deficit = amount - principalSlash;
                slashDeficit += deficit;
            }

            // Transfer slashed funds to CoreVault
            if (principalSlash > 0) {
                IERC20(asset()).safeTransfer(coreVault, principalSlash);
            }
        }

        emit PrincipalSlashed(actualSlash, slashDeficit);
    }

    // ============ ERC-4626 Overrides ============

    /**
     * @notice Get total assets in the vault (principal + yield - deficit)
     * @return Total assets
     */
    function totalAssets() public view virtual override(ERC4626, IERC4626) returns (uint256) {
        uint256 gross = totalPrincipal + accumulatedYield;
        return gross;
    }

    /**
     * @notice Get effective total assets considering slash deficit
     * @return Effective total assets
     */
    function effectiveTotalAssets() public view returns (uint256) {
        uint256 gross = totalPrincipal + accumulatedYield;
        return gross > slashDeficit ? gross - slashDeficit : 0;
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
     * @notice Get the effective APY for Junior depositors based on recent performance
     * @dev This is an estimate based on accumulated yield
     * @return The estimated APY in basis points
     */
    function estimatedAPY() external view returns (uint256) {
        if (totalPrincipal == 0) return 0;
        return (accumulatedYield * 10_000) / totalPrincipal;
    }

    /**
     * @notice Get the leverage factor (how much Senior is being covered)
     * @param seniorPrincipal The total Senior principal
     * @return The leverage factor in basis points (10000 = 1x)
     */
    function leverageFactor(uint256 seniorPrincipal) external view returns (uint256) {
        if (totalPrincipal == 0) return 0;
        return ((seniorPrincipal + totalPrincipal) * 10_000) / totalPrincipal;
    }

    /**
     * @notice Check if the vault is in a healthy state
     * @return True if no slash deficit
     */
    function isHealthy() external view returns (bool) {
        return slashDeficit == 0;
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
