//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMintable} from "./IMintable.sol";

contract KidosStakeOneOff is Ownable, IERC721Receiver {
    address public rewardManager;
    bool public isStakeEnabled;
    IMintable public rewardToken;
    uint256 public stakePeriod;

    address private _kidos;

    mapping(uint256 => address) private _originalOwner;
    mapping(address => uint256[]) private _ownerTokens;
    mapping(uint256 => uint256) private _tokenIndex;
    mapping(uint256 => uint256) private _startTime;

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

    function setRewardToken(IMintable rewardToken_) external onlyRewardManager {
        rewardToken = rewardToken_;
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
        _startTime[tokenId_] = block.timestamp;

        return IERC721Receiver.onERC721Received.selector;
    }

    function timeUntilClaim(uint256 tokenId_) public view returns(uint256) {
        uint256 timePassed = block.timestamp - _startTime[tokenId_];
        if (timePassed > stakePeriod) {
            return 0;
        }
        return stakePeriod - timePassed;
    }

    function isClaimable(uint256 tokenId_) public view returns(bool) {
        return timeUntilClaim(tokenId_) == 0;
    }

    function claimAndWithdraw(uint256 tokenId_) external {
        require(
            msg.sender == _originalOwner[tokenId_],
            "KidosStake: Only original owner can withdraw/claim"
        );
        require(isClaimable(tokenId_), "KidosStake: Not claimable yet");

        rewardToken.mint(msg.sender);

        _withdraw(tokenId_);
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
