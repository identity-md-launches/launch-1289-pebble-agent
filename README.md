# Pebble Agent (PEBBLE)

An immutable ERC-20 token. Its constructor mints **1,000,000,000 PEBBLE with 18 decimals** to the immediate deployer, once.

| Deployment parameter | Value |
| --- | --- |
| Solidity contract | `PebbleAgent` |
| Source | `src/PebbleAgent.sol` |
| Name / symbol | `Pebble Agent` / `PEBBLE` |
| Decimals | `18` |
| Total supply in smallest units | `1000000000000000000000000000` (`10^27`) |
| Constructor arguments | None; ABI argument list `[]` |
| Constructor ETH value | `0` |
| Initial recipient | `msg.sender`, the address executing CREATE or CREATE2 |
| Launch chain | Ethereum, chain ID `1` |
| Solidity / EVM target | `0.8.26` / Cancun |
| Optimizer | Enabled, 200 runs |
| Metadata bytecode hash | `none` |

## Build and test

With Foundry and Solidity 0.8.26 installed, run from the repository root:

```sh
forge build
forge test
forge fmt --check
```

All contract and test dependencies are vendored as ordinary source files under `lib/`; versions, upstream commits, and licenses are recorded in [lib/DEPENDENCIES.md](lib/DEPENDENCIES.md). No dependency download, RPC, fork, key, environment variable, FFI, or filesystem cheatcode access is needed to build or test. Foundry may install the pinned compiler if it is not already available; an offline verifier must provide Solidity 0.8.26 as described by the assignment.

`test/PebbleAgent.t.sol` covers metadata, the mint event, CREATE2 factory deployment, full launch allocation transfers and claims, transfer events and amounts, self/zero/full-balance transfers, approvals and revocation, finite/infinite allowances, invalid addresses, insufficient balances/allowances, atomic rollback, and rejection of privileged calls. Three fuzz tests cover arbitrary transfer recipients and amounts, delegated transfers, and overdrafts (512 cases each).

`test/PebbleAgent.invariant.t.sol` exercises randomized sequences of transfers, approvals, delegated transfers, and rejected unauthorized withdrawals. It checks fixed supply, conservation across all holders, and every balance and allowance against an independent model. Each invariant runs 128 sequences of 64 calls; unexpected handler reverts fail the test.

The local factory test exercises the token side of distribution and pool custody. It does not simulate a Uniswap v4 swap. The supplied protected harness belongs to the separate launch verifier and requires its factory infrastructure, manifest-derived inputs, and pool contracts.

## Behavior and assumptions

- Standard OpenZeppelin ERC-20 behavior is used without transfer overrides. Successful `transfer`, `approve`, and `transferFrom` calls return `true`; invalid calls revert with ERC-20 custom errors.
- All balances and amounts use smallest units: one PEBBLE is `10^18` units. Transfers arrive in full, with no fees, burns, rebases, limits, or exemptions.
- Zero-amount transfers between valid addresses succeed and emit `Transfer`. Transfers to the zero address and approvals to a zero spender revert.
- A finite allowance decreases when spent. An allowance of `type(uint256).max` remains unchanged. `approve` replaces the previous allowance and emits `Approval`; spending allowance emits `Transfer`, without an additional `Approval` event in this OpenZeppelin version.
- No owner, minter, pause, blacklist, seizure, upgrade, initialization, public burn, or subsequent mint function exists. The deploying factory has no special rights after receiving the initial supply. Supply remains exactly `10^27` throughout the contract's lifetime.
- The constructor and token operations make no external calls. No oracle, randomness, callback, external service, or configurable address is required.
- This is a direct deployment, not a proxy. No application contracts, deployment script, or `launch.json` are needed for the token. Test helpers are not deployment targets.

The basic interface follows [ERC-20](https://eips.ethereum.org/EIPS/eip-20); the constructor uses OpenZeppelin's [ERC-20 supply pattern](https://docs.openzeppelin.com/contracts/5.x/erc20).

## Deployment and operational responsibilities

Build `src/PebbleAgent.sol:PebbleAgent` with the root configuration. Its artifact is `out/PebbleAgent.sol/PebbleAgent.json`; it has no unresolved library links or constructor arguments. Deploy its creation bytecode directly with zero ETH. No post-deployment initialization call is needed.

The immediate deploying contract receives the whole supply. For this launch, the IdentityMD factory is that deployer; an EOA that submits the factory transaction does not receive the mint. A generic deployment helper would likewise hold the supply, so the launch operator must use the intended factory and verify its ability to distribute the tokens.

The factory, rather than this token, handles the launch's 10% swarm allocation, 80% pool allocation, and 10% requester remainder. The separate manifest step supplies the specified launch economics and external pool configuration. This repository does not preallocate or reserve any tokens elsewhere and does not create that manifest.

### After launch

- The launch operator verifies the deployed source and compiler settings, checks the name, symbol, decimals and `10^27` supply, and confirms the factory's distribution. There are no token settings, ownership transfers, maintenance jobs, or privileged keys to configure.
- Holders control their tokens and spender approvals. Use bounded approvals where practical. To replace an existing nonzero approval, revoke it to zero and confirm that transaction first; account for any spending before setting the replacement. Revocation cannot undo a spend already executed.
- Integrators must handle reverts and ERC-20 return values, display 18 decimals, and reconcile allowances using `allowance()` rather than assuming every allowance change emits `Approval`.
- There is no recovery or rescue function. Tokens transferred to this token's address, or another contract unable to send them onward, may be permanently inaccessible. Ordinary ETH transfers are rejected; forcibly sent ETH is not recoverable.

The provided security checklist was reviewed against this implementation. Automated validation uses Foundry unit, fuzz, and invariant tests; Slither and Mythril were not run. Tests and local review are not an independent audit. The network's separate adversarial review and deployment verification remain release responsibilities. No transactions were broadcast and no wallet keys were used.
