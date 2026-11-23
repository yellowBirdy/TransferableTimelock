# Background and Motivation

Build `ERC20LiquidTimelock`, a local Git-initialized Foundry reference repository based on the linked ERC-20 restriction pattern. Newly minted balances must remain fully transferable while being non-burnable during the mint block.

## Request 2 (Planner, 2026-11-23): fix and reconcile `ERC20LiquidTimelockOptimised`

User-requested items (the "draft" is to be ignored; user confirmed):

1. Optimised: `timelockedBalanceOf` returns a stale amount (locks never expire). Return amount only if `lockedAt == number()`, else 0.
2. Optimised: self-transfer lowers the lock (no `from == to` guard). Return early when `from == to`.
3. Optimised: overdraft transfer panics (0x11) instead of `InsufficientBalance()` because Solady calls `_beforeTokenTransfer` before its balance check. Check `amount <= balanceOf(from)` first (or move to `_afterTokenTransfer`).
4. No tests cover the Optimised contract. Run the existing unit, fuzz and invariant suites against both contracts through a shared abstract test base.
5. Naming: use the repo set for both contracts: `timelockedBalanceOf`, `unlockedBalanceOf`, `ERC20InsufficientUnlockedBalance(account, ...)`. (User decision.)
6. Rename contracts/repo to `TransferableTimelock` (GitHub repo already renamed; user also asked for the local `origin` remote to be updated).

Baseline observed before any change: `forge test` has 7 failing tests (3 unit/fuzz + 4 invariants). Cause: `ERC20LiquidTimelock` declares `ERC20InsufficientUnlockedBalance(address account, uint256 missing)` (2 args) but the tests and handler expect `(account, unlocked, requested)` (3 args). Item 5 must resolve this.

# Key Challenges and Analysis

- Use `block.number` consistently; the source gist mixes timestamp and block-number checks.
- Attribute minted restrictions to the mint recipient, not `msg.sender`.
- Spend unrestricted balance first and propagate only the restricted remainder through transfers.
- Preserve restricted-balance conservation across arbitrary same-block transfer graphs.
- Treat self-transfers and zero transfers as accounting no-ops.
- Keep mint authorization outside the reusable base contract.
- Run `super._update` first and derive transfer propagation from post-operation balances.

## Request 2 analysis

- Solady and OpenZeppelin revert with different overdraft errors: Solady `InsufficientBalance()` vs OZ `ERC20InsufficientBalance(sender, balance, needed)`. A shared test base needs a virtual hook per implementation for that one assertion (and only that one).
- If the Optimised contract uses the same 3-arg `ERC20InsufficientUnlockedBalance` as the OZ contract, the shared tests need no hook for the burn error. This is how "one naming set on both contracts" is achieved.
- Shared test base design: an interface (`ERC20`-compatible plus `mint`, `burn`, `timelockedBalanceOf`, `unlockedBalanceOf`, and the error declaration) in `test/`; an abstract test base with a virtual `_deploy()`; the handler typed to the interface instead of the concrete OZ mock; one new mock for the Optimised contract exposing `_mint`/`_burn`. Concrete test contracts per implementation inherit the unit/fuzz base and the invariant base.
- Running the shared suite against Optimised BEFORE fixing items 1-3 gives a genuine TDD red state (expected to fail: stale lock, self-transfer, overdraft).
- The user's own examples become explicit regression tests: balance 100 / locked 30 / self-transfer 80 keeps the lock at 30; overdraft transfer reverts with the implementation's balance error.
- Rename scope (assuming `ERC20` prefix is kept, per Milestone 6): `ERC20LiquidTimelock(.sol/.t.sol/Invariant/Mock/Handler/Optimised)` becomes `ERC20TransferableTimelock...`; README title/prose/example; mock token name/symbol strings (`"Liquid Timelock"`, `"LIQUID"`); git `origin` URL. Historical scratchpad text is left as is.
- Possible secondary issues noticed but NOT in scope (reported, not planned): Optimised burn of more than balance also reverts with `InsufficientUnlockedBalance` rather than `InsufficientBalance`; Optimised stores `amount` in 200 bits so mints above 2^200 would silently corrupt the packed slot; a zero-amount mint writes a lock record.

# High-level Task Breakdown

