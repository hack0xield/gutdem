//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDemKidos} from "../libraries/LibDemKidos.sol";

contract KidosStake is Modifiers, IERC721Receiver {
    uint256 public constant CLAIM_REWARD = 40 ether; //40 ERC20 Kidos
    uint256 public constant STAKE_PERIOD = 24 hours;

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        require(
            msg.sender == address(this),
            "KidosStake: Expects DemKidos NFT"
        );

        s.originalOwner[tokenId] = from;
        s.claimedTime[tokenId] = block.timestamp;

        return IERC721Receiver.onERC721Received.selector;
    }

    function claimAndWithdraw(uint256 tokenId) external {
        claim(tokenId);
        _withdraw(tokenId);
    }

    function withdraw(uint256 tokenId) external {
        require(
            msg.sender == s.originalOwner[tokenId],
            "KidosStake: Only original owner can claim"
        );

        _withdraw(tokenId);
    }

    function claim(uint256 tokenId) public {
        require(
            msg.sender == s.originalOwner[tokenId],
            "KidosStake: Only original owner can claim"
        );

        uint256 timePassed = block.timestamp - s.claimedTime[tokenId];
        uint256 rewardToClaim = (timePassed / STAKE_PERIOD) * CLAIM_REWARD;
        if (rewardToClaim > 0) {
            LibDemKidos.dropTokens(rewardToClaim, msg.sender);

            uint256 unclaimedTime = timePassed % STAKE_PERIOD;
            s.claimedTime[tokenId] = block.timestamp - unclaimedTime;
        }
    }

    function _withdraw(uint256 tokenId) internal {
        delete s.originalOwner[tokenId];
        IERC721(address(this)).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
    }
}
