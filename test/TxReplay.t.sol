// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {BrokenCounter, DebugBrokenCounter, FixedCounter} from "./Counter.sol";
import {TxReplay, Transaction} from "../src/TxReplay.sol";

contract TxReplayTest is TxReplay {
    // failed transaction in the sepolia
    bytes32 constant TARGET_TRANSACTION_HASH = 0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9;

    function test_replay_tx_hash() public {
        TxInfo memory txInfo = restore(getRpcUrl(), RestoreType.POST, TARGET_TRANSACTION_HASH);
        (bool success,) = call(txInfo.txn);
        assertEq(success, false);
    }

    function test_debug_tx_hash() public {
        TxInfo memory txInfo = restore(getRpcUrl(), RestoreType.POST, TARGET_TRANSACTION_HASH);
        address counter = txInfo.txn.to;
        // replace the BrokenCounter with DebugBrokenCounter
        setCode(counter, address(new DebugBrokenCounter()));

        // call DebugBrokenCounter::increment(uint256) with the actual state
        (bool success,) = call(txInfo.txn);
        assertEq(success, false);
    }

    function test_fix_replay_tx_hash() public {
        TxInfo memory txInfo = restore(getRpcUrl(), RestoreType.POST, TARGET_TRANSACTION_HASH);
        address counter = txInfo.txn.to;
        uint256 current = BrokenCounter(counter).number();

        (bool success,) = call(txInfo.txn);
        assertEq(success, false);

        setCode(counter, address(new FixedCounter()));

        (success,) = call(txInfo.txn);
        assertEq(success, true);
        assertEq(FixedCounter(counter).number(), current + 1);
    }

    function test_replay_tx_bytes() public {
        // fork url for mainnet, sepolia, etc.
        // the fork url should be an archive node
        vm.createSelectFork(getRpcUrl(), 5833789);
        (bool success,) = call(
            hex"f88d8085067d17cbe4830f424094f6b11c29307d230668536721537250e35124973c80a47cf5dab000000000000000000000000000000000000000000000000000000000000000018401546d71a0ad76bfd7ce8607325c173f8946f16e516a6223b359d30f5bb6193a3c74a8189da0195b0cfd14375595acc6abc15b42400b73f80db0d557e51b8dd82bfec18e762a"
        );
        // ensure the transaction fails
        assertEq(success, false);
    }

    function test_debug_tx_bytes() public {
        vm.createSelectFork(getRpcUrl(), 5833789);
        Transaction.Tx memory txn = Transaction.decode(
            hex"f88d8085067d17cbe4830f424094f6b11c29307d230668536721537250e35124973c80a47cf5dab000000000000000000000000000000000000000000000000000000000000000018401546d71a0ad76bfd7ce8607325c173f8946f16e516a6223b359d30f5bb6193a3c74a8189da0195b0cfd14375595acc6abc15b42400b73f80db0d557e51b8dd82bfec18e762a"
        );
        address counter = txn.to;
        // replace the BrokenCounter with DebugBrokenCounter
        setCode(counter, address(new DebugBrokenCounter()));

        // call DebugBrokenCounter::increment(uint256) with the actual state
        (bool success,) = call(txn);
        assertEq(success, false);
    }

    function test_fix_replay_tx_bytes() public {
        vm.createSelectFork(getRpcUrl(), 5833789);
        Transaction.Tx memory txn = Transaction.decode(
            hex"f88d8085067d17cbe4830f424094f6b11c29307d230668536721537250e35124973c80a47cf5dab000000000000000000000000000000000000000000000000000000000000000018401546d71a0ad76bfd7ce8607325c173f8946f16e516a6223b359d30f5bb6193a3c74a8189da0195b0cfd14375595acc6abc15b42400b73f80db0d557e51b8dd82bfec18e762a"
        );
        address counter = txn.to;
        uint256 current = BrokenCounter(counter).number();

        (bool success,) = call(txn);
        assertEq(success, false);

        setCode(counter, address(new FixedCounter()));

        (success,) = call(txn);
        assertEq(success, true);
        assertEq(FixedCounter(counter).number(), current + 1);
    }

    // returned URL must be that of the sepolia archive node
    function getRpcUrl() internal view returns (string memory) {
        return vm.envString("RPC_URL");
    }

    function test_decodeAccessList() public pure {
        // $ cast access-list 0x7932861c00E3f88A39206a62a1d2e774ab938AF6 "increment(uint256)" 1 --rpc-url https://ethereum-sepolia-archive.allthatnode.com
        string memory json =
            '{"accessList":[{"address":"0x7932861c00e3f88a39206a62a1d2e774ab938af6","storageKeys":["0x0000000000000000000000000000000000000000000000000000000000000000"]}],"gasUsed":"0x657f"}';
        bytes memory data = vm.parseJson(json, ".accessList");
        Transaction.Tx memory txn;
        txn.accessList = abi.decode(data, (Transaction.AccessTuple[]));
        assertEq(txn.accessList.length, 1);
        assertEq(txn.accessList[0].address_, 0x7932861c00E3f88A39206a62a1d2e774ab938AF6);
        assertEq(txn.accessList[0].storageKeys.length, 1);
        assertEq(txn.accessList[0].storageKeys[0], 0);
    }
}
