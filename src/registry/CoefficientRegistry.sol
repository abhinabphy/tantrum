// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

contract CoefficientRegistry {
    struct FeeParams {
        int128 p0; // p*(y0), Q64.64 fixed-point, fee as a fraction (1e18 = 100%)
        int128 m0; // m*(y0)
        int128 betaP; // d p*/dy, Q64.64
        int128 betaM; // d m*/dy
        int128 y0; // reference inventory at solve time
        uint40 validFrom; // activation timestamp (enforces update delay)
        uint40 validUntil; // TTL — after this, hook falls back to safeConstantFee
        uint8 depthBucket; // which depth grid this was solved on (§Part I.11)
        bytes32 solverHash; // hash of the off-chain solver run, for audit/replay
    }

    mapping(PoolId => mapping(uint8 => FeeParams)) public active;
    mapping(PoolId => mapping(uint8 => FeeParams)) public pending;
    mapping(PoolId => int128) public safeConstantFee; // fail-safe fallback, governance-set

        



}
