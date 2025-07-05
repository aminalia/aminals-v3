# Aminals NFT Project

**Aminals** is a revolutionary NFT project where each NFT is a self-sovereign, non-transferable digital entity deployed as its own smart contract that literally owns itself.

## Core Architecture

**Self-Sovereign NFTs**: Unlike traditional NFTs that are token IDs within a collection contract, each Aminal is its own ERC721 contract that mints to `address(this)`, creating true digital autonomy with no external control possible.

**Economic System**: Uses Variable Rate Gradual Dutch Auctions (VRGDA) to convert ETH into "love" and "energy" - love varies with feeding state (10x multiplier for hungry Aminals, 0.1x for overfed), while energy remains constant. This creates natural incentives for community care over whale hoarding.

**Breeding Governance**: A 4-phase community-driven breeding system where holders vote on traits using love-based voting power. The community can propose Gene NFTs as alternative traits and veto unwanted breeding.

## Key Components

1. **Aminal.sol** - Self-owning NFT contract with love/energy mechanics
2. **AminalFactory.sol** - Deploys individual Aminal contracts (breeding-focused)
3. **Gene.sol** - Onchain SVG NFTs representing genetic traits
4. **AminalBreedingVote.sol** - Community voting system for breeding
5. **BreedingSkill.sol** - Secure two-step breeding proposal system
6. **AminalVRGDA.sol** - Economic incentive mechanics
7. **AminalRenderer.sol** - Dynamic SVG composition and rendering

## Innovative Features

- **True Self-Sovereignty**: Each Aminal owns itself as `address(this)`
- **Non-Transferable**: Permanent autonomy, cannot be sold or transferred
- **Community Economics**: VRGDA creates natural distribution encouraging care for neglected Aminals
- **Skills System**: Extensible framework for Aminal interactions with external contracts
- **Onchain Traits**: Complete SVG storage with dynamic positioning algorithms
- **Democratic Breeding**: Community votes on genetic traits with love-based power

The project represents a radical departure from traditional NFT design, creating truly autonomous digital entities with community-driven governance and innovative economic mechanisms.

---

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
