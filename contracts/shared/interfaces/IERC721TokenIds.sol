// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC721TokenIds {
    function tokenIdsOfOwner(
        address _owner
    ) external view returns (uint256[] memory);
}
