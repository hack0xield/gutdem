// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC1363Receiver} from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDemNft} from "../libraries/LibDemNft.sol";

contract SaleFacet is Modifiers, IERC1363Receiver {
    function setRewardManager(address rewardManager_) external onlyOwner {
        s.rewardManager = rewardManager_;
    }

    function withdrawDbn() external onlyRewardManager {
        IERC20(s.dbnContract).transfer(
            msg.sender,
            IERC20(s.dbnContract).balanceOf(address(this))
        );
    }

    function onTransferReceived(
        address operator,
        address,
        uint256 amount,
        bytes memory
    ) external override returns (bytes4) {
        require(
            msg.sender == address(s.dbnContract),
            "SaleFacet: onTransferReceived wrong sender"
        );
        require(s.isSaleEnabled == true, "SaleFacet: Purchase is disabled");

        uint256 nftAmount = amount / s.dbnPrice;
        require(nftAmount > 0, "SaleFacet: Too low amount");
        LibDemNft.mint(nftAmount, operator);

        return IERC1363Receiver.onTransferReceived.selector;
    }
}
