//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {DoubleEndedQueue} from "../libraries/DoubleEndedQueue.sol";
import {ERC20Events} from "../libraries/ERC20Events.sol";
import {ERC721Events} from "../libraries/ERC721Events.sol";

import {Modifiers, COINS_TO_TOKEN} from "../libraries/LibAppStorage.sol";
import {IERC404} from "../interfaces/IERC404.sol";

contract DemKidos is IERC404, Modifiers {
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;

    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;
    uint256 private constant _BITMASK_OWNED_INDEX = ((1 << 96) - 1) << 160;
    uint256 public constant ID_ENCODING_PREFIX = 1 << 255;

    function name() external view returns (string memory) {
        return s.name;
    }

    function symbol() external view returns (string memory) {
        return s.symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return s.totalSupply;
    }

    /// @notice Function to find owner of a given ERC-721 token
    function ownerOf(uint256 id_) external view returns (address erc721Owner) {
        erc721Owner = _getOwnerOf(id_);

        if (!_isValidTokenId(id_)) {
            revert InvalidTokenId();
        }

        if (erc721Owner == address(0)) {
            revert NotFound();
        }
    }

    function owned(address owner_) external view returns (uint256[] memory) {
        return s.owned[owner_];
    }

    function getOwnedIndex(
        uint256 id_
    ) public view returns (uint256 ownedIndex_) {
        uint256 data = s.ownedData[id_];

        assembly {
            ownedIndex_ := shr(160, data)
        }
    }

    function balanceOf(address account) external view returns (uint256) {
        return s.balanceOf[account];
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256) {
        return s.allowance[owner][spender];
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        return s.getApproved[tokenId];
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool) {
        return s.isApprovedForAll[owner][operator];
    }

    function erc721BalanceOf(address owner_) public view returns (uint256) {
        return s.owned[owner_].length;
    }

    function erc20BalanceOf(address owner_) public view returns (uint256) {
        return s.balanceOf[owner_];
    }

    function erc20TotalSupply() external view returns (uint256) {
        return s.totalSupply;
    }

    function erc721TotalSupply() external view returns (uint256) {
        return s.minted;
    }

    function getERC721QueueLength() external view returns (uint256) {
        return s.storedERC721Ids.length();
    }

    function getERC721TokensInQueue(
        uint256 start_,
        uint256 count_
    ) external view returns (uint256[] memory) {
        uint256[] memory tokensInQueue = new uint256[](count_);

        for (uint256 i = start_; i < start_ + count_; ) {
            tokensInQueue[i - start_] = s.storedERC721Ids.at(i);

            unchecked {
                ++i;
            }
        }

        return tokensInQueue;
    }

    function tokenURI(uint256) external view returns (string memory) {
        return s.tokenUri;
    }

    function setTokenURI(string memory uri_) external onlyOwner {
        s.tokenUri = uri_;
    }

    /// @notice Function for token approvals
    /// @dev This function assumes the operator is attempting to approve
    ///      an ERC-721 if valueOrId_ is a possibly valid ERC-721 token id.
    ///      Unlike setApprovalForAll, spender_ must be allowed to be 0x0 so
    ///      that approval can be revoked.
    function approve(
        address spender_,
        uint256 valueOrId_
    ) external returns (bool) {
        if (_isValidTokenId(valueOrId_)) {
            erc721Approve(spender_, valueOrId_);
        } else {
            return erc20Approve(spender_, valueOrId_);
        }

        return true;
    }

    function erc721Approve(address spender_, uint256 id_) public {
        // Intention is to approve as ERC-721 token (id).
        address erc721Owner = _getOwnerOf(id_);

        if (
            msg.sender != erc721Owner &&
            !s.isApprovedForAll[erc721Owner][msg.sender]
        ) {
            revert Unauthorized();
        }

        s.getApproved[id_] = spender_;

        emit ERC721Events.Approval(erc721Owner, spender_, id_);
    }

    /// @dev Providing type(uint256).max for approval value results in an
    ///      unlimited approval that is not deducted from on transfers.
    function erc20Approve(
        address spender_,
        uint256 value_
    ) public returns (bool) {
        // Prevent granting 0x0 an ERC-20 s.allowance.
        if (spender_ == address(0)) {
            revert InvalidSpender();
        }

        s.allowance[msg.sender][spender_] = value_;

        emit ERC20Events.Approval(msg.sender, spender_, value_);

        return true;
    }

    /// @notice Function for ERC-721 approvals
    function setApprovalForAll(address operator_, bool approved_) external {
        // Prevent approvals to 0x0.
        if (operator_ == address(0)) {
            revert InvalidOperator();
        }
        s.isApprovedForAll[msg.sender][operator_] = approved_;
        emit ERC721Events.ApprovalForAll(msg.sender, operator_, approved_);
    }

    /// @notice Function for mixed transfers from an operator that may be different than 'from'.
    /// @dev This function assumes the operator is attempting to transfer an ERC-721
    ///      if valueOrId is a possible valid token id.
    function transferFrom(
        address from_,
        address to_,
        uint256 valueOrId_
    ) public returns (bool) {
        if (_isValidTokenId(valueOrId_)) {
            erc721TransferFrom(from_, to_, valueOrId_);
        } else {
            // Intention is to transfer as ERC-20 token (value).
            return erc20TransferFrom(from_, to_, valueOrId_);
        }

        return true;
    }

    /// @notice Function for ERC-721 transfers from.
    /// @dev This function is recommended for ERC721 transfers.
    function erc721TransferFrom(
        address from_,
        address to_,
        uint256 id_
    ) public {
        // Prevent minting tokens from 0x0.
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        // Prevent burning tokens to 0x0.
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        if (from_ != _getOwnerOf(id_)) {
            revert Unauthorized();
        }

        // Check that the operator is either the sender or approved for the transfer.
        if (
            msg.sender != from_ &&
            !s.isApprovedForAll[from_][msg.sender] &&
            msg.sender != s.getApproved[id_]
        ) {
            revert Unauthorized();
        }

        // We only need to check ERC-721 transfer exempt status for the recipient
        // since the sender being ERC-721 transfer exempt means they have already
        // had their ERC-721s stripped away during the rebalancing process.
        if (erc721TransferExempt(to_)) {
            revert RecipientIsERC721TransferExempt();
        }

        // Transfer 1 * _units() ERC-20 and 1 ERC-721 token.
        // ERC-721 transfer exemptions handled above. Can't make it to this point if either is transfer exempt.
        _transferERC20(from_, to_, _units());
        _transferERC721(from_, to_, id_);
    }

    /// @notice Function for ERC-20 transfers from.
    /// @dev This function is recommended for ERC20 transfers
    function erc20TransferFrom(
        address from_,
        address to_,
        uint256 value_
    ) public returns (bool) {
        // Prevent minting tokens from 0x0.
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        // Prevent burning tokens to 0x0.
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        uint256 allowed = s.allowance[from_][msg.sender];

        // Check that the operator has sufficient s.allowance.
        if (allowed != type(uint256).max) {
            s.allowance[from_][msg.sender] = allowed - value_;
        }

        // Transferring ERC-20s directly requires the _transferERC20WithERC721 function.
        // Handles ERC-721 exemptions internally.
        return _transferERC20WithERC721(from_, to_, value_);
    }

    /// @notice Function for ERC-20 transfers.
    /// @dev This function assumes the operator is attempting to transfer as ERC-20
    ///      given this function is only supported on the ERC-20 interface.
    ///      Treats even large amounts that are valid ERC-721 ids as ERC-20s.
    function transfer(address to_, uint256 value_) external returns (bool) {
        // Prevent burning tokens to 0x0.
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        // Transferring ERC-20s directly requires the _transferERC20WithERC721 function.
        // Handles ERC-721 exemptions internally.
        return _transferERC20WithERC721(msg.sender, to_, value_);
    }

    /// @notice Function for ERC-721 transfers with contract support.
    /// This function only supports moving valid ERC-721 ids, as it does not exist on the ERC-20
    /// spec and will revert otherwise.
    function safeTransferFrom(
        address from_,
        address to_,
        uint256 id_
    ) external {
        safeTransferFrom(from_, to_, id_, "");
    }

    /// @notice Function for ERC-721 transfers with contract support and callback data.
    /// This function only supports moving valid ERC-721 ids, as it does not exist on the
    /// ERC-20 spec and will revert otherwise.
    function safeTransferFrom(
        address from_,
        address to_,
        uint256 id_,
        bytes memory data_
    ) public {
        if (!_isValidTokenId(id_)) {
            revert InvalidTokenId();
        }

        transferFrom(from_, to_, id_);

        if (
            to_.code.length != 0 &&
            IERC721Receiver(to_).onERC721Received(
                msg.sender,
                from_,
                id_,
                data_
            ) !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    function setERC721TransferExempt(
        address target_,
        bool state_
    ) external onlyOwner {
        _setERC721TransferExempt(target_, state_);
    }

    /// @notice Function for self-exemption
    function setSelfERC721TransferExempt(bool state_) external {
        _setERC721TransferExempt(msg.sender, state_);
    }

    /// @notice Function to check if address is transfer exempt
    function erc721TransferExempt(address target_) public view returns (bool) {
        return target_ == address(0) || s.erc721TransferExempt[target_];
    }

    function initMintSupply(uint256 maxTotalSupplyERC721_) external onlyOwner {
        // Do not mint the ERC721s to the initial owner, as it's a waste of gas.
        _setERC721TransferExempt(s.rewardManager, true);
        _mintERC20(s.rewardManager, maxTotalSupplyERC721_ * _units());
    }

    function _units() internal pure returns (uint256) {
        return 10 ** decimals() * COINS_TO_TOKEN;
    }

    /// @notice For a token token id to be considered valid, it just needs
    ///         to fall within the range of possible token ids, it does not
    ///         necessarily have to be s.minted yet.
    function _isValidTokenId(uint256 id_) internal pure returns (bool) {
        return id_ > ID_ENCODING_PREFIX && id_ != type(uint256).max;
    }

    /// @notice This is the lowest level ERC-20 transfer function, which
    ///         should be used for both normal ERC-20 transfers as well as minting.
    /// Note that this function allows transfers to and from 0x0.
    function _transferERC20(
        address from_,
        address to_,
        uint256 value_
    ) internal {
        // Minting is a special case for which we should not check the balance of
        // the sender, and we should increase the total supply.
        if (from_ == address(0)) {
            s.totalSupply += value_;
        } else {
            // Deduct value from sender's balance.
            s.balanceOf[from_] -= value_;
        }

        // Update the recipient's balance.
        // Can be unchecked because on mint, adding to s.totalSupply is checked, and on transfer balance deduction is checked.
        unchecked {
            s.balanceOf[to_] += value_;
        }

        emit ERC20Events.Transfer(from_, to_, value_);
    }

    /// @notice Consolidated record keeping function for transferring ERC-721s.
    /// @dev Assign the token to the new owner, and remove from the old owner.
    /// Note that this function allows transfers to and from 0x0.
    /// Does not handle ERC-721 exemptions.
    function _transferERC721(address from_, address to_, uint256 id_) internal {
        // If this is not a mint, handle record keeping for transfer from previous owner.
        if (from_ != address(0)) {
            // On transfer of an NFT, any previous approval is reset.
            delete s.getApproved[id_];

            uint256 updatedId = s.owned[from_][s.owned[from_].length - 1];
            if (updatedId != id_) {
                uint256 updatedIndex = getOwnedIndex(id_);
                // update s.owned for sender
                s.owned[from_][updatedIndex] = updatedId;
                // update index for the moved id
                _setOwnedIndex(updatedId, updatedIndex);
            }

            // pop
            s.owned[from_].pop();
        }

        // Check if this is a burn.
        if (to_ != address(0)) {
            // If not a burn, update the owner of the token to the new owner.
            // Update owner of the token to the new owner.
            _setOwnerOf(id_, to_);
            // Push token onto the new owner's stack.
            s.owned[to_].push(id_);
            // Update index for new owner's stack.
            _setOwnedIndex(id_, s.owned[to_].length - 1);
        } else {
            // If this is a burn, reset the owner of the token to 0x0 by deleting the token from s.ownedData.
            delete s.ownedData[id_];
        }

        emit ERC721Events.Transfer(from_, to_, id_);
    }

    /// @notice Internal function for ERC-20 transfers. Also handles any ERC-721 transfers that may be required.
    // Handles ERC-721 exemptions.
    function _transferERC20WithERC721(
        address from_,
        address to_,
        uint256 value_
    ) internal returns (bool) {
        uint256 erc20BalanceOfSenderBefore = erc20BalanceOf(from_);
        uint256 erc20BalanceOfReceiverBefore = erc20BalanceOf(to_);

        _transferERC20(from_, to_, value_);

        // Preload for gas savings on branches
        bool isFromERC721TransferExempt = erc721TransferExempt(from_);
        bool isToERC721TransferExempt = erc721TransferExempt(to_);

        // Skip _withdrawAndStoreERC721 and/or _retrieveOrMintERC721 for ERC-721 transfer exempt addresses
        // 1) to save gas
        // 2) because ERC-721 transfer exempt addresses won't always have/need ERC-721s corresponding to their ERC20s.
        if (isFromERC721TransferExempt && isToERC721TransferExempt) {
            // Case 1) Both sender and recipient are ERC-721 transfer exempt. No ERC-721s need to be transferred.
            // NOOP.
        } else if (isFromERC721TransferExempt) {
            // Case 2) The sender is ERC-721 transfer exempt, but the recipient is not. Contract should not attempt
            //         to transfer ERC-721s from the sender, but the recipient should receive ERC-721s
            //         from the bank/s.minted for any whole number increase in their balance.
            // Only cares about whole number increments.
            uint256 tokensToRetrieveOrMint = (s.balanceOf[to_] / _units()) -
                (erc20BalanceOfReceiverBefore / _units());
            for (uint256 i = 0; i < tokensToRetrieveOrMint; ) {
                _retrieveOrMintERC721(to_);
                unchecked {
                    ++i;
                }
            }
        } else if (isToERC721TransferExempt) {
            // Case 3) The sender is not ERC-721 transfer exempt, but the recipient is. Contract should attempt
            //         to withdraw and store ERC-721s from the sender, but the recipient should not
            //         receive ERC-721s from the bank/s.minted.
            // Only cares about whole number increments.
            uint256 tokensToWithdrawAndStore = (erc20BalanceOfSenderBefore /
                _units()) - (s.balanceOf[from_] / _units());
            for (uint256 i = 0; i < tokensToWithdrawAndStore; ) {
                _withdrawAndStoreERC721(from_);
                unchecked {
                    ++i;
                }
            }
        } else {
            // Case 4) Neither the sender nor the recipient are ERC-721 transfer exempt.
            // Strategy:
            // 1. First deal with the whole tokens. These are easy and will just be transferred.
            // 2. Look at the fractional part of the value:
            //   a) If it causes the sender to lose a whole token that was represented by an NFT due to a
            //      fractional part being transferred, withdraw and store an additional NFT from the sender.
            //   b) If it causes the receiver to gain a whole new token that should be represented by an NFT
            //      due to receiving a fractional part that completes a whole token, retrieve or mint an NFT to the recevier.

            // Whole tokens worth of ERC-20s get transferred as ERC-721s without any burning/minting.
            uint256 nftsToTransfer = value_ / _units();
            for (uint256 i = 0; i < nftsToTransfer; ) {
                // Pop from sender's ERC-721 stack and transfer them (LIFO)
                uint256 indexOfLastToken = s.owned[from_].length - 1;
                uint256 tokenId = s.owned[from_][indexOfLastToken];
                _transferERC721(from_, to_, tokenId);
                unchecked {
                    ++i;
                }
            }

            // If the transfer changes either the sender or the recipient's holdings from a fractional to a non-fractional
            // amount (or vice versa), adjust ERC-721s.

            // First check if the send causes the sender to lose a whole token that was represented by an ERC-721
            // due to a fractional part being transferred.
            //
            // Process:
            // Take the difference between the whole number of tokens before and after the transfer for the sender.
            // If that difference is greater than the number of ERC-721s transferred (whole _units()), then there was
            // an additional ERC-721 lost due to the fractional portion of the transfer.
            // If this is a self-send and the before and after balances are equal (not always the case but often),
            // then no ERC-721s will be lost here.
            if (
                erc20BalanceOfSenderBefore /
                    _units() -
                    erc20BalanceOf(from_) /
                    _units() >
                nftsToTransfer
            ) {
                _withdrawAndStoreERC721(from_);
            }

            // Then, check if the transfer causes the receiver to gain a whole new token which requires gaining
            // an additional ERC-721.
            //
            // Process:
            // Take the difference between the whole number of tokens before and after the transfer for the recipient.
            // If that difference is greater than the number of ERC-721s transferred (whole _units()), then there was
            // an additional ERC-721 gained due to the fractional portion of the transfer.
            // Again, for self-sends where the before and after balances are equal, no ERC-721s will be gained here.
            if (
                erc20BalanceOf(to_) /
                    _units() -
                    erc20BalanceOfReceiverBefore /
                    _units() >
                nftsToTransfer
            ) {
                _retrieveOrMintERC721(to_);
            }
        }

        return true;
    }

    /// @notice Internal function for ERC20 minting
    /// @dev This function will allow minting of new ERC20s.
    ///      If mintCorrespondingERC721s_ is true, and the recipient is not ERC-721 exempt, it will
    ///      also mint the corresponding ERC721s.
    /// Handles ERC-721 exemptions.
    function _mintERC20(address to_, uint256 value_) internal {
        /// You cannot mint to the zero address (you can't mint and immediately burn in the same transfer).
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        if (s.totalSupply + value_ > ID_ENCODING_PREFIX) {
            revert MintLimitReached();
        }

        _transferERC20WithERC721(address(0), to_, value_);
    }

    /// @notice Internal function for ERC-721 minting and retrieval from the bank.
    /// @dev This function will allow minting of new ERC-721s up to the total fractional supply. It will
    ///      first try to pull from the bank, and if the bank is empty, it will mint a new token.
    /// Does not handle ERC-721 exemptions.
    function _retrieveOrMintERC721(address to_) internal {
        if (to_ == address(0)) {
            revert InvalidRecipient();
        }

        uint256 id;

        if (!s.storedERC721Ids.empty()) {
            // If there are any tokens in the bank, use those first.
            // Pop off the end of the queue (FIFO).
            id = s.storedERC721Ids.popBack();
        } else {
            // Otherwise, mint a new token, should not be able to go over the total fractional supply.
            ++s.minted;

            // Reserve max uint256 for approvals
            if (s.minted == type(uint256).max) {
                revert MintLimitReached();
            }

            id = ID_ENCODING_PREFIX + s.minted;
        }

        address erc721Owner = _getOwnerOf(id);

        // The token should not already belong to anyone besides 0x0 or this contract.
        // If it does, something is wrong, as this should never happen.
        if (erc721Owner != address(0)) {
            revert AlreadyExists();
        }

        // Transfer the token to the recipient, either transferring from the contract's bank or minting.
        // Does not handle ERC-721 exemptions.
        _transferERC721(erc721Owner, to_, id);
    }

    /// @notice Internal function for ERC-721 deposits to bank (this contract).
    /// @dev This function will allow depositing of ERC-721s to the bank, which can be retrieved by future minters.
    // Does not handle ERC-721 exemptions.
    function _withdrawAndStoreERC721(address from_) internal {
        if (from_ == address(0)) {
            revert InvalidSender();
        }

        // Retrieve the latest token added to the owner's stack (LIFO).
        uint256 id = s.owned[from_][s.owned[from_].length - 1];

        // Transfer to 0x0.
        // Does not handle ERC-721 exemptions.
        _transferERC721(from_, address(0), id);

        // Record the token in the contract's bank queue.
        s.storedERC721Ids.pushFront(id);
    }

    /// @notice Initialization function to set pairs / etc, saving gas by avoiding mint / burn on unnecessary targets
    function _setERC721TransferExempt(address target_, bool state_) internal {
        if (target_ == address(0)) {
            revert InvalidExemption();
        }

        // Adjust the ERC721 balances of the target to respect exemption rules.
        // Despite this logic, it is still recommended practice to exempt prior to the target
        // having an active balance.
        if (state_) {
            _clearERC721Balance(target_);
        } else {
            _reinstateERC721Balance(target_);
        }

        s.erc721TransferExempt[target_] = state_;
    }

    /// @notice Function to reinstate balance on exemption removal
    function _reinstateERC721Balance(address target_) private {
        uint256 expectedERC721Balance = erc20BalanceOf(target_) / _units();
        uint256 actualERC721Balance = erc721BalanceOf(target_);

        for (uint256 i = 0; i < expectedERC721Balance - actualERC721Balance; ) {
            // Transfer ERC721 balance in from pool
            _retrieveOrMintERC721(target_);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Function to clear balance on exemption inclusion
    function _clearERC721Balance(address target_) private {
        uint256 erc721Balance = erc721BalanceOf(target_);

        for (uint256 i = 0; i < erc721Balance; ) {
            // Transfer out ERC721 balance
            _withdrawAndStoreERC721(target_);
            unchecked {
                ++i;
            }
        }
    }

    function _getOwnerOf(uint256 id_) internal view returns (address ownerOf_) {
        uint256 data = s.ownedData[id_];

        assembly {
            ownerOf_ := and(data, _BITMASK_ADDRESS)
        }
    }

    function _setOwnerOf(uint256 id_, address owner_) internal {
        uint256 data = s.ownedData[id_];

        assembly {
            data := add(
                and(data, _BITMASK_OWNED_INDEX),
                and(owner_, _BITMASK_ADDRESS)
            )
        }

        s.ownedData[id_] = data;
    }

    function _setOwnedIndex(uint256 id_, uint256 index_) internal {
        uint256 data = s.ownedData[id_];

        if (index_ > _BITMASK_OWNED_INDEX >> 160) {
            revert OwnedIndexOverflow();
        }

        assembly {
            data := add(
                and(data, _BITMASK_ADDRESS),
                and(shl(160, index_), _BITMASK_OWNED_INDEX)
            )
        }

        s.ownedData[id_] = data;
    }
}
