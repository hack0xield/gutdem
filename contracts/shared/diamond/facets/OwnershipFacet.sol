// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "../lib/LibDiamond.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";

contract OwnershipFacet is IOwnable {
    function transferOwnership(address newOwner_) external override {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(newOwner_);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}
