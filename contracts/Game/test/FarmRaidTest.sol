// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {RaidRequest} from "../libraries/LibAppStorage.sol";
import {FarmRaid} from "../facets/FarmRaid.sol";
import {LibFarmRaid} from "../libraries/LibFarmRaid.sol";

import {VRFConsumer} from "../vrfConsumer/VRFConsumer.sol";

contract FarmRaidTest is FarmRaid {
    using BitMaps for BitMaps.BitMap;

    event ScoutedTest(bytes32 requestId, uint256 randomness);
    event FarmRaidedTest(bytes32 requestId, uint256 randomness);

    function scoutTest(
        uint256 id_
    ) external onlyDemRebelOwner(id_) onlyActiveFarm(id_) {
        LibFarmRaid.initScout(id_);

        bytes32 requestId = VRFConsumer(address(this)).requestRandomNumber();
        s.scoutRequests[requestId] = id_;

        uint256 randomness = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp))
        );

        emit ScoutedTest(requestId, randomness);
    }

    function scoutCallbackTest(
        bytes32 requestId_,
        uint256 randomness_
    ) external {
        uint256 rebelId = s.scoutRequests[requestId_];
        uint256 foundId = LibFarmRaid.pickRandomFarm(rebelId, randomness_);
        assert(foundId != rebelId);

        s.scoutedFarm[rebelId] = foundId;
        s.isScoutDone.set(rebelId);
        emit ScoutPerformed(rebelId, foundId);

        s.scoutInProgress.unset(rebelId);
        delete s.scoutRequests[requestId_];
    }

    function raidTest(
        uint24 id_,
        uint256 toddlerQty_
    ) external onlyDemRebelOwner(id_) {
        uint256 raidChance = LibFarmRaid.initRaid(id_, toddlerQty_);
        bytes32 requestId = VRFConsumer(address(this)).requestRandomNumber();
        s.raidRequests[requestId] = RaidRequest(id_, uint232(raidChance));

        uint256 randomness = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.timestamp))
        );

        emit FarmRaidedTest(requestId, randomness);
    }

    function raidCallbackTest(
        bytes32 requestId_,
        uint256 randomness_
    ) external {
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
}
