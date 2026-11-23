// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20TransferableTimelock} from "../../src/ERC20TransferableTimelock.sol";

/**
 * @dev Permissionless mint/burn harness used only to exercise the base pattern.
 */
contract ERC20TransferableTimelockMock is ERC20TransferableTimelock {
    constructor() ERC20TransferableTimelock("Transferable Timelock", "TRANSFERABLE") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
