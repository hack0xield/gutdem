//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KidosStake is Ownable, IERC721Receiver {
    address public rewardManager;
    bool public isStakeEnabled;
    IERC20 public rewardToken;
    uint256 public rewardAmount;
    uint256 public stakePeriod;

    address private _kidos;

    mapping(uint256 => address) private _originalOwner;
    mapping(address => uint256[]) private _ownerTokens;
    mapping(uint256 => uint256) private _tokenIndex;
    mapping(uint256 => uint256) private _claimedTime;

    modifier onlyRewardManager() {
        require(
            rewardManager == msg.sender,
            "KidosStake: Only reward manager"
        );
        _;
    }

    constructor(address kidos_) Ownable(msg.sender) {
        _kidos = kidos_;
    }

    function stakedTokens(
        address owner_
    ) external view returns (uint256[] memory) {
        return _ownerTokens[owner_];
    }

    function setRewardManager(address rewardManager_) external onlyOwner {
        rewardManager = rewardManager_;
    }

    function setStakeEnabled(bool enable_) external onlyRewardManager {
        isStakeEnabled = enable_;
    }

    function setRewardToken(IERC20 rewardToken_) external onlyRewardManager {
        rewardToken = rewardToken_;
    }

    function setRewardAmount(uint256 rewardAmount_) external onlyRewardManager {
        rewardAmount = rewardAmount_;
    }

    function setStakePeriod(uint256 stakePeriod_) external onlyRewardManager {
        stakePeriod = stakePeriod_;
    }

    function onERC721Received(
        address,
        address from_,
        uint256 tokenId_,
        bytes calldata
    ) external returns (bytes4) {
        require(isStakeEnabled, "KidosStake: Stake is disabled");
        require(
            msg.sender == address(_kidos),
            "KidosStake: Expects DemKidos NFT"
        );

        _tokenStake(tokenId_, from_);
        _claimedTime[tokenId_] = block.timestamp;

        return IERC721Receiver.onERC721Received.selector;
    }

    function rewardToClaim(uint256 tokenId_) public view returns(uint256) {
        if (!isStakeEnabled) {
            return 0;
        }

        uint256 timePassed = block.timestamp - _claimedTime[tokenId_];
        uint256 reward = (timePassed / stakePeriod) * rewardAmount;

        return reward;
    }

    function claimAndWithdraw(uint256 tokenId_) external {
        require(
            msg.sender == _originalOwner[tokenId_],
            "KidosStake: Only original owner can withdraw/claim"
        );

        _claim(tokenId_);
        _withdraw(tokenId_);
    }

    function claim(uint256 tokenId_) external {
        require(
            msg.sender == _originalOwner[tokenId_],
            "KidosStake: Only original owner can claim"
        );

        _claim(tokenId_);
    }

    function withdraw(uint256 tokenId_) external {
        require(
            msg.sender == _originalOwner[tokenId_],
            "KidosStake: Only original owner can withdraw"
        );

        _withdraw(tokenId_);
    }

    function _claim(uint256 tokenId_) internal {
        uint256 reward = rewardToClaim(tokenId_);
        if (reward > 0) {
            rewardToken.transferFrom(
                rewardManager,
                msg.sender,
                reward
            );

            uint256 timePassed = block.timestamp - _claimedTime[tokenId_];
            uint256 unclaimedTime = timePassed % stakePeriod;
            _claimedTime[tokenId_] = block.timestamp - unclaimedTime;
        }
    }

    function _withdraw(uint256 tokenId_) internal {
        _tokenUnstake(tokenId_);
        IERC721(address(_kidos)).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId_
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
