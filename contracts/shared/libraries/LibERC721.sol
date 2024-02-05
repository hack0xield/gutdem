// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721TokenReceiver} from "../interfaces/IERC721TokenReceiver.sol";

library LibERC721 {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(
        address indexed _owner,
        address indexed _approved,
        uint256 indexed _tokenId
    );

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(
        address indexed _owner,
        address indexed _operator,
        bool _approved
    );

    bytes4 internal constant ERC721_RECEIVED = 0x150b7a02;
    bytes4 internal constant ERC721_BATCH_RECEIVED = 0x4b808c46;

    function checkOnERC721Received(
        address operator_,
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) internal {
        uint256 size;
        assembly {
            size := extcodesize(to_)
        }
        if (size > 0) {
            require(
                ERC721_RECEIVED ==
                    IERC721TokenReceiver(to_).onERC721Received(
                        operator_,
                        from_,
                        tokenId_,
                        data_
                    ),
                "LibERC721: Transfer rejected/failed by to_"
            );
        }
    }

    function checkOnERC721BatchReceived(
        address operator_,
        address from_,
        address to_,
        uint256[] calldata tokenIds_,
        bytes calldata data_
    ) internal {
        uint256 size;
        assembly {
            size := extcodesize(to_)
        }
        if (size > 0) {
            require(
                ERC721_BATCH_RECEIVED ==
                    IERC721TokenReceiver(to_).onERC721BatchReceived(
                        operator_,
                        from_,
                        tokenIds_,
                        data_
                    ),
                "LibERC721: Transfer rejected/failed by to_"
            );
        }
    }
}
