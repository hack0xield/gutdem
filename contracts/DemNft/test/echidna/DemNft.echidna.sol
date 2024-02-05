// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DemNft} from "../../facets/DemNft.sol";
import {LibDiamond} from "../../../shared/diamond/lib/LibDiamond.sol";
import {LibDemNft} from "../../libraries/LibDemNft.sol";

contract DemNftEchidna is DemNft  {

    event Debug(address from, address to, uint256 id);

    address constant user1 = address(0x10000);
    address constant user2 = address(0x20000);
    uint constant maxNft = 10;

    constructor() {
        s.name = "DemBacon";
        s.symbol = "DBN";
        s.maxNftCount = maxNft;
        s.cloneBoxURI = "ipfs://QmUzSR5yDqtsjnzfvfFZWe2JyEryhm7UgUfhKr9pkokG7C";
        s.isSaleEnabled = true;
        s.dbnPrice = 100;
        s.dbnContract = address(0);

        LibDemNft.mint(maxNft / 2, user1);
        LibDemNft.mint(maxNft / 2, user2);
    }

    function transferAndCheck(uint256 value) public {
        uint256 index = value % (this.balanceOf(msg.sender) + 1);
        uint256 tokenId = this.tokenOfOwnerByIndex(msg.sender, index);
        if (msg.sender != user1) {
            this.transferFrom(msg.sender, user1, tokenId);
            emit Debug(msg.sender, user1, tokenId);
        } else {
            this.transferFrom(msg.sender, user2, tokenId);
            emit Debug(msg.sender, user2, tokenId);
        }
        checkTotalSupply();
        checkBalances();
    }

    function checkTotalSupply() internal view {
        assert(this.totalSupply() <= maxNft);
    }

    function checkBalances() internal view  {
        assert(this.balanceOf(user1) <= maxNft);
        assert(this.balanceOf(user2) <= maxNft);
    }
}
