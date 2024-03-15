import {ethers} from "hardhat";

export let deployConfig = {
    dbnName: "DemBacon",
    dbnSymbol: "DBN",

    name: "TEST",
    symbol: "TT",
    maxDemRebels: 10000,
    demRebelSalePrice: ethers.parseEther("0.0008"),
    whitelistSalePrice: ethers.parseEther("0.0002"),
    maxDemRebelsSalePerUser: 10000,
    isSaleActive: true,
    cloneBoxURI: "ipfs://QmUzSR5yDqtsjnzfvfFZWe2JyEryhm7UgUfhKr9pkokG7C",

    //Cross Chain
    isRootChain: false,
    fxCheckpointManager: "0x2890bA17EfE978480615e330ecB65333b880928e",
    fxRoot: "0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA",
    fxChild: "0xCf73231F28B7331BBe3124B907840A94851f9f11",

    //Farm Nfts
    growerNftName: "GUTDEM Farm Grower",
    growerNftSymbol: "GDGRW",
    growerNftImage: "ipfs://QmUzSR5yDqtsjnzfvfFZWe2JyEryhm7UgUfhKr9pkokG7C",
    growerNftMax: 5000,
    growerSaleActive: true,
    growerSaleBcnPrice: ethers.parseEther("100"),

    toddlerNftName: "GUTDEM Farm Toddler",
    toddlerNftSymbol: "GDTDL",
    toddlerNftImage: "ipfs://QmUzSR5yDqtsjnzfvfFZWe2JyEryhm7UgUfhKr9pkokG7C",
    toddlerNftMax: 5000,
    toddlerSaleActive: true,
    toddlerSaleBcnPrice: ethers.parseEther("50"),

    //Kidos
    kidosMintPrice: ethers.parseEther("0.0003"),
    kidosTicketsCount: 10000,
    kidosMaxMintNfts: 10,

    //Weed Farm
    activationPrice: ethers.parseEther("1"),
    farmPeriod: 3600,
    farmMaxTier: 18,
    toddlerMaxCount: 20,
    basicLootShare: 50,
    farmRaidDuration: 86400,
    poolShareFactor: ethers.parseEther("1.5"),

    //Lottery
    //prizeValue: ethers.parseEther("100"),

    vrfKeyHash: "0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4",
    vrfFee: ethers.parseEther("0.0001"),
    vrfCoordinator: "0x8C7382F9D8f56b33781fE506E897a4F1e2d17255",
    linkTokenAddress: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    linkAmountToTransfer: ethers.parseEther("0.1"),
}