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
}
