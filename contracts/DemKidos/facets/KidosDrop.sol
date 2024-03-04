//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDemKidos} from "../libraries/LibDemKidos.sol";

contract KidosDrop is Modifiers {
    using BitMaps for BitMaps.BitMap;

    uint256 private constant DROP_AMOUNT = 0.5 ether;

    function setRewardManager(address rewardManager_) external onlyOwner {
        s.rewardManager = rewardManager_;
    }

    function setSigVerifierAddress(
        address address_
    ) external onlyRewardManager {
        s.sigVerifier = address_;
    }

    function isClaimed(uint256 ticketNumber_) external view returns (bool) {
        return !s.wlBitMap.get(ticketNumber_);
    }

    function whitelistDrop(
        bytes calldata signature_,
        uint256 ticketNumber_
    ) external {
        require(
            s.wlBitMap.get(ticketNumber_) == true,
            "KidosDrop: Already claimed"
        );

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(abi.encodePacked(msg.sender, ticketNumber_))
        );
        require(
            s.sigVerifier == ECDSA.recover(hash, signature_),
            "KidosDrop: Sig validation failed"
        );
        s.wlBitMap.unset(ticketNumber_);

        LibDemKidos.dropTokens(DROP_AMOUNT, msg.sender);
    }
}
