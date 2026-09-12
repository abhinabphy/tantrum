// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

/// @title ICoefficientRegistry
/// @notice Manages the storage, time-delayed promotion, and fail-safe fallback of dynamic fee parameters.
/// @dev All mathematical parameters use Q64.64 signed fixed-point arithmetic to prevent precision drift.
interface ICoefficientRegistry {
    
    /* -------------------------------------------------------------------------- */
    /*                                   STRUCTS                                  */
    /* -------------------------------------------------------------------------- */

    / @notice Holds the linearized fee parameters solved off-chain.
    / @dev Carefully packed to fit within minimal EVM storage slots (3 slots total).
    struct FeeParams {
        // Slot 0: Base parameters
        int128 p0;          // Q64.64: Base sell fee fraction (p*(y0))
        int128 m0;          // Q64.64: Base buy fee fraction (m*(y0))
        
        // Slot 1: Slopes and Reference
        int128 betaP;       // Q64.64: d p*/dy (Sell fee sensitivity)
        int128 betaM;       // Q64.64: d m*/dy (Buy fee sensitivity)
        
        // Slot 2: Metadata, Time-locks, and Validation
        int128 y0;          // Live reserve snapshot at off-chain solve time
        uint40 validFrom;   // Timestamp when these parameters can become active
        uint40 validUntil;  // Timestamp when these parameters expire (TTL)
        uint8 depthBucket;  // Index of the liquidity depth grid used for the HJB solve
        bytes32 solverHash; // Deterministic hash of the Rust solver execution
    }

    /* -------------------------------------------------------------------------- */
    /*                                   ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Thrown when attempting to update coefficients before the minimum interval.
    error RateLimitExceeded();
    
    /// @notice Thrown when the new validFrom timestamp violates the minimum delay guardrail.
    error InvalidActivationDelay();
    
    /// @notice Thrown when the TTL (validUntil) is set too far in the future or in the past.
    error InvalidTTL();
    
    /// @notice Thrown when provided coefficients fail the pure BoundsCheck sanity limits.
    error CoefficientsOutOfBounds();

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Emitted when a new set of parameters is written to the pending mapping.
    event CoefficientsStaged(
        PoolId indexed id, 
        uint8 indexed depthBucket, 
        bytes32 solverHash, 
        uint40 validFrom
    );

    /// @notice Emitted when pending parameters are lazy-promoted to active.
    event CoefficientsPromoted(
        PoolId indexed id, 
        uint8 indexed depthBucket, 
        bytes32 solverHash
    );

    /// @notice Emitted if governance updates the fallback safe fee.
    event SafeConstantFeeUpdated(
        PoolId indexed id, 
        uint24 newSafeFee
    );

    /* -------------------------------------------------------------------------- */
    /*                                 STATE GETTERS                              */
    /* -------------------------------------------------------------------------- */

    /// @notice Retrieves the currently active parameters for a pool and depth bucket.
    function getActiveParams(PoolId id, uint8 depthBucket) external view returns (FeeParams memory);

    /// @notice Retrieves the pending parameters awaiting their validFrom timestamp.
    function getPendingParams(PoolId id, uint8 depthBucket) external view returns (FeeParams memory);

    /// @notice Retrieves the fail-safe static fee for a specific pool.
    function getSafeConstantFee(PoolId id) external view returns (int128);

    /* -------------------------------------------------------------------------- */
    /*                                CORE LOGIC                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Retrieves the strictly valid parameter set, handling lazy promotion and TTL degradation.
    /// @dev If `pending` is ripe, returns `pending`. If `active` is expired, returns `safeConstantFee`.
    /// @param id The Uniswap v4 PoolId.
    /// @param depthBucket The current liquidity depth classification of the pool.
    /// @return The parameter struct safe for immediate fee calculation.
    function getEffectiveParams(PoolId id, uint8 depthBucket) external view returns (FeeParams memory);

    /// @notice Batches off-chain solver updates across multiple depth buckets for a single pool.
    /// @dev Must be restricted to the Keeper role or GuardedTimelock.
    /// @param id The Uniswap v4 PoolId.
    /// @param buckets An array of depth bucket indices.
    /// @param params An array of structurally valid FeeParams.
    function updateCoefficientsBatch(
        PoolId id, 
        uint8[] calldata buckets, 
        FeeParams[] calldata params
    ) external;

    /// @notice Explicitly promotes pending parameters to active if the validFrom timestamp has passed.
    /// @dev This is usually handled lazily in `getEffectiveParams`, but exposed for manual Keeper maintenance.
    function promotePending(PoolId id, uint8 depthBucket) external;
}