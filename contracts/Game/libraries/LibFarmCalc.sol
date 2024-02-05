// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";

library LibFarmCalc {
    uint256 constant internal POOL_DECREASE_FACTOR = 0.995 * 1e18;

    function upgradeCost(uint256 farmTier_) internal pure returns (uint256) {
        return
            ((FixedPointMathLib.mulWad(0.1e18, (farmTier_ ** 3) * 1e18) +
                FixedPointMathLib.mulWad(2.5e18, (farmTier_ ** 2) * 1e18) +
                FixedPointMathLib.mulWad(3.5e18, (farmTier_) * 1e18) -
                6 *
                1e18) / 1e18) *
            100 *
            1 ether;
    }

    function upgradeCooldown(
        uint256 farmTier_
    ) internal pure returns (uint256) {
        if (farmTier_ < 2) return 0;
        return 10800 * farmTier_ + 64800;
    }

    function maxGrowSpots(uint256 farmTier_) internal pure returns (uint256) {
        return farmTier_ + 2;
    }

    function growerFarmRate(uint256 farmTier_) internal pure returns (uint256) {
        return (farmTier_ + 19) * 1 ether;
    }

    function harvestCap(uint256 farmTier_) internal pure returns (uint256) {
        return
            (((farmTier_ ** 2) *
                1e18 +
                FixedPointMathLib.mulWad(0.4e18, (farmTier_) * 1e18) +
                6e18) / 1e18) *
            50 *
            1 ether;
    }

    function bonusToAttack(uint256 farmTier_) internal pure returns (uint256) {
        if (farmTier_ < 2) return 0;
        return
            (FixedPointMathLib.mulWad(0.03e18, (farmTier_ ** 2) * 1e18) +
                FixedPointMathLib.mulWad(1.55e18, (farmTier_) * 1e18) -
                1.6e18) / 1e18;
    }

    function bonusToDefense(uint256 farmTier_) internal pure returns (uint256) {
        if (farmTier_ < 2) return 0;
        return
            (FixedPointMathLib.mulWad(0.03e18, (farmTier_ ** 2) * 1e18) +
                FixedPointMathLib.mulWad(1.25e18, (farmTier_) * 1e18) -
                1.6e18) / 1e18;
    }

    function bonusToLoot(uint256 farmTier_) internal pure returns (uint256) {
        if (farmTier_ < 2) return 0;
        return
            (FixedPointMathLib.mulWad(0.03e18, (farmTier_ ** 2) * 1e18) +
                FixedPointMathLib.mulWad(1.55e18, (farmTier_) * 1e18) -
                1.6e18) / 1e18;
    }

    function bonusToProtection(
        uint256 farmTier_
    ) internal pure returns (uint256) {
        if (farmTier_ < 2) return 0;
        return
            (FixedPointMathLib.mulWad(0.03e18, (farmTier_ ** 2) * 1e18) +
                FixedPointMathLib.mulWad(1.25e18, (farmTier_) * 1e18) -
                1.6e18) / 1e18;
    }

    function dbnPoolDecrease(
        uint256 currentPool_
    ) internal pure returns (uint256) {
        return
            FixedPointMathLib.mulWad(
                POOL_DECREASE_FACTOR,
                currentPool_ * 1e18
            ) / 1e18;
    }

    /**
     * @param remainingEpochPool_ Unspent Dbn left on this epoch
     * @param initEpochPool_ Dbn amount in pool in the beginning of epoch
     * @param poolShareFactor_ Game config value, should be supplied with e18 multiplier e.g. ( 0.95 * e18 )
     * @param tokensInSafe_ How many farm tokens the user have to spend at the moment
     * @param tokensMass_ Overall amount of farm tokens on stocks and safes on the beginning of epoch
     * @param tokensExchangeRate_ How much farm tokens should be paid for one Dbn on this epoch
     */
    function farmTokenToDbnSwapPair(
        uint256 remainingEpochPool_,
        uint256 initEpochPool_,
        uint256 poolShareFactor_,
        uint256 tokensInSafe_,
        uint256 tokensMass_,
        uint256 tokensExchangeRate_
    ) internal pure returns (uint256 tokenToSpend, uint256 dbnAmount) {
        //AvailableTokensForPurchase = Min (
        //    RemainingWeekPool;
        //    InitialWeekPool * PoolShareFactor * PseudoInSafe / PseudoMass;
        //    PseudoInSafe / PseudoToTokenExchangeRate
        //)
        uint256 poolShare = FixedPointMathLib.mulWad(
            FixedPointMathLib.mulWad(initEpochPool_ * 1e18, poolShareFactor_),
            ((tokensInSafe_ * 1e18) / tokensMass_)
        ) / 1e18;
        uint256 maxObtainable = (tokensInSafe_ * 1e18) / tokensExchangeRate_;

        dbnAmount = FixedPointMathLib.min(
            FixedPointMathLib.min(remainingEpochPool_, poolShare),
            maxObtainable
        );
        tokenToSpend = dbnToFarmTokens(dbnAmount, tokensExchangeRate_);
    }

    function dbnToFarmTokens(
        uint256 dbnAmount_,
        uint256 tokensExchangeRate_
    ) internal pure returns (uint256) {
        return
            FixedPointMathLib.mulWad(dbnAmount_ * 1e18, tokensExchangeRate_) /
            1e18;
    }
}
