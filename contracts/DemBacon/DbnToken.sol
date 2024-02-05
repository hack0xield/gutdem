// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1363, ERC20} from "erc-payable-token/contracts/token/ERC1363/ERC1363.sol";

contract DbnToken is ERC1363, Ownable {
    struct Args {
        address rewardManager;
        string name;
        string symbol;
    }

    address public _rewardManager;

    modifier onlyRewardManager() {
        require(_rewardManager == msg.sender, "DbnToken: Only reward manager");
        _;
    }

    constructor(
        Args memory args_
    ) ERC20(args_.name, args_.symbol) Ownable(msg.sender) {
        _rewardManager = args_.rewardManager;
    }

    function mint(address account_, uint256 value_) external onlyRewardManager {
        _mint(account_, value_);
    }

    function setRewardManager(address rewardManager_) external onlyOwner {
        _rewardManager = rewardManager_;
    }
}
