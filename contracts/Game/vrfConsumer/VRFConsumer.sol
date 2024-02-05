// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {FarmRaid} from "../facets/FarmRaid.sol";
import {VRFConsumerBase} from "./VRFConsumerBase.sol";

contract VRFConsumer is VRFConsumerBase {

    function requestRandomNumber() external returns (bytes32 requestId) {
        require(msg.sender == address(this), "VRFConsumer: Only contract access");

        require(s.LINK.transferFrom(address(tx.origin), address(this), s.vrfFee), "VRFConsumer: Can't send LINK");
        return requestRandomness(s.vrfKeyHash, s.vrfFee); // This is the function that makes the initial call to VRF.
    }

    /**
     * This is the function which VRF calls back to when it has generated the number.
     */
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
//        if (_requestId == s.raffleRequestId) {
//            SafeLotteryFacet(address(this)).raffleCallback(_randomness);
//        } else
        if ( s.raidRequests[_requestId].raidSuccessChance != 0 ) {
            FarmRaid(address(this)).raidCallback(_requestId, _randomness);
        } else {
            FarmRaid(address(this)).scoutCallback(_requestId, _randomness);
        }
    }
}