1. Initialize Foundry/Git, pin dependencies, and establish failing core behavior tests.
2. Implement the base contract and pass core behavior tests.
3. Add and pass comprehensive edge-case and fuzz tests.
4. Add and pass stateful model-based invariant tests.
5. Complete documentation and final high-run verification.
6. Rename the implementation to `ERC20LiquidTimelock`, use block NatSpec comments, and convert `_update` to post-state accounting.

## Request 2 plan (one task at a time; Executor stops after each for user verification)

7. Rename to `Transferable` (item 6, code only): contracts, files (`git mv`), tests, mock, handler, README, mock token strings. Success: `forge build` passes; `rg -i liquid` finds only historical scratchpad text; test failures identical to baseline (the same 7).
8. Reconcile the burn error (item 5): make `ERC20InsufficientUnlockedBalance` identical on both contracts (see Open Decision A). OZ contract revert data must match what tests expect. Success: the 7 baseline failures are gone for the OZ contract; README error text matches.
9. Shared test base + Optimised mock (item 4): refactor the unit/fuzz suite and invariant suite to run against both contracts. Add the two regression tests from the user's examples. Success: OZ variant fully green; Optimised variant red exactly for items 1, 2, 3 (documented in the scratchpad).
10. Fix item 1 in Optimised: `timelockedBalanceOf` returns amount only when `lockedAt == number()`. Success: stale-lock tests green for Optimised.
11. Fix item 2 in Optimised: `if (from == to) return;` in `_beforeTokenTransfer`. Success: self-transfer tests (including 100/30/80 example) green.
12. Fix item 3 in Optimised: move timelock accounting from `_beforeTokenTransfer` to `_afterTokenTransfer` and use post-transfer balances, matching the OpenZeppelin implementation's strategy. Solady must perform canonical balance validation first for both transfers and burns. Success: transfer and burn overdrafts return Solady's `InsufficientBalance()` rather than a panic or timelock error, while shared unit, fuzz and invariant suites remain green.
13. Final verification: `forge test` default profile and `FOUNDRY_PROFILE=ci`, `forge fmt --check`, README updated (naming, Optimised mention, test layout). Report lint warnings without fixing them.
14. Git remote: set `origin` to the renamed GitHub URL (see Open Decision C). Success: `git remote -v` shows the new URL; no force operations.

# Project Status Board

- [x] Milestone 1: Repository scaffold and failing behavioral tests
- [x] Milestone 2: Core LiquidTimelock implementation
- [x] Milestone 3: Edge-case and fuzz suite
- [x] Milestone 4: Stateful invariant suite
- [x] Milestone 5: Documentation and final verification
- [x] Milestone 6: ERC20 rename, block NatSpec, and parent-first `_update`
- [x] Milestone 7: Install Solady
- [x] Milestone 8: Add Solady ERC-20 boilerplate
- [x] Task 7: Rename `LiquidTimelock` to `TransferableTimelock` (code only)
- [x] Task 8: Reconcile `ERC20InsufficientUnlockedBalance` on both contracts
- [x] Task 9: Shared abstract test base, Optimised mock, regression tests
- [x] Task 10: Optimised fix 1, locks expire
- [x] Task 11: Optimised fix 2, self-transfer guard
- [x] Task 12: Optimised fix 3, overdraft error
- [x] Task 13: Final verification and README
- [x] Task 14: Update git `origin` URL

# Current Status / Progress Tracking

The local Git/Foundry repository is initialized. `forge-std` v1.16.2 and OpenZeppelin Contracts v5.7.0 are pinned as Git submodules. A deliberately incomplete `LiquidTimelock` scaffold, a permissionless test harness, and four core behavior tests establish the initial TDD red state.

`forge test` compiles successfully and reports the intended baseline: 3 failing tests (recipient restriction, restricted-balance propagation, and burn rejection) plus 1 passing next-block expiry test. IDE diagnostics report no linter errors.

The base contract now records recipient mints, enforces same-block burn restrictions, propagates only the restricted portion of transfers, accumulates same-block receipts, and lazily expires records. All 4 core tests pass.

The deterministic/fuzz suite now contains 15 passing tests, including chains, split/merge, dust, self/zero operations, mint-transfer-burn, and repeated receipts. Four model-based invariants pass 256 runs and 128,000 calls each with no handler reverts.

