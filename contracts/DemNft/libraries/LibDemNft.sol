// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LibAppStorage, AppStorage} from "./LibAppStorage.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";

library LibDemNft {
    function tokenBaseURI(
        uint256 tokenId_
    ) internal view returns (string memory) {
        AppStorage storage s = LibAppStorage.diamondStorage();
        string storage baseURI = s.baseURI;

        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, Strings.toString(tokenId_))
                : s.cloneBoxURI;
    }

    function transfer(address from_, address to_, uint256 tokenId_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        if (s.approved[tokenId_] != address(0)) {
            delete s.approved[tokenId_];
            emit LibERC721.Approval(from_, address(0), tokenId_);
        }

        setOwner(tokenId_, to_);
    }

    function mint(uint256 amount_, address to_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256 tokenId = s.tokenIdsCount;
        require(
            tokenId + amount_ <= s.maxNftCount,
            "LibDemNft: Exceed max nft supply"
        );

        for (uint256 i = 0; i < amount_; ) {
            setOwner(tokenId, to_);

            unchecked {
                ++tokenId;
                ++i;
            }
        }
        s.tokenIdsCount = tokenId;
    }

    function setOwner(uint256 tokenId_, address newOwner_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();
        address oldOwner = s.owners[tokenId_];

        s.owners[tokenId_] = newOwner_;
        removeIndex(tokenId_, oldOwner);
        addIndex(tokenId_, newOwner_);

        emit LibERC721.Transfer(oldOwner, newOwner_, tokenId_);
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
        AppStorage storage s = LibAppStorage.diamondStorage();
        uint256[] storage ownerTokenIds = s.ownerTokenIds[to_];

        s.ownerTokenIdIndexes[to_][tokenId_] = ownerTokenIds.length;
        ownerTokenIds.push(tokenId_);
    }
}
