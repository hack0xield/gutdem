// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibFarmCalc} from "../libraries/LibFarmCalc.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ISafe} from "../interfaces/ISafe.sol";

contract CashOut is Modifiers {
    using BitMaps for BitMaps.BitMap;

    function startNewCashOutEpoch(
        uint256 tokensMass_,
        uint256 exchangeRate_
    ) external onlyGameManager {
        s.tokensMass = tokensMass_;
        s.tokensExchangeRate = exchangeRate_;

        uint256 newInitEpochPool = LibFarmCalc.dbnPoolDecrease(s.initEpochPool);
        s.initEpochPool = newInitEpochPool;
        s.remainingEpochPool = newInitEpochPool;

        s.epochNumber += 1;
    }

    /**
     * Exchange all available tokens in Farm Safe for Dbn tokens.
     * Could also be limited by other factors.
     * Takes one of Min(remaining dbn in pool, farm pool share, farm harverst tokens)
     */
    function cashOut(uint256 id_) external onlyDemRebelOwner(id_) {
        uint256 tokenToSpend;
        uint256 dbnAmount;
        (tokenToSpend, dbnAmount) = getTokenDbnSwapPair(id_);

        if (dbnAmount > 0) {
            //TODO mint dbn here?
            IERC20(s.demBaconAddress).transferFrom(
                s.safeAddress,
                msg.sender,
                dbnAmount
            ); //TODO ??
            s.remainingEpochPool -= dbnAmount;

            ISafe(s.safeAddress).reduceSafeEntry(id_, tokenToSpend);
            s.epochToFarmCashOut[s.epochNumber].set(id_);
        }
    }

    function getTokenDbnSwapPair(
        uint256 id_
    ) public view returns (uint256 tokenToSpend, uint256 dbnAmount) {
        require(
            s.epochToFarmCashOut[s.epochNumber].get(id_) == false,
            "CashOut: Farm already cash out on this epoch!"
        );
        require(s.remainingEpochPool > 0, "CashOut: Token pool is empty!");

        uint256 tokensInSafe = ISafe(s.safeAddress).getSafeContent(id_);
        require(tokensInSafe > 0, "CashOut: Farm Safe is empty!");

        return
            LibFarmCalc.farmTokenToDbnSwapPair(
                s.remainingEpochPool,
                s.initEpochPool,
                s.poolShareFactor,
                tokensInSafe,
                s.tokensMass,
                s.tokensExchangeRate
            );

        //        return LibFarmCalc.farmTokenToDbnSwapPair(995_000 ether, 995_000 ether, 1.5 ether,
        //            100_000 ether, 1_300_000 ether, 5 ether);

        //        return LibFarmCalc.farmTokenToDbnSwapPair(114_000, 995_000, 1.5 ether,
        //            100_000, 1_300_000, 5 ether);
    }

    function isFarmCashOut(uint256 id_) external view returns (bool) {
        return s.epochToFarmCashOut[s.epochNumber].get(id_);
    }

    function buyFarmTokens(
        uint256 id_,
        uint256 dbnAmount_
    ) external onlyDemRebelOwner(id_) {
        IERC20(s.demBaconAddress).transferFrom(
            msg.sender,
            s.safeAddress,
            dbnAmount_
        ); //TODO ??

        uint256 farmTokensAmount = LibFarmCalc.dbnToFarmTokens(
            dbnAmount_,
            s.tokensExchangeRate
        );
        ISafe(s.safeAddress).increaseSafeEntry(id_, farmTokensAmount);
    }

    function getFarmTokensAmountFromDbn(
        uint256 dbnAmount_
    ) external view returns (uint256) {
        return LibFarmCalc.dbnToFarmTokens(dbnAmount_, s.tokensExchangeRate);
    }

    function getRemainingEpochPool() external view returns (uint256) {
        return s.remainingEpochPool;
    }

    function getInitEpochPool() external view returns (uint256) {
        return s.initEpochPool;
    }

    function getPoolShareFactor() external view returns (uint256) {
        return s.poolShareFactor;
    }

    function setPoolShareFactor(uint256 factor_) external onlyGameManager {
        s.poolShareFactor = factor_;
    }
}