Final CI-profile verification passes all 19 tests: each fuzz test ran 1,000 cases and each invariant ran 512 sequences of 1,000 calls (512,000 calls per invariant) with zero handler reverts. `forge fmt --check`, `forge build --sizes`, `git diff --check`, and IDE diagnostics also pass. README, MIT license, pinned compiler/dependencies, CI workflow, and integration guidance are present.

The contract and all first-party test artifacts are now named `ERC20LiquidTimelock`. NatSpec uses block comments. `_update` calls `super._update` first, validates burns against the post-burn balance, and computes transferred timelock as the excess over the sender's post-transfer balance. The default 19-test suite passes.

Solady v0.1.26 is installed at `lib/solady` as a Git submodule and recorded in `foundry.lock`. `forge build` succeeds with only the previously documented lint warnings.

`src/ERC20LiquidTimelockOptimised.sol` now provides a Solady ERC-20 boilerplate with constructor-configurable name and symbol metadata. The optional cached EIP-712 name hash was removed as requested. `forge build` succeeds.

Request 2, Task 7 implementation is complete and awaiting human verification. All current source, test, mock, handler, contract, import, README, and mock metadata names now use `ERC20TransferableTimelock` / `ERC20TransferableTimelockOptimised`. No `Liquid` occurrence remains in `src`, `test`, or `README.md`; historical scratchpad records were intentionally retained. `forge build`, `git diff --check`, and IDE diagnostics pass. `forge test` retains the exact baseline of 12 passing and 7 failing tests caused by the pre-existing two-argument/three-argument custom-error mismatch, as required by this task's success criteria. Existing Foundry warnings were reported and not changed.

Request 2, Task 7 was verified by the user. Task 8 implementation is complete and awaiting human verification. Both implementations now declare `ERC20InsufficientUnlockedBalance(address account, uint256 unlockedBalance, uint256 requestedAmount)`. The OpenZeppelin implementation derives the pre-burn unlocked amount from post-burn state; the Optimised implementation reports its pre-operation `unlockedBalanceOf`. README error documentation matches. The default suite passes all 19 tests, including 256 invariant runs / 128,000 calls per invariant with zero handler reverts. `git diff --check` and IDE diagnostics pass. Existing Optimised constructor-shadowing compiler warnings were reported and not changed.

The user directed the Executor to continue, verifying Task 8. Task 9 implementation is complete and awaiting human verification. `IERC20TransferableTimelock` now provides the shared test surface; an Optimised mock exposes `_mint` and `_burn`; the unit/fuzz suite and model-based invariant suite each have concrete OpenZeppelin and Optimised runners over shared abstract bases. The exact 100 balance / 30 timelocked / self-transfer 80 regression and canonical overdraft-error regression are included. OpenZeppelin passes all 17 unit/fuzz tests and all 4 invariants (128,000 calls each). Optimised has the intended red state: 12 unit/fuzz tests pass and 5 fail across stale expiry, self-transfer mutation, overdraft panic, plus stale-expiry effects; all 4 Optimised invariants fail from the same known defects. Overall: 33 pass, 9 fail. `git diff --check` and IDE diagnostics pass. `forge fmt --check` reports three wrapping-only diffs in `test/ERC20TransferableTimelock.t.sol`; per user instruction, they were reported and not automatically fixed.

At the user's direction to finish and push, Tasks 9–13 were completed without further milestone pauses. The Optimised implementation now ignores stale packed records, preserves self-transfer accounting, and performs all timelock accounting in `_afterTokenTransfer`, allowing Solady to validate transfer and burn overdrafts first. README documents both implementations and the shared suite. `forge fmt --check`, `git diff --check`, IDE diagnostics, and `forge build --sizes` pass. The default profile passes all 42 tests. The CI profile passes all 42 tests: each fuzz test ran 1,000 cases and all eight invariant runs completed 512 sequences / 512,000 calls with zero reverts. Existing Foundry warnings for unchecked test transfers and the handler immutable naming were reported and not changed. Commit `64378f6` (`fix optimised transferable timelock accounting`) was pushed to `origin/master`; local and remote `master` match.

At the user's request, the three reported warnings were then addressed locally: Optimised constructor parameters now use `name_` / `symbol_`, successful unit-test transfers assert their returned boolean, the intentionally reverting overdraft call has a targeted Forge lint suppression, and the handler immutable is `TOKEN`. `forge fmt --check`, all 42 default-profile tests, `forge build --sizes`, `git diff --check`, and IDE diagnostics pass with no compiler or Forge lint findings. These three files are not yet committed or pushed.

