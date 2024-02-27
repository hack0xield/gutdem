// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
        uint256 totalNativeSupply;
        string tokenUri;
//
//        //Sale specifics
//        bool isSaleEnabled;
//        uint256 dbnPrice;
//        address dbnContract;
    }

    function init(Args memory args_) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

//        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
//        ds.supportedInterfaces[type(IERC1363Receiver).interfaceId] = true;
        ds.supportedInterfaces[type(IERC20).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721).interfaceId] = true;
//        ds.supportedInterfaces[type(IERC721TokenIds).interfaceId] = true;
        ds.supportedInterfaces[type(IOwnable).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
//
        s.name = args_.name;
        s.symbol = args_.symbol;
        s.totalNativeSupply = args_.totalNativeSupply;
        s.tokenUri = args_.tokenUri;
//
//        s.isSaleEnabled = args_.isSaleEnabled;
//        s.dbnPrice = args_.dbnPrice;
//        s.dbnContract = args_.dbnContract;
    }
}
