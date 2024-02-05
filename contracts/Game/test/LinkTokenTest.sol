// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {MockLinkToken} from "@chainlink/contracts/src/v0.8/mocks/MockLinkToken.sol";

contract LinkTokenTest is MockLinkToken {

    function transferFrom(address from_, address to_, uint256 value_) external returns (bool) {
        balances[from_] = balances[from_] - value_;
        balances[to_] = balances[to_] + value_;
        return true;
    }
}