# Executor's Feedback or Assistance Requests

No assistance is pending. Planner cross-check confirms that every requested implementation and test category is covered.

Executor completed the Solady installation and requests human verification before Milestone 7 is marked complete.

Executor is creating the requested `ERC20LiquidTimelockOptimised` boilerplate as the current task.

Executor completed the boilerplate and requests human verification before Milestone 8 is marked complete. The earlier immutable naming note is no longer applicable because `_nameHash` was removed.

Executor completed Request 2, Task 7 (rename) and requests human verification before marking it complete or proceeding to Task 8. The git remote and local directory were not changed in this task.

Executor completed Request 2, Task 8 (shared three-argument insufficient-unlocked-balance error) and requests human verification before marking it complete or proceeding to Task 9.

At the user's direction, the Executor updated `origin` to `https://github.com/yellowBirdy/TransferableTimelock.git`, committed the tracked Task 7 and Task 8 changes as `c69984e` (`rename transferable timelock contracts`), and pushed `master` successfully. Local `master` matches `origin/master`. The untracked `.cursor/` coordination directory was intentionally not included in the commit.

Executor completed Request 2, Task 9 (shared test bases and Optimised red-state coverage) and requests human verification before marking it complete or proceeding to Task 10. The only formatter findings are three line-wrapping differences in the shared unit test.

Executor implemented and pushed Tasks 10–13 at the user's direction. No implementation assistance is pending. Formal completion announcement remains for Planner cross-check per the project workflow.

## Planner: open decisions awaiting user sign-off (Request 2)

- **A. RESOLVED by user: use the recommended 3-arg `ERC20InsufficientUnlockedBalance(account, unlocked, requested)` on both contracts.** (Original analysis follows.) The OZ contract has `(account, missing)`; tests/handler expect `(account, unlocked, requested)`. Recommendation: use the 3-arg form `ERC20InsufficientUnlockedBalance(account, unlocked, requested)` on both contracts. It matches the existing tests, needs no test rewrites, and gives Optimised a shared, informative error. Cost: changes the OZ contract's error signature (and the selector), and adds a small gas cost to Optimised's revert path. Alternative: keep the 2-arg form and rewrite the tests/handler.
- **B. RESOLVED by user:** move the Optimised contract's timelock accounting to `_afterTokenTransfer`. Solady therefore performs its canonical balance validation first for both transfers and burns; successful operations then use post-transfer accounting, matching the OpenZeppelin implementation's strategy.
- **C. Remote URL. RESOLVED by user:** `https://github.com/yellowBirdy/TransferableTimelock` (so the `origin` fetch/push URL becomes `https://github.com/yellowBirdy/TransferableTimelock.git`). Local folder name is left unchanged.
- **D. RESOLVED by user:** `ERC20TransferableTimelock` and `ERC20TransferableTimelockOptimised` (same scheme, distinct names). Original note: contract name prefix. Plan assumes `ERC20TransferableTimelock` / `ERC20TransferableTimelockOptimised` (keeps the `ERC20` prefix from Milestone 6). If plain `TransferableTimelock` is wanted, say so.

# Lessons

- The installed Foundry version is 1.3.5-stable.
- OpenZeppelin Contracts v5.7.0 uses the ERC-20 `_update` extension point required by this pattern.
- Hidden `.cursor` project directories require unrestricted filesystem permission in this environment.
- Foundry's invariant runner still targets other deployed contracts when only `targetSelector` is configured. Pair it with `targetContract(address(handler))` to keep arbitrary calls inside the shadow-ledger handler.
- Forge can retain minimized invariant failures in its ignored cache after the test contract changes; it reports and ignores those stale entries before running the current suite.
- `forge build --sizes` reports test-only lint warnings for unchecked ERC-20 return values and one immutable naming note. They are non-failing, and were reported rather than changed per project instructions.
- The warning cleanup was later authorized and completed. Constructor parameters use `name_` / `symbol_`; using `_name` / `_symbol` there would shadow the existing storage variables of the same names and break their assignments.
- The original tests passed because the previous implementation deliberately computed timelock movement from pre-transfer balances before calling `super._update`; that ordering was internally consistent. The revised implementation honors the requested parent-first convention and uses post-state formulas instead.
- This repository's automatic Solady remapping points `solady/` to `lib/solady/src/`, so imports use `solady/tokens/ERC20.sol`.
