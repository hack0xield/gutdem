//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Modifiers} from "../libraries/LibAppStorage.sol";

contract DemKidos is Modifiers {
    // Events
    event ERC20Transfer(
        address indexed from,
        address indexed to,
        uint256 amount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event ERC721Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    // Errors
    error NotFound();
    error AlreadyExists();
    error InvalidRecipient();
    error InvalidSender();
    error UnsafeRecipient();
    error Unauthorized();
    error InvalidOwner();

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

    /// @notice Function to find owner of a given native token
    function ownerOf(uint256 id) external view returns (address owner) {
        owner = s.ownerOf[id];

        if (owner == address(0)) {
            revert NotFound();
        }
    }

    function owned(address owner) external view returns (uint256[] memory) {
        return s.owned[owner];
    }

    function ownedIndex(uint256 id) external view returns (uint256) {
        return s.ownedIndex[id];
    }

    function name() external view returns (string memory) {
        return s.name;
    }

    function symbol() external view returns (string memory) {
        return s.symbol;
    }

    function totalSupply() external view returns (uint256) {
        return s.totalNativeSupply * (10 ** decimals());
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function tokenURI(uint256) external view returns (string memory) {
        return s.tokenUri;
    }

    /// @notice Function for token approvals
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function approve(
        address spender,
        uint256 amountOrId
    ) external returns (bool) {
        if (amountOrId <= s.minted && amountOrId > 0) {
            address owner = s.ownerOf[amountOrId];

            if (msg.sender != owner && !s.isApprovedForAll[owner][msg.sender]) {
                revert Unauthorized();
            }

            s.getApproved[amountOrId] = spender;

            emit Approval(owner, spender, amountOrId);
        } else {
            s.allowance[msg.sender][spender] = amountOrId;

            emit Approval(msg.sender, spender, amountOrId);
        }

        return true;
    }

    function setApprovalForAll(address operator, bool approved) external {
        s.isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /// @notice Function for mixed transfers
    /// @dev This function assumes id / native if amount less than or equal to current max id
    function transferFrom(address from, address to, uint256 amountOrId) public {
        if (amountOrId <= s.minted) {
            if (from != s.ownerOf[amountOrId]) {
                revert InvalidSender();
            }

            if (to == address(0)) {
                revert InvalidRecipient();
            }

            if (
                msg.sender != from &&
                !s.isApprovedForAll[from][msg.sender] &&
                msg.sender != s.getApproved[amountOrId]
            ) {
                revert Unauthorized();
            }

            s.balanceOf[from] -= _getUnit();

            unchecked {
                s.balanceOf[to] += _getUnit();
            }

            s.ownerOf[amountOrId] = to;
            delete s.getApproved[amountOrId];

            // update s.owned for sender
            uint256 updatedId = s.owned[from][s.owned[from].length - 1];
            s.owned[from][s.ownedIndex[amountOrId]] = updatedId;
            // pop
            s.owned[from].pop();
            // update index for the moved id
            s.ownedIndex[updatedId] = s.ownedIndex[amountOrId];
            // push token to to owned
            s.owned[to].push(amountOrId);
            // update index for to owned
            s.ownedIndex[amountOrId] = s.owned[to].length - 1;

            emit Transfer(from, to, amountOrId);
            emit ERC20Transfer(from, to, _getUnit());
        } else {
            uint256 allowed = s.allowance[from][msg.sender];

            if (allowed != type(uint256).max)
                s.allowance[from][msg.sender] = allowed - amountOrId;

            _transfer(from, to, amountOrId);
        }
    }

    /// @notice Function for fractional transfers
    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
    }

    /// @notice Function for native transfers with contract support
    function safeTransferFrom(address from, address to, uint256 id) external {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            IERC721Receiver(to).onERC721Received(msg.sender, from, id, "") !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Function for native transfers with contract support and callback data
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public {
        transferFrom(from, to, id);

        if (
            to.code.length != 0 &&
            IERC721Receiver(to).onERC721Received(msg.sender, from, id, data) !=
            IERC721Receiver.onERC721Received.selector
        ) {
            revert UnsafeRecipient();
        }
    }

    /// @notice Internal function for fractional transfers
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 unit = _getUnit();
        uint256 balanceBeforeSender = s.balanceOf[from];
        uint256 balanceBeforeReceiver = s.balanceOf[to];

        s.balanceOf[from] -= amount;

        unchecked {
            s.balanceOf[to] += amount;
        }

        uint256 burnTokens = (balanceBeforeSender / unit) -
            (s.balanceOf[from] / unit);
        for (uint256 i = 0; i < burnTokens; i++) {
            _burn(from);
        }

        uint256 mintTokens = (s.balanceOf[to] / unit) -
            (balanceBeforeReceiver / unit);
        for (uint256 i = 0; i < mintTokens; i++) {
            _mint(to);
        }

        emit ERC20Transfer(from, to, amount);
        return true;
    }

    // Internal utility logic
    function _getUnit() internal pure returns (uint256) {
        return 10 ** decimals();
    }

    function _mint(address to) internal {
        if (to == address(0)) {
            revert InvalidRecipient();
        }

        unchecked {
            s.minted++;
        }

        uint256 id = s.minted;

        if (s.ownerOf[id] != address(0)) {
            revert AlreadyExists();
        }

        s.ownerOf[id] = to;
        s.owned[to].push(id);
        s.ownedIndex[id] = s.owned[to].length - 1;

        emit Transfer(address(0), to, id);
    }

    function _burn(address from) internal {
        if (from == address(0)) {
            revert InvalidSender();
        }

        uint256 id = s.owned[from][s.owned[from].length - 1];
        s.owned[from].pop();
        delete s.ownedIndex[id];
        delete s.ownerOf[id];
        delete s.getApproved[id];

        emit Transfer(from, address(0), id);
    }
}
