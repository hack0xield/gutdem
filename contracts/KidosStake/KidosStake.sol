//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KidosStake is Ownable, IERC721Receiver {
    address private _rewardManager;
    address private _kidos;
    bool private _isStakeEnabled;

    mapping(uint256 => address) private _originalOwner;
    mapping(address => uint256[]) private _ownerTokens;
    mapping(uint256 => uint256) private _tokenIndex;
    mapping(uint256 => uint256) private _claimedTime;

    uint256 public constant CLAIM_REWARD = 40 ether; //40 ERC20 Kidos
    uint256 public constant STAKE_PERIOD = 24 hours;

    constructor(address kidos_) Ownable(msg.sender) {
        _kidos = kidos_;
    }

    function stakedTokens(
        address owner_
    ) external view returns (uint256[] memory) {
        return _ownerTokens[owner_];
    }

    function isStakeEnabled() external view returns (bool) {
        return _isStakeEnabled;
    }

    function setStakeEnabled(bool enable_) external {
        require(
            _rewardManager == msg.sender,
            "KidosStake: Only reward manager"
        );
        _isStakeEnabled = enable_;
    }

    function setRewardManager(address rewardManager_) external onlyOwner {
        _rewardManager = rewardManager_;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        require(_isStakeEnabled, "KidosStake: Stake is disabled");
        require(
            msg.sender == address(_kidos),
            "KidosStake: Expects DemKidos NFT"
        );

        _tokenStake(tokenId, from);
        _claimedTime[tokenId] = block.timestamp;

        return IERC721Receiver.onERC721Received.selector;
    }

    function claimAndWithdraw(uint256 tokenId) external {
        require(
            msg.sender == _originalOwner[tokenId],
            "KidosStake: Only original owner can withdraw/claim"
        );

        _claim(tokenId);
        _withdraw(tokenId);
    }

    function claim(uint256 tokenId) public {
        require(
            msg.sender == _originalOwner[tokenId],
            "KidosStake: Only original owner can claim"
        );

        _claim(tokenId);
    }

    function withdraw(uint256 tokenId) external {
        require(
            msg.sender == _originalOwner[tokenId],
            "KidosStake: Only original owner can withdraw"
        );

        _withdraw(tokenId);
    }

    function rewardToClaim(uint256 tokenId) public view returns(uint256) {
        if (!_isStakeEnabled) {
            return 0;
        }

        uint256 timePassed = block.timestamp - _claimedTime[tokenId];
        uint256 reward = (timePassed / STAKE_PERIOD) * CLAIM_REWARD;

        return reward;
    }

    function _claim(uint256 tokenId) internal {
        uint256 reward = rewardToClaim(tokenId);
        if (reward > 0) {
            IERC20(address(_kidos)).transferFrom(
                _rewardManager,
                msg.sender,
                reward
            );

            uint256 timePassed = block.timestamp - _claimedTime[tokenId];
            uint256 unclaimedTime = timePassed % STAKE_PERIOD;
            _claimedTime[tokenId] = block.timestamp - unclaimedTime;
        }
    }

    function _withdraw(uint256 tokenId) internal {
        _tokenUnstake(tokenId);
        IERC721(address(_kidos)).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
    }

    function _tokenUnstake(uint256 tokenId_) internal {
        address staker = _originalOwner[tokenId_];
        require(staker != address(0), "KidosStake: not staked error");

        uint256[] storage ownerTokens = _ownerTokens[staker];
        uint256 index = _tokenIndex[tokenId_];
        uint256 lastIndex = ownerTokens.length - 1;
        if (index != lastIndex) {
            uint256 lastTokenId = ownerTokens[lastIndex];
            ownerTokens[index] = lastTokenId;
            _tokenIndex[lastTokenId] = index;
        }
        ownerTokens.pop();
        delete _tokenIndex[tokenId_];
        delete _originalOwner[tokenId_];
    }

    function _tokenStake(uint256 tokenId_, address staker_) internal {
        _originalOwner[tokenId_] = staker_;

        uint256[] storage ownerTokens = _ownerTokens[staker_];
        _tokenIndex[tokenId_] = ownerTokens.length;
        ownerTokens.push(tokenId_);
    }
}
