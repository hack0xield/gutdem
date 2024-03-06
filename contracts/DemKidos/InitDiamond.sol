// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

import {AppStorage} from "./libraries/LibAppStorage.sol";
import {LibDiamond} from "../shared/diamond/lib/LibDiamond.sol";
import {IOwnable} from "../shared/diamond/interfaces/IOwnable.sol";
import {IDiamondCut} from "../shared/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../shared/diamond/interfaces/IDiamondLoupe.sol";
import {IERC404} from "./interfaces/IERC404.sol";

contract InitDiamond {
    AppStorage internal s;

    struct Args {
        string name;
        string symbol;
        string tokenUri;

        address rewardManager;
        uint256 ticketsCount;
    }

    function init(Args memory args_) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IERC20).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721).interfaceId] = true;
        ds.supportedInterfaces[type(IERC404).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721Receiver).interfaceId] = true;
        ds.supportedInterfaces[type(IOwnable).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        s.name = args_.name;
        s.symbol = args_.symbol;
        s.tokenUri = args_.tokenUri;

        s.rewardManager = args_.rewardManager;
        s.ticketsCount = args_.ticketsCount;

        initWlBitmap();
    }

    function initWlBitmap() internal {
        // Init whitelistDrop bitmap
        uint256 bucketsCount = s.ticketsCount / 256 + 1;
        for (uint bucket = 0; bucket < bucketsCount; ++bucket) {
            s.wlBitMap._data[bucket] = type(uint256).max;
        }
    }
}
