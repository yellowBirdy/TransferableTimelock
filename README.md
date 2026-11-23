# ERC20TransferableTimelock

ERC20TransferableTimelock is a reusable ERC-20 pattern for making newly minted tokens
temporarily non-burnable while preserving full transferability. This reference
implementation restricts a minted balance only for the block in which it was
minted.

The pattern is based on
[ERC20Restricted](https://gist.github.com/yellowBirdy/955a9f2bcff52d6a7e361b861d877ea5),
with corrected recipient accounting, consistent block-number expiry, explicit
burn enforcement, and tested handling of transfer edge cases.

## Semantics

When tokens are minted in block N:

- they may be transferred any number of times in block N;
- they may not be burned in block N;
- the non-burnable amount follows transfers through recipients;
- they become fully burnable from block N+1 onward.

An account can hold unlocked and timelocked tokens simultaneously. Transfers
consume unlocked balance first. Only the amount exceeding that unlocked balance
is treated as timelocked and propagated to the recipient.

For example, an account holding 70 unlocked and 30 timelocked tokens that
transfers 80 sends 70 unlocked and 10 timelocked tokens. Its remaining 20 tokens
stay timelocked, and the recipient gains a timelocked balance of 10.

This convention gives the implementation a precise conservation property:
within one block, transfers preserve the global sum of timelocked balances.
Mints increase it, permitted burns cannot decrease it, and the next block
expires it.

## Integration

`ERC20TransferableTimelock` deliberately does not define a public mint or burn policy.
Derive from it and expose `_mint` or `_burn` using the authorization appropriate
for your application:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20TransferableTimelock} from "./ERC20TransferableTimelock.sol";

contract ExampleToken is ERC20TransferableTimelock, Ownable {
    constructor(address initialOwner)
        ERC20TransferableTimelock("Example Token", "EXAMPLE")
        Ownable(initialOwner)
    {}

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
```

The repository includes OpenZeppelin and Solady implementations with the same
read API and burn-restriction error. The OpenZeppelin implementation uses
`_update`; the Optimised Solady implementation uses `_afterTokenTransfer`, so
Solady validates and updates ERC-20 balances before timelock accounting runs.

### Read API

- `timelockedBalanceOf(account)` returns the balance that cannot be burned in
  the current block.
- `unlockedBalanceOf(account)` returns the balance currently available to burn.

Expired records return zero without requiring a cleanup transaction. A later
restricted receipt safely replaces stale state.

## Edge-case behavior

- Multiple mints and restricted receipts in one block accumulate.
- Split transfers and later merges conserve the exact timelocked amount.
- Dust transfers propagate single token units correctly.
- Zero-value mints and transfers do not alter timelock state.
- Self-transfers preserve both balance and timelock state.
- A burn may consume unlocked balance while timelocked balance remains.
- A burn exceeding unlocked capacity reverts with
  `ERC20InsufficientUnlockedBalance(account, unlockedBalance, requestedAmount)`.

## Limitations

- This is a same-block action restriction, not vesting or a time-based escrow.
- Timelock accounting is fungible and follows an unrestricted-first convention;
  it does not identify particular token units.
- Transfers remain intentionally unrestricted, so recipients inherit any
  timelocked portion they receive.
- A derived contract overriding the implementation's ERC-20 update hook must
  call its parent implementation to preserve this behavior.
- The permissionless mint/burn contract under `test/mocks` is a test harness,
  not a deployment contract.

## Development

The repository uses Foundry and pins OpenZeppelin Contracts v5.7.0 and Solady
v0.1.26.

```shell
forge install
forge build
forge test
forge fmt --check
```

Run the larger CI profile with:

```shell
FOUNDRY_PROFILE=ci forge test
```

The shared suite runs against both implementations and includes deterministic
tests, parameterized fuzz tests, and a stateful shadow-ledger handler.
Invariants cover per-account model agreement, global timelocked-balance
conservation, total-supply conservation, arbitrary transfer chains, splitting
and merging, dust, self and zero transfers, mint-transfer-burn sequences,
repeated same-block receipts, block expiry, and canonical overdraft errors.

## License

MIT
