// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {Modifiers, RebelFarmInfo, RaidRequest} from "../libraries/LibAppStorage.sol";
import {LibFarmRaid} from "../libraries/LibFarmRaid.sol";
import {LibFarmCalc} from "../libraries/LibFarmCalc.sol";
import {LibRebelFarm} from "../libraries/LibRebelFarm.sol";

import {VRFConsumer} from "../vrfConsumer/VRFConsumer.sol";

contract FarmRaid is Modifiers {
    using BitMaps for BitMaps.BitMap;

    event FarmRaided(
        uint256 indexed attackerId,
        uint256 indexed farmId,
        bool isSuccess
    );
    event ScoutPerformed(uint256 indexed rebelId, uint256 indexed foundId);

    function scout(
        uint256 id_
    ) external onlyDemRebelOwner(id_) onlyActiveFarm(id_) {
        LibFarmRaid.initScout(id_);

        bytes32 requestId = VRFConsumer(address(this)).requestRandomNumber();
        s.scoutRequests[requestId] = id_;
    }

    function scoutCallback(bytes32 requestId_, uint256 randomness_) external {
        require(
            msg.sender == address(this),
            "FarmRaid: Only contract callback"
        );

        uint256 rebelId = s.scoutRequests[requestId_];
        uint256 foundId = LibFarmRaid.pickRandomFarm(rebelId, randomness_);
        assert(foundId != rebelId);

        s.scoutedFarm[rebelId] = foundId;
        s.isScoutDone.set(rebelId);
        emit ScoutPerformed(rebelId, foundId);

        s.scoutInProgress.unset(rebelId);
        delete s.scoutRequests[requestId_];
    }

    function isScoutInProgress(uint256 id_) external view returns (bool) {
        return s.scoutInProgress.get(id_);
    }

    function isScoutDone(uint256 id_) external view returns (bool) {
        return s.isScoutDone.get(id_);
    }

    function getScoutedFarm(uint256 id_) external view returns (uint256) {
        require(
            s.isScoutDone.get(id_) == true,
            "FarmRaidFacet: Scouting should be performed first"
        );

        return s.scoutedFarm[id_];
    }

    function setFarmRaidDuration(uint256 duration_) external onlyOwner {
        require(duration_ > 0, "FarmRaid: Duration should be greater than 0");
        s.farmRaidDuration = duration_;
    }

    function raid(
        uint24 id_,
        uint256 toddlerQty_
    ) external onlyDemRebelOwner(id_) {
        uint256 raidChance = LibFarmRaid.initRaid(id_, toddlerQty_);
        bytes32 requestId = VRFConsumer(address(this)).requestRandomNumber();
        s.raidRequests[requestId] = RaidRequest(id_, uint232(raidChance));
    }

    function raidCallback(bytes32 requestId_, uint256 randomness_) external {
        require(
            msg.sender == address(this),
            "FarmRaid: Only contract callback"
        );

        RaidRequest storage request = s.raidRequests[requestId_];
        bool result = randomness_ % 100 < request.raidSuccessChance;
        if (result) {
            LibFarmRaid.robSafe(request.pivotFarm);
        }
        emit FarmRaided(
            request.pivotFarm,
            s.scoutedFarm[request.pivotFarm],
            result
        );
        delete s.raidRequests[requestId_];
    }

    function isFarmRaidOngoing(uint256 id_) external view returns (bool) {
        return LibFarmRaid.isRaidOngoing(id_);
    }

    function isFarmRaidFinished(uint256 id_) external view returns (bool) {
        return LibFarmRaid.isRaidFinished(id_);
    }

    function timeToFinishFarmRaid(uint256 id_) external view returns (uint256) {
        return LibFarmRaid.timeToFinishRaid(id_);
    }

    function returnToddlers(uint256 id_) external onlyDemRebelOwner(id_) {
        require(
            LibFarmRaid.isRaidFinished(id_),
            "FarmRaid: The raid is not finished yet"
        );

        s.toddlerInRaidQty[id_] = 0;
    }

    function getActiveToddlers(uint256 id_) external view returns (uint256) {
        return LibFarmRaid.getActiveToddlers(id_);
    }

    function getRebelFarmInfo(
        uint256 id_
    ) external view returns (RebelFarmInfo memory) {
        RebelFarmInfo memory farmInfo;
        farmInfo.isFarmActivated = LibRebelFarm.isFarmActivated(id_);
        farmInfo.farmTier = s.farmTier[id_];
        farmInfo.toddlerCount = LibRebelFarm.farmToddlerQty(id_);
        farmInfo.growerCount = LibRebelFarm.farmGrowerQty(id_);
        farmInfo.activeToddlers = LibFarmRaid.getActiveToddlers(id_);
        farmInfo.farmRate = LibRebelFarm.getFarmRate(id_);
        farmInfo.harvestAmount = LibRebelFarm.harvestAmount(id_);
        farmInfo.upgradeCooldown = LibRebelFarm.farmUpgradeCooldown(id_);
        farmInfo.isScoutInProgress = s.scoutInProgress.get(id_);

        farmInfo.isScoutDone = s.isScoutDone.get(id_);
        if (farmInfo.isScoutDone) {
            farmInfo.scoutedFarm = s.scoutedFarm[id_];
            farmInfo.isFarmRaidOngoing = LibFarmRaid.isRaidOngoing(id_);
            if (farmInfo.isFarmRaidOngoing) {
                farmInfo.isFarmRaidFinished = LibFarmRaid.isRaidFinished(id_);
                farmInfo.timeToFinishFarmRaid = LibFarmRaid.timeToFinishRaid(
                    id_
                );
            }
        }

        return farmInfo;
    }

    function tierBonusToAttack(
        uint256 farmTier_
    ) external pure returns (uint256) {
        return LibFarmCalc.bonusToAttack(farmTier_);
    }

    function tierBonusToDefense(
        uint256 farmTier_
    ) external pure returns (uint256) {
        return LibFarmCalc.bonusToDefense(farmTier_);
    }

    function tierBonusToLoot(
        uint256 farmTier_
    ) external pure returns (uint256) {
        return LibFarmCalc.bonusToLoot(farmTier_);
    }

    function tierBonusToProtection(
        uint256 farmTier_
    ) external pure returns (uint256) {
        return LibFarmCalc.bonusToProtection(farmTier_);
    }
}
