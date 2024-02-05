// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {LibAppStorage, AppStorage, DemRebelData} from "./LibAppStorage.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";

library LibDemRebel {
    uint256 public constant FIRST_MINT_LIMIT = 1000;
    uint256 public constant SECOND_MINT_LIMIT = 5000;

    function tokenBaseURI(
        uint256 tokenId_
    ) internal view returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();

        string storage baseURI = s.baseURI1;
        if (tokenId_ >= FIRST_MINT_LIMIT) {
            baseURI = s.baseURI2;
        } else if (tokenId_ >= SECOND_MINT_LIMIT) {
            baseURI = s.baseURI3;
        }

        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, Strings.toString(tokenId_))
                : s.cloneBoxURI;
    }

    function getDemRebel(
        uint256 tokenId_
    ) internal view returns (DemRebelData memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        return s.demRebels[tokenId_];
    }

    function transfer(address from_, address to_, uint256 tokenId_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.approved[tokenId_] != address(0)) {
            delete s.approved[tokenId_];
            emit LibERC721.Approval(from_, address(0), tokenId_);
        }

        setOwner(tokenId_, to_);
    }

    function setOwner(uint256 id_, address newOwner_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        address oldOwner = s.demRebels[id_].owner;

        s.demRebels[id_].owner = newOwner_;
        removeIndex(id_, oldOwner);
        addIndex(id_, newOwner_);

        emit LibERC721.Transfer(oldOwner, newOwner_, id_);
    }

    function removeIndex(uint256 tokenId_, address from_) internal {
        if (from_ != address(0)) {
            AppStorage storage s = LibAppStorage.diamondStorage();
            uint256[] storage ownerTokenIdsFrom = s.ownerTokenIds[from_];
            mapping(uint256 => uint256) storage ownerTokenIdIndexesFrom = s
                .ownerTokenIdIndexes[from_];

            uint256 index = ownerTokenIdIndexesFrom[tokenId_];
            uint256 lastIndex = ownerTokenIdsFrom.length - 1;
            if (index != lastIndex) {
                uint256 lastTokenId = ownerTokenIdsFrom[lastIndex];
                ownerTokenIdsFrom[index] = lastTokenId;
                ownerTokenIdIndexesFrom[lastTokenId] = index;
            }
            ownerTokenIdsFrom.pop();
            delete ownerTokenIdIndexesFrom[tokenId_];
        }
    }

    function addIndex(uint256 tokenId_, address to_) internal {
        if (to_ != address(0)) {
            AppStorage storage s = LibAppStorage.diamondStorage();
            uint256[] storage ownerTokenIds = s.ownerTokenIds[to_];

            s.ownerTokenIdIndexes[to_][tokenId_] = ownerTokenIds.length;
            ownerTokenIds.push(tokenId_);
        }
    }

    function validateAndLowerName(
        string memory _name
    ) internal pure returns (string memory) {
        bytes memory name = abi.encodePacked(_name);
        uint256 len = name.length;

        require(len != 0, "LibDemRebel: Name can't be 0 chars");
        require(
            len < 26,
            "LibDemRebel: Name can't be greater than 25 characters"
        );

        uint256 char = uint256(uint8(name[0]));
        require(char != 32, "LibDemRebel: First char of name can't be a space");

        char = uint256(uint8(name[len - 1]));
        require(char != 32, "LibDemRebel: Last char of name can't be a space");

        for (uint256 i; i < len; i++) {
            char = uint256(uint8(name[i]));
            require(
                char > 31 && char < 127,
                "LibDemRebel: Invalid character in DemRebel name"
            );

            if (char < 91 && char > 64) {
                name[i] = bytes1(uint8(char + 32));
            }
        }

        return string(name);
    }
}
