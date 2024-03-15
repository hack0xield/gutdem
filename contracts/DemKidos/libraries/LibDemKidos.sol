// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage, COINS_TO_TOKEN} from "./LibAppStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibDemKidos {

    function kidosUnits() pure internal returns(uint256) {
        return 10 ** 18 * COINS_TO_TOKEN;
    }

    function tokensToCoins(uint256 amount_) pure internal returns(uint256) {
        return amount_ * kidosUnits();
    }

    function dropTokens(uint256 amount_, address recipient_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IERC20(address(this)).transferFrom(
            s.rewardManager,
            recipient_,
            amount_
        );
    }

    function tokenUnstake(uint256 tokenId_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        address staker = s.originalOwner[tokenId_];
        require(staker != address(0), "LibDemKidos: not staked error");

        uint256[] storage ownerTokens = s.ownerTokens[staker];
        uint256 index = s.tokenIndex[tokenId_];
        uint256 lastIndex = ownerTokens.length - 1;
        if (index != lastIndex) {
            uint256 lastTokenId = ownerTokens[lastIndex];
            ownerTokens[index] = lastTokenId;
            s.tokenIndex[lastTokenId] = index;
        }
        ownerTokens.pop();
        delete s.tokenIndex[tokenId_];
        delete s.originalOwner[tokenId_];
    }

    function tokenStake(uint256 tokenId_, address staker_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        s.originalOwner[tokenId_] = staker_;

        uint256[] storage ownerTokens = s.ownerTokens[staker_];
        s.tokenIndex[tokenId_] = ownerTokens.length;
        ownerTokens.push(tokenId_);
    }
}
