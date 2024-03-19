//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDemKidos} from "../libraries/LibDemKidos.sol";

import "hardhat/console.sol";

contract KidosDrop is Modifiers {
    using BitMaps for BitMaps.BitMap;

    function setRewardManager(address rewardManager_) external onlyOwner {
        s.rewardManager = rewardManager_;
    }

    function dropPrice() external view returns (uint256) {
        return s.dropPrice;
    }

    function setDropPrice(uint256 dropPrice_) external onlyRewardManager {
        s.dropPrice = dropPrice_;
    }

    function isMintEnabled() external view returns (bool) {
        return s.isMintEnabled;
    }

    function setMintEnabled(bool isMintEnabled_) external onlyRewardManager {
        s.isMintEnabled = isMintEnabled_;
    }

    function mintPrice() external view returns (uint256) {
        return s.mintPrice;
    }

    function setMintPrice(uint256 mintPrice_) external onlyRewardManager {
        s.mintPrice = mintPrice_;
    }

    function maxMintNfts() external view returns (uint256) {
        return s.maxMintNfts;
    }

    function setMaxMintNfts(uint256 maxMintNfts_) external onlyRewardManager {
        s.maxMintNfts = maxMintNfts_;
    }

    function sigVerifierAddress() external view returns (address) {
        return s.sigVerifier;
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
        uint256 ticketNumber_,
        uint256 amount_
    ) external payable {
        require(s.sigVerifier != address(0), "KidosDrop: SigVer is not set");
        require(
            s.wlBitMap.get(ticketNumber_) == true,
            "KidosDrop: Already claimed"
        );
        require(
            s.dropPrice <= msg.value,
            "KidosDrop: Insufficient ethers value"
        );

        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(
            keccak256(abi.encodePacked(msg.sender, ticketNumber_, amount_))
        );
        require(
            s.sigVerifier == ECDSA.recover(hash, signature_),
            "KidosDrop: Sig validation failed"
        );
        s.wlBitMap.unset(ticketNumber_);

        LibDemKidos.dropTokens(amount_, msg.sender);
    }

    function mint(uint256 nftCount_) external payable {
        require(s.isMintEnabled, "KidosDrop: Mint is disabled");
        require(
            s.mintPrice * nftCount_ <= msg.value,
            "KidosDrop: Insufficient ethers value"
        );
        require(
            nftCount_ + s.owned[msg.sender].length <=
            s.maxMintNfts,
            "KidosDrop: Exceeded maximum nfts per user"
        );

        uint256 tokensAmount = LibDemKidos.tokensToCoins(nftCount_);
        LibDemKidos.dropTokens(tokensAmount, msg.sender);
    }

    function withdraw() external onlyRewardManager {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "KidosDrop: Withdraw failed");
    }
}
