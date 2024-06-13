// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {INonfungiblePositionManager} from "uniswap-v3-periphery-0.8/contracts/interfaces/INonfungiblePositionManager.sol";

contract LiquidityLocker is Ownable {
    address public immutable feesRecipient;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    constructor(
        address feesRecipient_,
        address nonfungiblePositionManager_
    ) Ownable(msg.sender) {
        feesRecipient = feesRecipient_;
        nonfungiblePositionManager = INonfungiblePositionManager(nonfungiblePositionManager_);
    }

    /// @notice Collects the fees associated with provided liquidity
    /// @dev The contract must hold the erc721 token before it can collect fees
    /// @param tokenId The id of the erc721 token
    function collectFees(uint256 tokenId) external {
        // Caller must own the ERC721 position, meaning it must be a deposit
        // set amount0Max and amount1Max to uint256.max to collect all fees
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: feesRecipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        nonfungiblePositionManager.collect(params);
    }

    /// @notice Transfers the NFT to the owner
    /// @param tokenId The id of the erc721
    function retrieveNFT(uint256 tokenId) external onlyOwner {
        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
    }
}
