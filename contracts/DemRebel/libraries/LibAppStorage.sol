// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import {LibDiamond} from "../../shared/diamond/lib/LibDiamond.sol";

struct DemRebelData {
    string name;
    address owner;
}

struct AppStorage {
    uint256 maxDemRebels;
    uint256 maxDemRebelsSalePerUser;
    uint256 demRebelSalePrice;
    bool isSaleActive;
    string name;
    string symbol;
    uint256 tokenIdsCount;

    address rewardManager;

    uint256 whitelistSalePrice;
    bool isWhitelistActive;
    address publicMintingAddress;
    BitMaps.BitMap wlBitMap;

    mapping(uint256 => DemRebelData) demRebels;
    mapping(address => uint256) balances;
    mapping(uint256 => address) approved;
    mapping(address => mapping(address => bool)) operators;
    mapping(string => bool) demRebelNamesUsed;

    string baseURI1;
    string baseURI2;
    string baseURI3;
    string cloneBoxURI;
}


library LibAppStorage {
    function diamondStorage() internal pure returns(AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyDemRebelOwner(uint256 _tokenId) {
        require(msg.sender == s.demRebels[_tokenId].owner, "LibAppStorage: Only DemRebel owner");
        _;
    }

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
