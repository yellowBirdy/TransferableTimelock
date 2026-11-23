// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "solady/tokens/ERC20.sol";

contract ERC20TransferableTimelockOptimised is ERC20 {
    error ERC20InsufficientUnlockedBalance(address account, uint256 unlockedBalance, uint256 requestedAmount);
    /// @dev bytes4(keccak256("_TIMELOCKS_SLOT_SEED")

    string private _name;
    string private _symbol;

    uint256 private constant _TIMELOCKS_SLOT_SEED = 0xa29895c4;
    /// @dev The balance slot of `owner` is given by:
    /// ```
    ///     mstore(0x0c, _TIMELOCKS_SLOT_SEED)
    ///     mstore(0x00, account)
    ///     let timelockSlot := keccak256(0x0c, 0x20)
    /// ```

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function timelock(address account) public view returns (uint56 lockedAt, uint200 amount) {
        assembly ("memory-safe") {
            mstore(0x0c, _TIMELOCKS_SLOT_SEED)
            mstore(0x00, account)
            amount := sload(keccak256(0x0c, 0x20))
            lockedAt := and(amount, 0xFFFFFFFFFFFFFF)
            amount := shr(56, amount)
        }
    }

    function timelockedBalanceOf(address account) public view returns (uint256) {
        (uint56 lockedAt, uint200 amount) = timelock(account);
        return lockedAt == block.number ? uint256(amount) : 0;
    }

    function unlockedBalanceOf(address account) public view returns (uint256) {
        return balanceOf(account) - timelockedBalanceOf(account);
    }

    function _setTimelock(address account, uint256 amount) private {
        assembly ("memory-safe") {
            mstore(0x0c, _TIMELOCKS_SLOT_SEED)
            mstore(0x00, account)
            sstore(keccak256(0x0c, 0x20), or(number(), shl(56, amount)))
        }
    }

    function _increaseTimelock(address account, uint256 amount) private {
        assembly ("memory-safe") {
            mstore(0x0c, _TIMELOCKS_SLOT_SEED)
            mstore(0x00, account)
            let slot := keccak256(0x0c, 0x20)
            let current := sload(slot)
            if eq(and(current, 0xFFFFFFFFFFFFFF), number()) { amount := add(amount, shr(56, current)) }
            sstore(slot, or(number(), shl(56, amount)))
        }
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        if (amount == 0 || from == to) return;

        if (from == address(0)) {
            _increaseTimelock(to, amount);
            return;
        }

        uint256 fromTimelockedBalance = timelockedBalanceOf(from);
        uint256 fromPostTransferBalance = balanceOf(from);
        if (fromPostTransferBalance < fromTimelockedBalance) {
            uint256 touchedTimelockedAmount = fromTimelockedBalance - fromPostTransferBalance;
            if (to == address(0)) {
                revert ERC20InsufficientUnlockedBalance(from, amount - touchedTimelockedAmount, amount);
            }

            _setTimelock(from, fromPostTransferBalance);
            _increaseTimelock(to, touchedTimelockedAmount);
        }
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
