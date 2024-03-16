// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "../../shared/diamond/lib/LibDiamond.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {DoubleEndedQueue} from "./DoubleEndedQueue.sol";

uint256 constant COINS_TO_TOKEN = 10000;

struct AppStorage {
    string name;
    string symbol;
    string tokenUri;

    uint256 totalSupply;
    uint256 minted;

    DoubleEndedQueue.Uint256Deque storedERC721Ids;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) balanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) isApprovedForAll;

    /// @dev Packed representation of ownerOf and owned indices
    mapping(uint256 => uint256) ownedData;

    /// @dev Array of owned ids in ERC-721 representation
    mapping(address => uint256[]) owned;

    /// @dev Addresses that are exempt from ERC-721 transfer, typically for gas savings (pairs, routers, etc)
    mapping(address => bool) erc721TransferExempt;

    // whitelist drop related
    address rewardManager;
    address sigVerifier;
    BitMaps.BitMap wlBitMap;
    uint256 ticketsCount;
    uint256 dropPrice;

    // mint related
    uint256 maxMintNfts;
    uint256 mintPrice;
    bool isMintEnabled;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyOwner() {
        require(
            LibDiamond.contractOwner() == msg.sender,
            "LibAppStorage: Only owner"
        );
        _;
    }

    modifier onlyRewardManager() {
        require(
            s.rewardManager == msg.sender,
            "LibAppStorage: Only reward manager"
        );
        _;
    }
}
