// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test, Vm} from "forge-std/Test.sol";

interface ITxReplay {
    struct TxInfo {
        uint256 blockNumber;
        uint256 transactionIndex;
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint256 gasPrice;
        bytes input;
    }

    struct CallInfo {
        address from;
        address to;
        bytes input;
        uint256 value;
        uint256 gas;
        uint256 gasPrice;
    }

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
}

abstract contract TxReplay is Test, ITxReplay {
    /**
     * @dev Call a contract with the given context
     * @param ctx The context of the call
     */
    function call(CallInfo memory ctx) internal returns (bool, bytes memory) {
        vm.txGasPrice(ctx.gasPrice);
        vm.prank(ctx.from, ctx.from);
        return ctx.to.call{value: ctx.value, gas: ctx.gas}(ctx.input);
    }

    /**
     * @dev Call a contract with the given context without gas limit
     * @param ctx The context of the call
     */
    function callNoGasLimit(CallInfo memory ctx) internal returns (bool, bytes memory) {
        vm.txGasPrice(ctx.gasPrice);
        vm.prank(ctx.from, ctx.from);
        return ctx.to.call{value: ctx.value}(ctx.input);
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
     * @dev Restore the state and return the call info of the target transaction
     */
    function restore(string memory forkUrlOrAlias, bytes32 txHash, RestoreType mode)
        internal
        returns (CallInfo memory)
    {
        TxInfo memory txInfo = transaction(forkUrlOrAlias, txHash);
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
        return CallInfo({
            from: txInfo.from,
            to: txInfo.to,
            input: txInfo.input,
            value: txInfo.value,
            gas: txInfo.gas,
            gasPrice: txInfo.gasPrice
        });
    }

    /**
     * @dev Replay the transaction corresponding to the given transaction hash
     * @param forkUrlOrAlias The URL or alias of the fork
     * @param txHash The hash of the transaction
     * @param mode Whether to restore to which point
     */
    function replay(string memory forkUrlOrAlias, bytes32 txHash, RestoreType mode)
        internal
        returns (bool, bytes memory)
    {
        return call(restore(forkUrlOrAlias, txHash, mode));
    }

    /**
     * @dev Get the transaction info corresponding to the given transaction hash
     * @param forkUrlOrAlias The URL or alias of the fork
     * @param txHash The hash of the transaction
     */
    function transaction(string memory forkUrlOrAlias, bytes32 txHash) internal returns (TxInfo memory) {
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
        Vm.FfiResult memory res = vm.tryFfi(inputs);
        require(res.exitCode == 0, string(res.stderr));
        return parseTransaction(res.stdout);
    }

    /**
     * @dev Parse the transaction info from the given JSON
     * @param json The JSON string
     */
    function parseTransaction(bytes memory json) internal view returns (TxInfo memory) {
        string memory s = string(json);
        require(!vm.keyExistsJson(s, ".error"), "failed to get transaction");

        TxInfo memory txInfo;
        txInfo.blockNumber = vm.parseJsonUint(s, ".result.blockNumber");
        txInfo.transactionIndex = vm.parseJsonUint(s, ".result.transactionIndex");
        txInfo.from = vm.parseJsonAddress(s, ".result.from");
        txInfo.to = vm.parseJsonAddress(s, ".result.to");
        txInfo.input = vm.parseJsonBytes(s, ".result.input");
        txInfo.value = vm.parseJsonUint(s, ".result.value");
        txInfo.gas = vm.parseJsonUint(s, ".result.gas");
        txInfo.gasPrice = vm.parseJsonUint(s, ".result.gasPrice");
        return txInfo;
    }

    /**
     * @dev Get the code of the target contract at the given address
     * @param target The target contract address
     */
    function codeAt(address target) internal view returns (bytes memory code) {
        assembly {
            let size := extcodesize(target)
            code := mload(0x40)
            mstore(0x40, add(code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(code, size)
            extcodecopy(target, add(code, 0x20), 0, size)
        }
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
