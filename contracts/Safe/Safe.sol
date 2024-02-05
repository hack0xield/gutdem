// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Safe is Ownable {
    mapping(uint256 => uint256) private balances;
    address public demBaconAddress;
    address public gameAddress;

    modifier onlyGameContract() {
        require(msg.sender == gameAddress, "Safe: Method usage disallowed");
        _;
    }

    constructor(address demBacon_) Ownable(msg.sender) {
        demBaconAddress = demBacon_;
    }

    function setGameContract(address gameContract_) external onlyOwner {
        gameAddress = gameContract_;
        IERC20(demBaconAddress).approve(gameAddress, type(uint256).max);
    }

    function increaseSafeEntry(
        uint256 tokenId_,
        uint256 value_
    ) external onlyGameContract {
        balances[tokenId_] += value_;
    }

    function reduceSafeEntry(
        uint256 tokenId_,
        uint256 value_
    ) external onlyGameContract {
        require(balances[tokenId_] >= value_, "Safe: reduce exceeds supply");
        balances[tokenId_] -= value_;
    }

    function getSafeContent(uint256 tokenId_) external view returns (uint256) {
        return balances[tokenId_];
    }
}
