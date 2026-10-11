# Vendored dependencies

All dependency sources are ordinary files; no install step or submodules are needed.

| Dependency | Release | Exact upstream commit | Included files |
| --- | --- | --- | --- |
| [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/c64a1edb67b6e3f4a15cca8909c9482ad33a02b0) | v5.4.0 | `c64a1edb67b6e3f4a15cca8909c9482ad33a02b0` | ERC20 and its four transitive Solidity dependencies, MIT license |
| [forge-std](https://github.com/foundry-rs/forge-std/tree/77041d2ce690e692d6e03cc812b57d1ddaa4d505) | v1.9.7 | `77041d2ce690e692d6e03cc812b57d1ddaa4d505` | `src/`, MIT and Apache licenses; used only by tests |

Sources were retrieved from GitHub's codeload tar archives at these exact commits.
The archive SHA-256 digests were:

- OpenZeppelin: `cad1e509c993850363d8218383499a0a8c7ac24ba71aeb120c43e96f2448b2fb`
- forge-std: `a387f7c2a10387f889b0d18b999cfa667a5273ac11cc11e18923022eb8b24bc3`

The included upstream Solidity files are unmodified. Their license notices are retained.
