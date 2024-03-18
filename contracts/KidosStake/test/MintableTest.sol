//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IMintable} from "../IMintable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MintableTest is Ownable, ERC721, IMintable {
    uint256 public tokenSupply;

    address private minter;

    constructor(address minter_) ERC721("MintableTest", "Test") Ownable(msg.sender) {
        minter = minter_;
    }

    function setMinter(address minter_) external onlyOwner {
        minter = minter_;
    }

    function mint(address to_) external {
        require(msg.sender == minter);

        _mint(to_, tokenSupply);
        tokenSupply += 1;
    }
}