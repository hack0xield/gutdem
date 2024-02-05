// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISafe {

    function increaseSafeEntry(uint256 tokenId_, uint256 value_) external;

    function reduceSafeEntry(uint256 tokenId_, uint256 value_) external;

    function getSafeContent(uint256 tokenId_) external view returns (uint256);

    function increaseSafeAllowness(uint256 tokenId_, uint256 value_) external;
}