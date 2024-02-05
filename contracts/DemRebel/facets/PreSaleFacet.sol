// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {LibDemRebel} from "../libraries/LibDemRebel.sol";
import {Modifiers} from "../libraries/LibAppStorage.sol";

contract PreSaleFacet is Modifiers {
    using BitMaps for BitMaps.BitMap;

    function setRewardManager(address rewardManager_) external onlyOwner {
        s.rewardManager = rewardManager_;
    }

    function isSaleActive() external view returns (bool) {
        return s.isSaleActive;
    }

    function setSaleIsActive(bool isActive_) external onlyRewardManager {
        s.isSaleActive = isActive_;
    }

    function isWhitelistActive() external view returns (bool) {
        return s.isWhitelistActive;
    }

    function isClaimed(uint256 ticketNumber_) external view returns (bool) {
        return !s.wlBitMap.get(ticketNumber_);
    }

    function setWhitelistActive(bool isActive_) external onlyRewardManager {
        s.isWhitelistActive = isActive_;
    }

    function setPublicMintingAddress(address address_) external onlyRewardManager {
        s.publicMintingAddress = address_;
    }

    function maxDemRebelsSalePerUser() external view returns (uint256) {
        return s.maxDemRebelsSalePerUser;
    }

    function setMaxDemRebelsSalePerUser(
        uint256 maxDemRebelsSalePerUser_
    ) external onlyRewardManager {
        s.maxDemRebelsSalePerUser = maxDemRebelsSalePerUser_;
    }

    function whitelistSale(
        bytes calldata signature_,
        uint256 ticketNumber_
    ) external payable {
        require(s.isWhitelistActive, "SaleFacet: Whitelist sale is disabled");
        require(
            s.wlBitMap.get(ticketNumber_) == true,
            "SaleFacet: Already claimed"
        );

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(abi.encodePacked(msg.sender, ticketNumber_))
        );
        require(
            s.publicMintingAddress == ECDSA.recover(hash, signature_),
            "SaleFacet: Sig validation failed"
        );
        s.wlBitMap.unset(ticketNumber_);

        require(
            s.whitelistSalePrice <= msg.value,
            "SaleFacet: Insufficient ethers value"
        );
        mint(1);
    }

    function withdraw() external onlyRewardManager {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "SaleFacet: Withdraw failed");
    }

    function purchaseDemRebels(uint256 count_) external payable {
        require(s.isSaleActive, "SaleFacet: Sale is disabled");
        require(
            s.demRebelSalePrice * count_ <= msg.value,
            "SaleFacet: Insufficient ethers value"
        );
        mint(count_);
    }

    function mint(uint256 rebelsCount_) internal {
        require(
            rebelsCount_ + s.tokenIdsCount <= s.maxDemRebels,
            "SaleFacet: Exceeded maximum DemRebels supply"
        );
        require(
            rebelsCount_ + s.ownerTokenIds[msg.sender].length <=
                s.maxDemRebelsSalePerUser,
            "SaleFacet: Exceeded maximum DemRebels per user"
        );

        checkMintLimit(rebelsCount_);

        uint256 tokenId = s.tokenIdsCount;
        for (uint256 i = 0; i < rebelsCount_; ) {
            LibDemRebel.setOwner(tokenId, msg.sender);

            unchecked {
                ++tokenId;
                ++i;
            }
        }
        s.tokenIdsCount = tokenId;
    }

    function checkMintLimit(uint256 requestedCount_) internal {
        // We don't want to overlap level, cause we consider to change price on new level
        require(
            s.tokenIdsCount >= LibDemRebel.FIRST_MINT_LIMIT ||
                s.tokenIdsCount + requestedCount_ <=
                LibDemRebel.FIRST_MINT_LIMIT,
            "SaleFacet: First part mint reached max cap"
        );
        require(
            s.tokenIdsCount >= LibDemRebel.SECOND_MINT_LIMIT ||
                s.tokenIdsCount + requestedCount_ <=
                LibDemRebel.SECOND_MINT_LIMIT,
            "SaleFacet: Second part mint reached max cap"
        );

        // Stop mint if some of the cap levels reached
        if (s.tokenIdsCount + requestedCount_ == LibDemRebel.FIRST_MINT_LIMIT) {
            s.isSaleActive = false;
            s.isWhitelistActive = false;
        } else if (
            s.tokenIdsCount + requestedCount_ == LibDemRebel.SECOND_MINT_LIMIT
        ) {
            s.isSaleActive = false;
            s.isWhitelistActive = false;
        }
    }
}
