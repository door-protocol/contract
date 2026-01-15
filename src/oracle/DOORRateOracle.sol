// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IDOORRateOracle} from "./interfaces/IDOORRateOracle.sol";

/**
 * @title DOORRateOracle
 * @notice DOOR Rate Oracle - Synthetic benchmark rate for DeFi
 * @dev Aggregates multiple rate sources with weighted average:
 *      - TESR (Treehouse Ethereum Staking Rate): 20%
 *      - mETH Staking (Mantle LST): 30%
 *      - SOFR (Secured Overnight Financing Rate): 25%
 *      - Aave USDT Supply Rate: 15%
 *      - Ondo USDY Yield: 10%
 *
 * Features:
 * - Signature verification for trustless updates
 * - Challenge mechanism for large rate changes
 * - Multiple rate sources with weights
 */
contract DOORRateOracle is IDOORRateOracle, AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============ Roles ============
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // ============ Constants ============
    uint256 public constant BASIS_POINTS = 10_000;
    uint256 public constant MAX_RATE = 5000;           // Max 50% APY
    uint256 public constant MAX_RATE_CHANGE = 200;     // Max 2% change per update
    uint256 public constant STALENESS_THRESHOLD = 24 hours;
    uint256 public constant CHALLENGE_PERIOD = 24 hours;
    uint256 public constant SENIOR_PREMIUM = 100;      // 1% premium over DOR

    // ============ State Variables ============
    RateSource[] public rateSources;

    /// @notice Authorized rate updaters (backend signers)
    mapping(address => bool) public authorizedUpdaters;

    /// @notice Pending rate changes under challenge
    mapping(uint256 => PendingRateChange) public pendingChanges;

    /// @notice Last computed DOR value (cached)
    uint256 public cachedDOR;
    uint256 public lastDORUpdate;

    /// @notice Nonce for replay protection
    uint256 public updateNonce;

    struct PendingRateChange {
        uint256 proposedRate;
        uint256 challengeDeadline;
        bool exists;
    }

    // ============ Errors ============
    error Unauthorized();
    error InvalidSourceId();
    error RateTooHigh();
    error StaleData();
    error ArrayLengthMismatch();
    error InvalidSignature();
    error NoPendingChallenge();
    error ChallengePeriodNotEnded();

    // ============ Constructor ============

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);

        authorizedUpdaters[msg.sender] = true;
        _initializeRateSources();
    }

    // ============ Initialization ============

    function _initializeRateSources() internal {
        // Source 0: TESR (Treehouse Ethereum Staking Rate) - 20%
        rateSources.push(
            RateSource({
                name: "TESR",
                weight: 2000,
                rate: 350, // 3.50%
                lastUpdate: block.timestamp,
                isActive: true
            })
        );

        // Source 1: mETH Staking (Mantle LST) - 30%
        rateSources.push(
            RateSource({
                name: "mETH",
                weight: 3000,
                rate: 450, // 4.50%
                lastUpdate: block.timestamp,
                isActive: true
            })
        );

        // Source 2: SOFR (Secured Overnight Financing Rate) - 25%
        rateSources.push(
            RateSource({
                name: "SOFR",
                weight: 2500,
                rate: 460, // 4.60%
                lastUpdate: block.timestamp,
                isActive: true
            })
        );

        // Source 3: Aave USDT Supply Rate - 15%
        rateSources.push(
            RateSource({
                name: "Aave_USDT",
                weight: 1500,
                rate: 600, // 6.00%
                lastUpdate: block.timestamp,
                isActive: true
            })
        );

        // Source 4: Ondo USDY Yield - 10%
        rateSources.push(
            RateSource({
                name: "Ondo_USDY",
                weight: 1000,
                rate: 500, // 5.00%
                lastUpdate: block.timestamp,
                isActive: true
            })
        );

        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;
    }

    // ============ Core Functions ============

    /**
     * @notice Get the current DOR (DOOR Optimized Rate)
     */
    function getDOR() external view override returns (uint256) {
        return cachedDOR;
    }

    /**
     * @notice Calculate Senior rate based on DOR
     */
    function calculateSeniorRate() external view override returns (uint256) {
        return cachedDOR + SENIOR_PREMIUM;
    }

    /**
     * @notice Calculate DOR from all active sources
     */
    function _calculateDOR() internal view returns (uint256) {
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < rateSources.length; i++) {
            if (rateSources[i].isActive) {
                weightedSum += rateSources[i].rate * rateSources[i].weight;
                totalWeight += rateSources[i].weight;
            }
        }

        if (totalWeight == 0) return 0;
        return weightedSum / totalWeight;
    }

    /**
     * @notice Get a specific rate source
     */
    function getRateSource(uint256 sourceId) external view override returns (RateSource memory) {
        if (sourceId >= rateSources.length) revert InvalidSourceId();
        return rateSources[sourceId];
    }

    /**
     * @notice Get all rate sources
     */
    function getAllRateSources() external view override returns (RateSource[] memory) {
        return rateSources;
    }

    /**
     * @notice Update a single rate source
     */
    function updateRate(uint256 sourceId, uint256 newRate) external override onlyRole(ORACLE_ROLE) {
        if (sourceId >= rateSources.length) revert InvalidSourceId();
        if (newRate > MAX_RATE) revert RateTooHigh();

        _updateRateInternal(sourceId, newRate);

        uint256 oldDOR = cachedDOR;
        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;

        if (oldDOR != cachedDOR) {
            emit DORUpdated(oldDOR, cachedDOR, block.timestamp);
        }
    }

    /**
     * @notice Batch update multiple rate sources
     */
    function batchUpdateRates(
        uint256[] calldata sourceIds,
        uint256[] calldata newRates
    ) external override onlyRole(ORACLE_ROLE) {
        if (sourceIds.length != newRates.length) revert ArrayLengthMismatch();

        for (uint256 i = 0; i < sourceIds.length; i++) {
            if (sourceIds[i] >= rateSources.length) revert InvalidSourceId();
            if (newRates[i] > MAX_RATE) revert RateTooHigh();
            _updateRateInternal(sourceIds[i], newRates[i]);
        }

        uint256 oldDOR = cachedDOR;
        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;

        emit BatchUpdateCompleted(sourceIds.length, cachedDOR, block.timestamp);
        emit DORUpdated(oldDOR, cachedDOR, block.timestamp);
    }

    /**
     * @notice Update rate with signature verification
     */
    function updateRateWithSignature(
        uint256 sourceId,
        uint256 newRate,
        uint256 timestamp,
        bytes calldata signature
    ) external override {
        if (block.timestamp > timestamp + 5 minutes) revert StaleData();

        bytes32 messageHash = keccak256(
            abi.encodePacked(address(this), sourceId, newRate, timestamp, updateNonce)
        );
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();

        address signer = ethSignedHash.recover(signature);
        if (!authorizedUpdaters[signer]) revert InvalidSignature();

        updateNonce++;

        _updateRateInternal(sourceId, newRate);

        uint256 oldDOR = cachedDOR;
        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;

        emit DORUpdated(oldDOR, cachedDOR, block.timestamp);
    }

    /**
     * @notice Internal rate update with challenge mechanism
     */
    function _updateRateInternal(uint256 sourceId, uint256 newRate) internal {
        RateSource storage source = rateSources[sourceId];
        uint256 oldRate = source.rate;

        uint256 rateChange = oldRate > newRate ? oldRate - newRate : newRate - oldRate;

        if (rateChange > MAX_RATE_CHANGE) {
            // Large change - initiate challenge period
            pendingChanges[sourceId] = PendingRateChange({
                proposedRate: newRate,
                challengeDeadline: block.timestamp + CHALLENGE_PERIOD,
                exists: true
            });

            emit RateChallengeInitiated(sourceId, oldRate, newRate, block.timestamp + CHALLENGE_PERIOD);
        } else {
            // Normal update
            source.rate = newRate;
            source.lastUpdate = block.timestamp;

            emit RateUpdated(sourceId, source.name, oldRate, newRate, block.timestamp);
        }
    }

    /**
     * @notice Execute pending rate change after challenge period
     */
    function executePendingChange(uint256 sourceId) external {
        PendingRateChange storage pending = pendingChanges[sourceId];
        if (!pending.exists) revert NoPendingChallenge();
        if (block.timestamp < pending.challengeDeadline) revert ChallengePeriodNotEnded();

        RateSource storage source = rateSources[sourceId];
        uint256 oldRate = source.rate;

        source.rate = pending.proposedRate;
        source.lastUpdate = block.timestamp;

        delete pendingChanges[sourceId];

        emit RateUpdated(sourceId, source.name, oldRate, pending.proposedRate, block.timestamp);

        uint256 oldDOR = cachedDOR;
        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;
        emit DORUpdated(oldDOR, cachedDOR, block.timestamp);
    }

    // ============ View Functions ============

    /**
     * @notice Get the target Senior APY based on DOR
     */
    function getSeniorTargetAPY() external view override returns (uint256) {
        return cachedDOR + SENIOR_PREMIUM;
    }

    /**
     * @notice Check if DOR data is fresh
     */
    function isFresh() external view override returns (bool) {
        return block.timestamp - lastDORUpdate < STALENESS_THRESHOLD;
    }

    /**
     * @notice Get detailed DOR breakdown
     */
    function getDORBreakdown()
        external
        view
        returns (
            string[] memory names,
            uint256[] memory weights,
            uint256[] memory rates,
            uint256[] memory contributions,
            uint256 totalDOR
        )
    {
        uint256 len = rateSources.length;
        names = new string[](len);
        weights = new uint256[](len);
        rates = new uint256[](len);
        contributions = new uint256[](len);

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < len; i++) {
            if (rateSources[i].isActive) {
                totalWeight += rateSources[i].weight;
            }
        }

        for (uint256 i = 0; i < len; i++) {
            names[i] = rateSources[i].name;
            weights[i] = rateSources[i].weight;
            rates[i] = rateSources[i].rate;

            if (rateSources[i].isActive && totalWeight > 0) {
                contributions[i] = (rateSources[i].rate * rateSources[i].weight) / totalWeight;
            }
        }

        totalDOR = cachedDOR;
    }

    /**
     * @notice Get health status of all rate sources
     */
    function getSourceHealth()
        external
        view
        returns (bool[] memory isHealthy, uint256[] memory lastUpdates, uint256 healthyCount)
    {
        uint256 len = rateSources.length;
        isHealthy = new bool[](len);
        lastUpdates = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            lastUpdates[i] = rateSources[i].lastUpdate;
            isHealthy[i] = (block.timestamp - rateSources[i].lastUpdate) < STALENESS_THRESHOLD;
            if (isHealthy[i]) healthyCount++;
        }
    }

    /**
     * @notice Get source count
     */
    function getSourceCount() external view returns (uint256) {
        return rateSources.length;
    }

    // ============ Admin Functions ============

    /**
     * @notice Add a new rate source
     */
    function addRateSource(
        string calldata name,
        uint256 weight,
        uint256 initialRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (initialRate > MAX_RATE) revert RateTooHigh();

        rateSources.push(
            RateSource({
                name: name,
                weight: weight,
                rate: initialRate,
                lastUpdate: block.timestamp,
                isActive: true
            })
        );

        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;
    }

    /**
     * @notice Update source weight
     */
    function updateSourceWeight(uint256 sourceId, uint256 newWeight) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (sourceId >= rateSources.length) revert InvalidSourceId();
        rateSources[sourceId].weight = newWeight;

        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;
    }

    /**
     * @notice Toggle source active status
     */
    function toggleSourceActive(uint256 sourceId, bool active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (sourceId >= rateSources.length) revert InvalidSourceId();
        rateSources[sourceId].isActive = active;

        cachedDOR = _calculateDOR();
        lastDORUpdate = block.timestamp;
    }

    /**
     * @notice Add or remove authorized updater
     */
    function setAuthorizedUpdater(address updater, bool authorized) external onlyRole(DEFAULT_ADMIN_ROLE) {
        authorizedUpdaters[updater] = authorized;
    }
}
