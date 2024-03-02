//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DemKidos} from "../facets/DemKidos.sol";

contract MinimalERC404 is DemKidos {

  function mintERC20(address account_, uint256 value_) external onlyOwner {
    _mintERC20(account_, value_);
  }
}
