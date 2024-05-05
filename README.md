# forge-tx-replay

**forge-tx-replay** is a small library for [Forge](https://github.com/foundry-rs/foundry) that makes it easy to replay transactions on various networks, including mainnet and public testnets.

You might think that this library is simliar to `cast run` command. However, this library not only replay a target transaction with the state corresponding to the block of the transaction but also provides helper functions to inspect the contract code and state using your local code(i.e. you can use `console.log` for debugging) when replaying the transaction. This helps developers debug failed transactions and check the validity of their fixes.

## Usage

### Installation

Add `forge-tx-replay` to your project using Forge:

```
$ forge install https://github.com/bluele/forge-tx-replay
```

### Example: Replay a failed transaction and debug with local contract code

*You can see the full example code in the [test](./test) directory.*

0. Deploy the [`BrokenCounter`](./test/Counter.sol) contract and send a transaction but it fails.

```
$ forge create BrokenCounter --rpc-url https://ethereum-sepolia-archive.allthatnode.com
[⠒] Compiling...
[⠰] Compiling 1 files with 0.8.24
[⠔] Solc 0.8.24 finished in 1.26s
Compiler run successful!
Deployer: 0x1F04a27318DB3EC532e517dD0396f9a0C40349B6
Deployed to: 0xF6b11C29307d230668536721537250e35124973c
Transaction hash: 0x5d2e24c7b00c14475e428ef7e8ba879fbdfadcd6b342e939e3e63710d8a081d7

# First tx is succeeded
$ cast send 0xF6b11C29307d230668536721537250e35124973c "increment(uint256)" 1 --legacy --gas-limit 1000000 --rpc-url https://ethereum-sepolia-archive.allthatnode.com

# Second tx is failed
$ cast send 0xF6b11C29307d230668536721537250e35124973c "increment(uint256)" 1 --legacy --gas-limit 1000000 --rpc-url https://ethereum-sepolia-archive.allthatnode.com
...
status                  0 (failed)
transactionHash         0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9
transactionIndex        129
...
to                      0xF6b11C29307d230668536721537250e35124973c
revertReason            increment failed
```

1. Get the txHash of the target transaction from etherscan.io or another source. In the above example, the txHash is `0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9`.
2. Write a script that replays the target transaction

```solidity
pragma solidity ^0.8.0;

import {TxReplay} from "forge-tx-replay/TxReplay.sol";

contract TxReplayTest is TxReplay {
    function test_replay() public {
        CallInfo memory callInfo = restore(
            // fork url for mainnet, sepolia, etc.
            // the fork url should be an archive node
            "https://ethereum-sepolia-archive.allthatnode.com",
            // txHash of the failed target transaction
            0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9,
            // You can choose which block to restore
            // Note that the result may differ from actual result if you choose except EXACT type
            //
            // POST: block that contains the target transaction, and replays all transactions include the target transaction in the block
            // EXACT (the execution time can be long): block that contains the target transaction, and replays all transactions contained in the block before the target transaction
            // PREVIOUS: one block before the block that contains the target transaction
            // LATEST: latest block
            RestoreType.EXACT
        );
        (bool success,) = call(callInfo);
        // ensure the transaction fails
        assertEq(success, false);
    }
}
```

3. Run the test script with `forge test` command.

```bash
$ forge test -vv --match-test test_replay --ffi
...
Ran 1 test for test/TxReplay.t.sol:TxReplayTest
[PASS] test_replay() (gas: 70451)
Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 2.21s (2.21s CPU time)
...
```

4. Write a script that replays the target transaction and debug with the local project's contract `DebugBrokenCounter` that contains `console.log` for debugging.

```solidity
pragma solidity ^0.8.0;

import {TxReplay} from "forge-tx-replay/TxReplay.sol";
import {BrokenCounter, DebugBrokenCounter} from "./Counter.sol";

contract TxReplayTest is TxReplay {
    function test_debug() public {
        CallInfo memory callInfo = restore(
            "https://ethereum-sepolia-archive.allthatnode.com",
            0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9,
            RestoreType.EXACT
        );
        address counter = callInfo.to;
        // replace the contract code with DebugBrokenCounter
        setCode(counter, address(new DebugBrokenCounter()));

        // call DebugBrokenCounter::increment(uint256) with the actual state
        (bool success,) = call(callInfo);
        assertEq(success, false);
    }
}
```

5. Run the test script with `forge test` command.
```bash
$ forge test -vv --match-test test_debug --ffi
...
Ran 1 test for test/TxReplay.t.sol:TxReplayTest
[PASS] test_debug() (gas: 236225)
Logs:
  number: 1
  n: 1

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 3.66s (1.94s CPU time)
...
```

You can see the logs from the `console.log` in the `DebugBrokenCounter` contract.
