// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {LibFarmCalc} from "./LibFarmCalc.sol";
import {LibAppStorage, AppStorage} from "./LibAppStorage.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {ISafe} from "../interfaces/ISafe.sol";

library LibRebelFarm {
    using BitMaps for BitMaps.BitMap;

    function isFarmActivated(uint256 id_) internal view returns (bool) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.farmTier[id_] != 0;
    }

    function addGrowers(uint256 id_, uint24[] calldata growerIds_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 idsCount = growerIds_.length;
        require(
            LibFarmCalc.maxGrowSpots(s.farmTier[id_]) >=
                s.farmGrowersCount[id_] + idsCount,
            "LibRebelFarm: Insufficient farm tier"
        );

        for (uint256 i; i < idsCount; ++i) {
            uint256 id = growerIds_[i];

            require(
                IERC721(s.demGrowerAddress).ownerOf(id) == msg.sender,
                "LibRebelFarm: sender is not grower owner"
            );
            require(
                s.growerInFarm.get(id) == false,
                "LibRebelFarm: Grower already in farm"
            );

            s.growerInFarm.set(id);
        }
        s.farmGrowersCount[id_] += idsCount;
    }

    function releaseGrowers(
        uint256 id_,
        uint24[] calldata growerIds_
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 idsCount = growerIds_.length;
        require(
            s.farmGrowersCount[id_] >= idsCount,
            "LibRebelFarm: Not enough growers in farm"
        );

        for (uint256 i; i < idsCount; ++i) {
            uint256 id = growerIds_[i];

            require(
                IERC721(s.demGrowerAddress).ownerOf(id) == msg.sender,
                "LibRebelFarm: sender is not grower owner"
            );
            require(
                s.growerInFarm.get(id) == true,
                "LibRebelFarm: Grower is not in farm"
            );

            s.growerInFarm.unset(id);
        }
        s.farmGrowersCount[id_] -= idsCount;
    }

    function addToddlers(uint256 id_, uint24[] calldata toddlerIds_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 idsCount = toddlerIds_.length;
        require(
            s.farmToddlersCount[id_] + idsCount <= s.toddlerMaxCount,
            "LibRebelFarm: Above toddlers limit"
        );

        for (uint256 i; i < idsCount; ++i) {
            uint256 id = toddlerIds_[i];

            require(
                IERC721(s.demToddlerAddress).ownerOf(id) == msg.sender,
                "LibRebelFarm: sender is not toddler owner"
            );
            require(
                s.toddlerInFarm.get(id) == false,
                "LibRebelFarm: Toddler already in farm"
            );

            s.toddlerInFarm.set(id);
        }
        s.farmToddlersCount[id_] += idsCount;
    }

    function releaseToddlers(
        uint256 id_,
        uint24[] calldata toddlerIds_
    ) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 idsCount = toddlerIds_.length;
        require(
            s.farmToddlersCount[id_] >= idsCount,
            "LibRebelFarm: Not enough toddlers in farm"
        );

        for (uint256 i; i < idsCount; ++i) {
            uint256 id = toddlerIds_[i];

            require(
                IERC721(s.demToddlerAddress).ownerOf(id) == msg.sender,
                "LibRebelFarm: sender is not toddler owner"
            );
            require(
                s.toddlerInFarm.get(id) == true,
                "LibRebelFarm: Toddler is not in farm"
            );

            s.toddlerInFarm.unset(id);
        }
        s.farmToddlersCount[id_] -= idsCount;
    }

    function farmToddlerQty(uint256 id_) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.farmToddlersCount[id_];
    }

    function farmGrowerQty(uint256 id_) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.farmGrowersCount[id_];
    }

    function harvest(uint256 id_) internal {
        require(
            isFarmActivated(id_),
            "LibRebelFarm: Rebel Farm not activated!"
        );

        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 amount = harvestAmount(id_);
        if (amount > 0) {
            transferToSafe(id_, amount);
            s.farmStockHarvest[id_] = 0;
            updateHarvestTimestamp(id_);
        }
    }

    function transferToSafe(uint256 id_, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        ISafe(s.safeAddress).increaseSafeEntry(id_, amount);
    }

    function payFromSafe(uint256 id_, uint256 amount) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        ISafe(s.safeAddress).reduceSafeEntry(id_, amount);
    }

    function updateHarvestTimestamp(uint256 id_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.farmHarvestedTime[id_] = block.timestamp;
    }

    function updateHarvestStock(uint256 id_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        s.farmStockHarvest[id_] = harvestAmount(id_);
        updateHarvestTimestamp(id_);
    }

    function harvestAmount(uint256 id_) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 amount = s.farmStockHarvest[id_] +
            ((block.timestamp - s.farmHarvestedTime[id_]) / s.farmPeriod) *
            getFarmRate(id_);

        uint256 capacity = LibFarmCalc.harvestCap(s.farmTier[id_]);
        return amount > capacity ? capacity : amount;
    }

    function getFarmRate(uint256 id_) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        return farmGrowerQty(id_) * LibFarmCalc.growerFarmRate(s.farmTier[id_]);
    }

    function farmUpgradeCooldown(uint256 id_) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 cdTime = LibFarmCalc.upgradeCooldown(s.farmTier[id_]);
        if (cdTime < (block.timestamp - s.farmUpgradeTime[id_])) {
            return 0;
        }
        return cdTime - (block.timestamp - s.farmUpgradeTime[id_]);
    }

    function removeFromTierIndex(uint24 rebelId, uint256 tier) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        uint256 index = s.tierFarmIdIndexes[tier][rebelId];
        uint256 lastIndex = s.tierFarmIds[tier].length - 1;
        if (index != lastIndex) {
            uint24 lastTokenId = s.tierFarmIds[tier][lastIndex];
            s.tierFarmIds[tier][index] = lastTokenId;
            s.tierFarmIdIndexes[tier][lastTokenId] = index;
        }
        s.tierFarmIds[tier].pop();
        delete s.tierFarmIdIndexes[tier][rebelId];
    }

    function addToTierIndex(uint24 rebelId, uint256 tier) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.tierFarmIdIndexes[tier][rebelId] = s.tierFarmIds[tier].length;
        s.tierFarmIds[tier].push(rebelId);
    }
}
