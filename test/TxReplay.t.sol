// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {BrokenCounter, DebugBrokenCounter, FixedCounter} from "./Counter.sol";
import {TxReplay} from "../src/TxReplay.sol";

contract TxReplayTest is TxReplay {
    // failed transaction in the sepolia
    bytes32 constant TARGET_TRANSACTION_HASH = 0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9;

    function test_replay() public {
        CallInfo memory callInfo = restore(getRpcUrl(), TARGET_TRANSACTION_HASH, RestoreType.POST);
        (bool success,) = call(callInfo);
        assertEq(success, false);
    }

    function test_debug() public {
        CallInfo memory callInfo = restore(getRpcUrl(), TARGET_TRANSACTION_HASH, RestoreType.POST);
        address counter = callInfo.to;
        // replace the BrokenCounter with DebugBrokenCounter
        setCode(counter, address(new DebugBrokenCounter()));

        // call DebugBrokenCounter::increment(uint256) with the actual state
        (bool success,) = call(callInfo);
        assertEq(success, false);
    }

    function test_fix_replay() public {
        CallInfo memory callInfo = restore(getRpcUrl(), TARGET_TRANSACTION_HASH, RestoreType.POST);
        address counter = callInfo.to;
        uint256 current = BrokenCounter(counter).number();

        (bool success,) = call(callInfo);
        assertEq(success, false);

        setCode(counter, address(new FixedCounter()));

        (success,) = call(callInfo);
        assertEq(success, true);
        assertEq(FixedCounter(counter).number(), current + 1);
    }

    // returned URL must be that of the archive node
    function getRpcUrl() internal view returns (string memory) {
        return vm.envString("RPC_URL");
    }
}
