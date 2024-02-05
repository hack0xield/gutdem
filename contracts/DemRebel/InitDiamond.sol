// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {AppStorage} from "./libraries/LibAppStorage.sol";
import {LibDiamond} from "../shared/diamond/lib/LibDiamond.sol";
import {IOwnable} from "../shared/diamond/interfaces/IOwnable.sol";
import {IDiamondCut} from "../shared/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../shared/diamond/interfaces/IDiamondLoupe.sol";
 
contract InitDiamond {
    AppStorage internal s;

    struct Args {
        string name;
        string symbol;
        string cloneBoxURI;
        uint256 maxDemRebels;
        uint256 demRebelSalePrice;
        uint256 whitelistSalePrice;
        uint256 maxDemRebelsPerUser;
        bool isSaleActive;
    }

    function init(Args memory _args) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721).interfaceId] = true;
        ds.supportedInterfaces[type(IOwnable).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        s.name = _args.name;
        s.symbol = _args.symbol;
        s.cloneBoxURI = _args.cloneBoxURI;
        s.maxDemRebels = _args.maxDemRebels;
        s.demRebelSalePrice = _args.demRebelSalePrice;
        s.whitelistSalePrice = _args.whitelistSalePrice;
        s.maxDemRebelsSalePerUser = _args.maxDemRebelsPerUser;
        s.isSaleActive = _args.isSaleActive;

        // Init whitelistSale bitmap
        uint256 bucketsCount = s.maxDemRebels / 256 + 1;
        for (uint bucket = 0; bucket < bucketsCount; ++bucket) {
            s.wlBitMap._data[bucket] = type(uint256).max;
        }
    }
}
