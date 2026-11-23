// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20TransferableTimelock {
    error ERC20InsufficientUnlockedBalance(address account, uint256 unlockedBalance, uint256 requestedAmount);

    function mint(address account, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function transfer(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function timelockedBalanceOf(address account) external view returns (uint256);

    function unlockedBalanceOf(address account) external view returns (uint256);
}
