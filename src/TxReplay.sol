// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Transaction} from "./Transaction.sol";

interface ITxReplay {
    /**
     * @dev A caller can whether to restore to which point
     * LATEST: latest block
     * PREVIOUS: one block before the block that contains the target transaction
     * EXACT: block that contains the target transaction, and replays all transactions contained in the block before the target transaction
     * POST: block that contains the target transaction, and replays all transactions include the target transaction in the block
     *
     * NOTE: If you want to replay with the real state in which the target transaction was executed, you must specify EXACT mode.
     * However, the execution time can be long because it replays all transactions contained in the block before the target transaction in the runtime.
     */
    enum RestoreType {
        POST,
        PREVIOUS,
        LATEST,
        EXACT
    }

    struct Context {
        bool checkGasLimit;
    }

    struct TxInfo {
        bytes32 blockHash;
        uint256 blockNumber;
        uint256 transactionIndex;
        Transaction.Tx txn;
    }
}

abstract contract TxReplay is Test, ITxReplay {
    using Transaction for Transaction.Tx;

    /**
     * @dev Replay the transaction corresponding to the given transaction hash
     * @param forkUrlOrAlias The URL or alias of the fork
     * @param txHash The hash of the transaction
     * @param mode Whether to restore to which point
     */
    function replay(string memory forkUrlOrAlias, RestoreType mode, bytes32 txHash)
        internal
        returns (bool, bytes memory)
    {
        return call(restore(forkUrlOrAlias, mode, txHash).txn);
    }

    /**
     * @dev Replay the transaction corresponding to the given transaction hash
     * @param forkUrlOrAlias The URL or alias of the fork
     * @param txBytes The transaction bytes
     * @param blockNumber The block number to restore
     */
    function replay(string memory forkUrlOrAlias, uint256 blockNumber, bytes memory txBytes)
        internal
        returns (bool, bytes memory)
    {
        vm.createSelectFork(forkUrlOrAlias, blockNumber);
        return call(txBytes);
    }

    /**
     * @dev Replay the transaction corresponding to the given transaction hash
     * @param forkUrlOrAlias The URL or alias of the fork
     * @param blockNumber The block number to restore
     * @param txn The transaction to replay
     */
    function replay(string memory forkUrlOrAlias, uint256 blockNumber, Transaction.Tx memory txn)
        internal
        returns (bool, bytes memory)
    {
        vm.createSelectFork(forkUrlOrAlias, blockNumber);
        return call(txn);
    }

    /**
     * @dev Call a contract with the given context
     * @param txn The transaction to replay
     */
    function call(Transaction.Tx memory txn) internal returns (bool, bytes memory) {
        return call(defaultContext(), txn);
    }

    /**
     * @dev Call a contract with the given context
     * @param txBytes The transaction to replay
     */
    function call(bytes memory txBytes) internal returns (bool, bytes memory) {
        return call(defaultContext(), txBytes);
    }

    /**
     * @dev Call a contract with the given context
     * @param ctx The context
     * @param txn The transaction to replay
     */
    function call(Context memory ctx, Transaction.Tx memory txn) internal returns (bool, bytes memory) {
        require(txn.to != address(0), "invalid contract address");
        require(txn.from != address(0), "invalid sender address");
        vm.prank(txn.from, txn.from);
        if (ctx.checkGasLimit) {
            return txn.to.call{value: txn.value, gas: txn.gasLimit}(txn.data);
        } else {
            return txn.to.call{value: txn.value}(txn.data);
        }
    }

    /**
     * @dev Call a contract with the given context
     * @param ctx The context
     * @param txBytes The transaction to replay
     */
    function call(Context memory ctx, bytes memory txBytes) internal returns (bool, bytes memory) {
        return call(ctx, Transaction.decode(txBytes));
    }

    /**
     * @dev Restore the state and return the call info of the target transaction
     */
    function restore(string memory forkUrlOrAlias, RestoreType mode, bytes32 txHash) internal returns (TxInfo memory) {
        TxInfo memory txInfo = getTransactionByHash(forkUrlOrAlias, txHash);
        if (mode == RestoreType.LATEST) {
            vm.createSelectFork(forkUrlOrAlias);
        } else if (mode == RestoreType.PREVIOUS) {
            vm.createSelectFork(forkUrlOrAlias, txInfo.blockNumber - 1);
        } else if (mode == RestoreType.EXACT) {
            vm.createSelectFork(forkUrlOrAlias, txHash);
        } else if (mode == RestoreType.POST) {
            vm.createSelectFork(forkUrlOrAlias, txInfo.blockNumber);
        } else {
            revert("invalid RestoreType");
        }
        return txInfo;
    }

    /**
     * @dev Set the code of the target contract
     * @param target The target contract
     * @param newImplementation The new implementation contract
     */
    function setCode(address target, address newImplementation) internal {
        vm.etch(target, codeAt(newImplementation));
    }

    /**
     * @dev Set the code of the target contract
     * @param target The target contract
     * @param newCode The new code
     */
    function setCode(address target, bytes memory newCode) internal {
        vm.etch(target, newCode);
    }

    /**
     * @dev Get the code of the target contract at the given address
     * @param target The target contract address
     */
    function codeAt(address target) internal view returns (bytes memory code) {
        code = target.code;
        require(code.length > 0, "invalid contract address");
    }

    /**
     * @dev Default context
     */
    function defaultContext() internal pure returns (Context memory) {
        return Context({checkGasLimit: false});
    }

    /**
     * @dev Get the transaction info corresponding to the given transaction hash
     * @param forkUrlOrAlias The URL or alias of the fork
     * @param txHash The hash of the transaction
     */
    function getTransactionByHash(string memory forkUrlOrAlias, bytes32 txHash) internal returns (TxInfo memory) {
        string memory forkUrl = vm.rpcUrl(forkUrlOrAlias);
        string[] memory inputs = new string[](9);
        inputs[0] = "curl";
        inputs[1] = "-s";
        inputs[2] = "-X";
        inputs[3] = "POST";
        inputs[4] = "-H";
        inputs[5] = "Content-Type: application/json";
        inputs[6] = forkUrl;
        inputs[7] = "--data";
        inputs[8] = string.concat(
            "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionByHash\",\"params\":[\"0x",
            hexEncode(txHash),
            "\"],\"id\":1}"
        );
        VmSafe.FfiResult memory res = vm.tryFfi(inputs);
        require(res.exitCode == 0, string(res.stderr));
        return parse(string(res.stdout));
    }

    // ------------------------------- Private Functions -------------------------------

    function parse(string memory json) private pure returns (TxInfo memory) {
        Transaction.TxType txType = Transaction.txTypeFrom(vm.parseJsonUint(json, ".result.type"));
        Transaction.Tx memory txn;
        if (txType == Transaction.TxType.LEGACY) {
            txn = parseLegacyTx(json);
        } else if (txType == Transaction.TxType.ACCESS_LIST) {
            txn = parseAccessListTx(json);
        } else if (txType == Transaction.TxType.DYNAMIC_FEE) {
            txn = parseDynamicFeeTx(json);
        } else {
            revert("unsupported transaction type");
        }
        return TxInfo({
            blockHash: vm.parseJsonBytes32(json, ".result.blockHash"),
            blockNumber: vm.parseJsonUint(json, ".result.blockNumber"),
            transactionIndex: vm.parseJsonUint(json, ".result.transactionIndex"),
            txn: txn
        });
    }

    function parseLegacyTx(string memory json) private pure returns (Transaction.Tx memory) {
        Transaction.Tx memory txn;
        txn.to = vm.parseJsonAddress(json, ".result.to");
        txn.data = vm.parseJsonBytes(json, ".result.input");
        txn.value = vm.parseJsonUint(json, ".result.value");
        txn.gasLimit = vm.parseJsonUint(json, ".result.gas");
        txn.gasPrice = vm.parseJsonUint(json, ".result.gasPrice");
        txn.from = vm.parseJsonAddress(json, ".result.from");
        txn.v = uint32(vm.parseJsonUint(json, ".result.v"));
        txn.r = vm.parseJsonBytes32(json, ".result.r");
        txn.s = vm.parseJsonBytes32(json, ".result.s");
        return txn;
    }

    function parseAccessListTx(string memory json) private pure returns (Transaction.Tx memory) {
        Transaction.Tx memory txn;
        txn.to = vm.parseJsonAddress(json, ".result.to");
        txn.data = vm.parseJsonBytes(json, ".result.input");
        txn.value = vm.parseJsonUint(json, ".result.value");
        txn.gasLimit = vm.parseJsonUint(json, ".result.gas");
        txn.gasPrice = vm.parseJsonUint(json, ".result.gasPrice");
        txn.from = vm.parseJsonAddress(json, ".result.from");
        txn.accessList = abi.decode(vm.parseJson(json, ".result.accessList"), (Transaction.AccessTuple[]));
        txn.v = uint32(vm.parseJsonUint(json, ".result.v"));
        txn.r = vm.parseJsonBytes32(json, ".result.r");
        txn.s = vm.parseJsonBytes32(json, ".result.s");
        return txn;
    }

    function parseDynamicFeeTx(string memory json) private pure returns (Transaction.Tx memory) {
        Transaction.Tx memory txn;
        txn.to = vm.parseJsonAddress(json, ".result.to");
        txn.data = vm.parseJsonBytes(json, ".result.input");
        txn.value = vm.parseJsonUint(json, ".result.value");
        txn.gasLimit = vm.parseJsonUint(json, ".result.gas");
        txn.maxPriorityFeePerGas = vm.parseJsonUint(json, ".result.maxPriorityFeePerGas");
        txn.maxFeePerGas = vm.parseJsonUint(json, ".result.maxFeePerGas");
        txn.from = vm.parseJsonAddress(json, ".result.from");
        txn.accessList = abi.decode(vm.parseJson(json, ".result.accessList"), (Transaction.AccessTuple[]));
        txn.v = uint32(vm.parseJsonUint(json, ".result.v"));
        txn.r = vm.parseJsonBytes32(json, ".result.r");
        txn.s = vm.parseJsonBytes32(json, ".result.s");
        return txn;
    }

    function hexEncode(bytes32 _bytes32) private pure returns (string memory) {
        bytes memory hexStr = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            hexStr[i * 2] = toByte(uint8(_bytes32[i] >> 4));
            hexStr[i * 2 + 1] = toByte(uint8(_bytes32[i] & 0x0f));
        }
        return string(hexStr);
    }

    function toByte(uint8 _uint8) private pure returns (bytes1) {
        if (_uint8 < 10) {
            return bytes1(_uint8 + 48);
        } else {
            return bytes1(_uint8 + 87);
        }
    }
}
