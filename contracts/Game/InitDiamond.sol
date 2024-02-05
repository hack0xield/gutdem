// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {AppStorage} from "./libraries/LibAppStorage.sol";
import {LibDiamond} from "../shared/diamond/lib/LibDiamond.sol";
import {IDiamondCut} from "../shared/diamond/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../shared/diamond/interfaces/IDiamondLoupe.sol";
 
contract InitDiamond {
    AppStorage internal s;

    uint256 constant INIT_WEEK_POOL = 1_000_000 ether; //1_005_025

    struct Args {
        address demBaconAddress;
        address demRebelAddress;
        address demGrowerAddress;
        address demToddlerAddress;
        address safeAddress;

        uint256 activationPrice;
        uint256 farmPeriod;
        uint256 farmMaxTier;
        uint256 toddlerMaxCount;
        uint256 basicLootShare;
        uint256 farmRaidDuration;
        //uint256 prizeValue;

        uint256 poolShareFactor;

        uint256 vrfFee;
        bytes32 vrfKeyHash;
    }

    function init(Args memory _args) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        s.demBaconAddress = _args.demBaconAddress;
        s.demRebelAddress = _args.demRebelAddress;
        s.demGrowerAddress = _args.demGrowerAddress;
        s.demToddlerAddress = _args.demToddlerAddress;
        s.safeAddress = _args.safeAddress;

        s.activationPrice = _args.activationPrice;
        s.farmPeriod = _args.farmPeriod;
        s.farmMaxTier = _args.farmMaxTier;
        s.toddlerMaxCount = _args.toddlerMaxCount;
        s.basicLootShare = _args.basicLootShare;
        s.farmRaidDuration = _args.farmRaidDuration;
        //s.prizeValue = _args.prizeValue;

        s.initEpochPool = INIT_WEEK_POOL;
        s.poolShareFactor = _args.poolShareFactor;

        s.vrfFee = _args.vrfFee;
        s.vrfKeyHash = _args.vrfKeyHash;
    }
}
