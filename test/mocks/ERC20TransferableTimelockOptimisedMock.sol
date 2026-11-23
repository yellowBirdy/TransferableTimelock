// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20TransferableTimelockOptimised} from "../../src/ERC20TransferableTimelockOptimised.sol";

/**
 * @dev Permissionless mint/burn harness used only to exercise the Optimised implementation.
 */
contract ERC20TransferableTimelockOptimisedMock is ERC20TransferableTimelockOptimised {
    constructor() ERC20TransferableTimelockOptimised("Transferable Timelock", "TRANSFERABLE") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
