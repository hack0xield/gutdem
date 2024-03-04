// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibAppStorage, AppStorage} from "./LibAppStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibDemKidos {
    function dropTokens(uint256 amount_, address recipient_) internal {
        AppStorage storage s = LibAppStorage.diamondStorage();

        IERC20(address(this)).transferFrom(
            s.rewardManager,
            recipient_,
            amount_
        );
    }
}
