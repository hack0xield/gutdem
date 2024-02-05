// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Modifiers} from "../libraries/LibAppStorage.sol";
import {IBlast} from "../../shared/interfaces/IBlast.sol";
import {LibDiamond} from "../../shared/diamond/lib/LibDiamond.sol";

contract GameManager is Modifiers {
    event GameManagerAdded(address indexed newGameManager);
    event GameManagerRemoved(address indexed removedGameManager);

    address constant BLAST_YIELD_CONTRACT =
        0x4300000000000000000000000000000000000002;

    function configureBlastYield() external onlyOwner {
        IBlast(BLAST_YIELD_CONTRACT).configureAutomaticYield();
        IBlast(BLAST_YIELD_CONTRACT).configureGovernor(
            LibDiamond.contractOwner()
        );
    }

    function addGameManagers(
        address[] calldata newGameManagers_
    ) external onlyOwner {
        for (uint256 i; i < newGameManagers_.length; ++i) {
            address newGameManager = newGameManagers_[i];
            s.gameManagers[newGameManager] = true;

            emit GameManagerAdded(newGameManager);
        }
    }

    function removeGameManagers(
        address[] calldata gameManagersToRemove_
    ) external onlyOwner {
        for (uint256 i; i < gameManagersToRemove_.length; i++) {
            address gameManager = gameManagersToRemove_[i];
            require(
                s.gameManagers[gameManager] == true,
                "GameManagerFacet: GameManager does not exist or already removed"
            );
            s.gameManagers[gameManager] = false;

            emit GameManagerRemoved(gameManager);
        }
    }

    //    function withdrawDbn(uint256 amount_) external onlyGameManager {
    //        IERC20(s.demBaconAddress).transfer(
    //            msg.sender, amount_
    //        );
    //    }
}
