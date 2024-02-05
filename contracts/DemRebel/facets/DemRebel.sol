// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DemRebelData, Modifiers} from "../libraries/LibAppStorage.sol";
import {LibDemRebel} from "../libraries/LibDemRebel.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";

contract DemRebel is Modifiers {
    event DemRebelNameSet(
        uint256 indexed tokenId,
        string oldName,
        string newName
    );

    function setDemRebelName(
        uint256 tokenId_,
        string calldata name_
    ) external onlyDemRebelOwner(tokenId_) {
        string memory lowerName = LibDemRebel.validateAndLowerName(name_);
        require(
            !s.demRebelNamesUsed[lowerName],
            "DemRebel: DemRebel name used already"
        );

        string memory existingName = s.demRebels[tokenId_].name;
        if (bytes(existingName).length > 0) {
            delete s.demRebelNamesUsed[
                LibDemRebel.validateAndLowerName(existingName)
            ];
        }

        s.demRebelNamesUsed[lowerName] = true;
        s.demRebels[tokenId_].name = name_;

        emit DemRebelNameSet(tokenId_, existingName, name_);
    }

    ///@notice Return the universal name of the NFT
    function name() external view returns (string memory) {
        return s.name;
    }

    /// @notice An abbreviated name for NFTs in this contract
    function symbol() external view returns (string memory) {
        return s.symbol;
    }

    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev URIs are defined in RFC 3986. The URI may point to a JSON file
    ///  that conforms to the "ERC721 Metadata JSON Schema".
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return LibDemRebel.tokenBaseURI(_tokenId);
    }

    /// @notice Change base URI of the NFT assets metadata
    /// @param _uri Base URI of the NFT assets metadata
    function setBaseURI1(string memory _uri) external onlyOwner {
        s.baseURI1 = _uri;
    }

    function setBaseURI2(string memory _uri) external onlyOwner {
        s.baseURI2 = _uri;
    }

    function setBaseURI3(string memory _uri) external onlyOwner {
        s.baseURI3 = _uri;
    }

    /// @notice Query the universal totalSupply of all NFTs ever minted
    /// @return The number of all NFTs that have been minted
    function totalSupply() external view returns (uint256) {
        return s.tokenIdsCount;
    }

    /// @notice Count all NFTs assigned to an owner
    /// @param owner_ An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address owner_) external view returns (uint256) {
        return s.ownerTokenIds[owner_].length;
    }

    /// @notice Enumerate valid NFTs
    /// @dev This work because we assuming sequential nfts count growth.
    /// Throws if `index_` >= `totalSupply()`.
    /// @param index_ A counter less than `totalSupply()`
    /// @return The token identifier for the `index_`th NFT,
    function tokenByIndex(uint256 index_) external view returns (uint256) {
        require(
            s.demRebels[index_].owner != address(0),
            "DemRebel: Rebel owner can't be address(0)"
        );
        return index_;
    }

    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `index_` >= `balanceOf(owner_)` or if
    ///  `owner_` is the zero address, representing invalid NFTs.
    /// @param owner_ An address where we are interested in NFTs owned by them
    /// @param index_ A counter less than `balanceOf(owner_)`
    /// @return The token identifier for the `index_`th NFT assigned to `owner_`,
    ///   (sort order not specified)
    function tokenOfOwnerByIndex(
        address owner_,
        uint256 index_
    ) external view returns (uint256) {
        require(
            index_ < s.ownerTokenIds[owner_].length,
            "DemRebel: index beyond owner balance"
        );
        return s.ownerTokenIds[owner_][index_];
    }

    /// @notice Get all the Ids of NFTs owned by an address
    /// @param owner_ The address to check for the NFTs
    /// @return an array of tokenId for each NFT
    function tokenIdsOfOwner(
        address owner_
    ) external view returns (uint256[] memory) {
        return s.ownerTokenIds[owner_];
    }

    /// @notice Get all details about all the NFTs owned by an address
    /// @param owner_ The address to check for the NFTs
    /// @return demRebels an array of structs,where each struct contains all the details of each NFT
    function getRebelsOfOwner(
        address owner_
    ) external view returns (DemRebelData[] memory demRebels) {
        uint256 length = s.ownerTokenIds[owner_].length;
        demRebels = new DemRebelData[](length);
        for (uint256 i; i < length; i++) {
            demRebels[i] = LibDemRebel.getDemRebel(s.ownerTokenIds[owner_][i]);
        }
    }

    /// @notice Get all details about NFT by id
    /// @param tokenId_ The identifier for an NFT
    /// @return struct, which contains all the details about NFT
    function getDemRebelData(
        uint256 tokenId_
    ) external view returns (DemRebelData memory) {
        return LibDemRebel.getDemRebel(tokenId_);
    }

    /// @notice Find the owner of an NFT
    /// @param tokenId_ The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 tokenId_) external view returns (address) {
        return s.demRebels[tokenId_].owner;
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `tokenId_` is not a valid NFT.
    /// @param tokenId_ The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 tokenId_) external view returns (address) {
        require(
            s.demRebels[tokenId_].owner != address(0),
            "DemRebel: tokenId is invalid"
        );
        return s.approved[tokenId_];
    }

    /// @notice Query if an address is an authorized operator for another address
    /// @param owner_ The address that owns the NFTs
    /// @param operator_ The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `owner_`, false otherwise
    function isApprovedForAll(
        address owner_,
        address operator_
    ) external view returns (bool) {
        return s.operators[owner_][operator_];
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless msg.sender is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `from_` is
    ///  not the current owner. Throws if `to_` is the zero address. Throws if
    ///  `tokenId_` is not a valid NFT. When transfer is complete, this function
    ///  checks if `to_` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `to_` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param from_ The current owner of the NFT
    /// @param to_ The new owner
    /// @param tokenId_ The NFT to transfer
    /// @param data_ Additional data with no specified format, sent in call to `to_`
    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes calldata data_
    ) external {
        internalTransferFrom(msg.sender, from_, to_, tokenId_);
        LibERC721.checkOnERC721Received(
            msg.sender,
            from_,
            to_,
            tokenId_,
            data_
        );
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param from_ The current owner of the NFT
    /// @param to_ The new owner
    /// @param tokenId_ The NFT to transfer
    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) external {
        internalTransferFrom(msg.sender, from_, to_, tokenId_);
        LibERC721.checkOnERC721Received(msg.sender, from_, to_, tokenId_, "");
    }

    /// @notice Transfers the ownership of multiple  NFTs from one address to another at once
    /// @dev Throws unless msg.sender is the current owner, an authorized
    ///  operator, or the approved address of each of the NFTs in `tokenIds_`. Throws if `from_` is
    ///  not the current owner. Throws if `to_` is the zero address. Throws if one of the NFTs in
    ///  `tokenIds_` is not a valid NFT. When transfer is complete, this function
    ///  checks if `to_` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721BatchReceived` on `to_` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721BatchReceived(address,address,uint256[],bytes)"))`.
    /// @param from_ The current owner of the NFTs
    /// @param to_ The new owner
    /// @param tokenIds_ An array containing the identifiers of the NFTs to transfer
    /// @param data_ Additional data with no specified format, sent in call to `to_`
    function safeBatchTransferFrom(
        address from_,
        address to_,
        uint256[] calldata tokenIds_,
        bytes calldata data_
    ) external {
        for (uint256 index = 0; index < tokenIds_.length; ) {
            internalTransferFrom(msg.sender, from_, to_, tokenIds_[index]);
            unchecked {
                ++index;
            }
        }
        LibERC721.checkOnERC721BatchReceived(
            msg.sender,
            from_,
            to_,
            tokenIds_,
            data_
        );
    }

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless msg.sender is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `from_` is
    ///  not the current owner. Throws if `to_` is the zero address. Throws if
    ///  `tokenId_` is not a valid NFT.
    /// @param from_ The current owner of the NFT
    /// @param to_ The new owner
    /// @param tokenId_ The NFT to transfer
    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) external {
        internalTransferFrom(msg.sender, from_, to_, tokenId_);
    }

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless msg.sender is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param approved_ The new approved NFT controller
    /// @param tokenId_ The NFT to approve
    function approve(address approved_, uint256 tokenId_) external {
        address owner = s.demRebels[tokenId_].owner;
        require(
            owner == msg.sender || s.operators[owner][msg.sender],
            "DemRebel: Not owner or operator of token."
        );
        s.approved[tokenId_] = approved_;
        emit LibERC721.Approval(owner, approved_, tokenId_);
    }

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of msg.sender's assets
    /// @dev Emits the ApprovalForAll event.
    /// @param operator_ Address to add to the set of authorized operators
    /// @param approved_ True if the operator is approved, false to revoke approval
    function setApprovalForAll(address operator_, bool approved_) external {
        s.operators[msg.sender][operator_] = approved_;
        emit LibERC721.ApprovalForAll(msg.sender, operator_, approved_);
    }

    // This function is used by transfer functions
    function internalTransferFrom(
        address sender_,
        address from_,
        address to_,
        uint256 tokenId_
    ) internal {
        require(from_ != address(0), "DemRebel: _from can't be 0 address");
        require(
            from_ == s.demRebels[tokenId_].owner,
            "DemRebel: _from is not owner, transfer failed"
        );
        require(
            sender_ == from_ ||
                s.operators[from_][sender_] ||
                sender_ == s.approved[tokenId_],
            "DemRebel: Not owner or approved to transfer"
        );
        LibDemRebel.transfer(from_, to_, tokenId_);
    }
}
