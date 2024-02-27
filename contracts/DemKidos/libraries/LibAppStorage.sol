// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {LibDiamond} from "../../shared/diamond/lib/LibDiamond.sol";

struct AppStorage {
    address rewardManager;

    // Metadata
    /// @dev Token name
    string name;

    /// @dev Token symbol
    string symbol;

    /// @dev Current mint counter, monotonically increasing to ensure accurate ownership
    uint256 minted;

    uint256 totalNativeSupply;
    string tokenUri;

    // Mappings
    /// @dev Balance of user in fractional representation
    mapping(address => uint256) balanceOf;

    /// @dev Allowance of user in fractional representation
    mapping(address => mapping(address => uint256)) allowance;

    /// @dev Approval in native representaion
    mapping(uint256 => address) getApproved;

    /// @dev Approval for all in native representation
    mapping(address => mapping(address => bool)) isApprovedForAll;

    /// @dev Owner of id in native representation
    mapping(uint256 => address) ownerOf;

    /// @dev Array of owned ids in native representation
    mapping(address => uint256[]) owned;

    /// @dev Tracks indices for the _owned mapping
    mapping(uint256 => uint256) ownedIndex;
}

library LibAppStorage {
    function diamondStorage() internal pure returns (AppStorage storage ds) {
        assembly {
            ds.slot := 0
        }
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyOwner() {
        require(
            LibDiamond.contractOwner() == msg.sender,
            "LibAppStorage: Only owner"
        );
        _;
    }

    modifier onlyRewardManager() {
        require(
            s.rewardManager == msg.sender,
            "LibAppStorage: Only reward manager"
        );
        _;
    }
}
