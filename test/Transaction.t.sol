// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Transaction} from "../src/Transaction.sol";

contract TransactionTest is Test {
    using Transaction for Transaction.Tx;

    function setUp() public {}

    function test_decode_contract_creation() public pure {
        /**
         * {
         *   "type": "0x2",
         *   "chainId": "0xaa36a7",
         *   "nonce": "0x3",
         *   "to": null,
         *   "gas": "0x20838",
         *   "gasPrice": null,
         *   "maxPriorityFeePerGas": "0x59682f00",
         *   "maxFeePerGas": "0xa9b6263d8",
         *   "value": "0x0",
         *   "input": "0x608060405234801561001057600080fd5b5061016d806100206000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633fb5c1cb146100465780637cf5dab01461005b5780638381f58a1461006e575b600080fd5b6100596100543660046100f7565b600055565b005b6100596100693660046100f7565b610089565b61007760005481565b60405190815260200160405180910390f35b6000805411801561009a5750600081115b156100de5760405162461bcd60e51b815260206004820152601060248201526f1a5b98dc995b595b9d0819985a5b195960821b604482015260640160405180910390fd5b806000808282546100ef9190610110565b909155505050565b60006020828403121561010957600080fd5b5035919050565b8082018082111561013157634e487b7160e01b600052601160045260246000fd5b9291505056fea26469706673582212205d8bf9a8b9ac33e9f7623bc29baa6edcdb3bfbcf11aeff759cd28347ed3e5bed64736f6c63430008180033",
         *   "accessList": [],
         *   "v": "0x0",
         *   "r": "0xef9b47b6de7b39cbc7ad6f7dab1756970133d6dc59f946cc916f880a156ec36d",
         *   "s": "0x60eadbbe97f11ece7bf134a577f337f23a0ef22a2f1850d292666b7a34a67a92",
         *   "yParity": "0x0",
         *   "hash": "0x5d2e24c7b00c14475e428ef7e8ba879fbdfadcd6b342e939e3e63710d8a081d7"
         * }
         */
        bytes memory txBytes =
            hex"02f901ea83aa36a7038459682f00850a9b6263d8830208388080b9018d608060405234801561001057600080fd5b5061016d806100206000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633fb5c1cb146100465780637cf5dab01461005b5780638381f58a1461006e575b600080fd5b6100596100543660046100f7565b600055565b005b6100596100693660046100f7565b610089565b61007760005481565b60405190815260200160405180910390f35b6000805411801561009a5750600081115b156100de5760405162461bcd60e51b815260206004820152601060248201526f1a5b98dc995b595b9d0819985a5b195960821b604482015260640160405180910390fd5b806000808282546100ef9190610110565b909155505050565b60006020828403121561010957600080fd5b5035919050565b8082018082111561013157634e487b7160e01b600052601160045260246000fd5b9291505056fea26469706673582212205d8bf9a8b9ac33e9f7623bc29baa6edcdb3bfbcf11aeff759cd28347ed3e5bed64736f6c63430008180033c080a0ef9b47b6de7b39cbc7ad6f7dab1756970133d6dc59f946cc916f880a156ec36da060eadbbe97f11ece7bf134a577f337f23a0ef22a2f1850d292666b7a34a67a92";
        Transaction.Tx memory txn = Transaction.decode(txBytes);
        assertTrue(txn.txType() == Transaction.TxType.DYNAMIC_FEE);
        assertEq(txn.nonce, 0x03);
        assertEq(txn.gasLimit, 0x20838);
        assertEq(txn.to, address(0));
        assertEq(txn.value, 0x0);
        assertEq(
            txn.data,
            hex"608060405234801561001057600080fd5b5061016d806100206000396000f3fe608060405234801561001057600080fd5b50600436106100415760003560e01c80633fb5c1cb146100465780637cf5dab01461005b5780638381f58a1461006e575b600080fd5b6100596100543660046100f7565b600055565b005b6100596100693660046100f7565b610089565b61007760005481565b60405190815260200160405180910390f35b6000805411801561009a5750600081115b156100de5760405162461bcd60e51b815260206004820152601060248201526f1a5b98dc995b595b9d0819985a5b195960821b604482015260640160405180910390fd5b806000808282546100ef9190610110565b909155505050565b60006020828403121561010957600080fd5b5035919050565b8082018082111561013157634e487b7160e01b600052601160045260246000fd5b9291505056fea26469706673582212205d8bf9a8b9ac33e9f7623bc29baa6edcdb3bfbcf11aeff759cd28347ed3e5bed64736f6c63430008180033"
        );
        assertEq(txn.maxPriorityFeePerGas, 0x59682f00);
        assertEq(txn.maxFeePerGas, 0xa9b6263d8);
        assertEq(txn.chainId, 0xaa36a7);
        assertEq(txn.v, 0x0);
        assertEq(txn.r, 0xef9b47b6de7b39cbc7ad6f7dab1756970133d6dc59f946cc916f880a156ec36d);
        assertEq(txn.s, 0x60eadbbe97f11ece7bf134a577f337f23a0ef22a2f1850d292666b7a34a67a92);
        assertEq(txn.txHash(), hex"5d2e24c7b00c14475e428ef7e8ba879fbdfadcd6b342e939e3e63710d8a081d7");
    }

    function test_decode_legacy_tx() public pure {
        /**
         * {
         *   "type": "0x0",
         *   "chainId": "0xaa36a7",
         *   "nonce": "0x5",
         *   "to": "0xf6b11c29307d230668536721537250e35124973c",
         *   "gas": "0xf4240",
         *   "gasPrice": "0x67d17cbe4",
         *   "maxPriorityFeePerGas": null,
         *   "maxFeePerGas": null,
         *   "value": "0x0",
         *   "input": "0x7cf5dab00000000000000000000000000000000000000000000000000000000000000001",
         *   "v": "0x1546d71",
         *   "r": "0xad76bfd7ce8607325c173f8946f16e516a6223b359d30f5bb6193a3c74a8189d",
         *   "s": "0x195b0cfd14375595acc6abc15b42400b73f80db0d557e51b8dd82bfec18e762a",
         *   "hash": "0xfbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9"
         * }
         */
        bytes memory txBytes =
            hex"f88d0585067d17cbe4830f424094f6b11c29307d230668536721537250e35124973c80a47cf5dab000000000000000000000000000000000000000000000000000000000000000018401546d71a0ad76bfd7ce8607325c173f8946f16e516a6223b359d30f5bb6193a3c74a8189da0195b0cfd14375595acc6abc15b42400b73f80db0d557e51b8dd82bfec18e762a";
        Transaction.Tx memory txn = Transaction.decode(txBytes);
        assertTrue(txn.txType() == Transaction.TxType.LEGACY);
        assertEq(txn.nonce, 0x5);
        assertEq(txn.chainId, 0xaa36a7);
        assertEq(txn.gasPrice, 0x67d17cbe4);
        assertEq(txn.gasLimit, 0xf4240);
        assertEq(txn.to, 0xF6b11C29307d230668536721537250e35124973c);
        assertEq(txn.value, 0x0);
        assertEq(txn.data, hex"7cf5dab00000000000000000000000000000000000000000000000000000000000000001");
        assertEq(txn.from, 0x1F04a27318DB3EC532e517dD0396f9a0C40349B6);
        assertEq(txn.v, 0x1546d71);
        assertEq(txn.r, 0xad76bfd7ce8607325c173f8946f16e516a6223b359d30f5bb6193a3c74a8189d);
        assertEq(txn.s, 0x195b0cfd14375595acc6abc15b42400b73f80db0d557e51b8dd82bfec18e762a);
        assertEq(txn.txHash(), hex"fbbf94672e596fa46bb5073f76062fdddc5e5ac6bde7a9ac2b9f902e93ab00e9");
    }

    function test_decode_eip4844() public pure {
        /**
         * {
         *   "type": "0x2",
         *   "chainId": "0xaa36a7",
         *   "nonce": "0x7",
         *   "to": "0x7932861c00e3f88a39206a62a1d2e774ab938af6",
         *   "gas": "0xac77",
         *   "gasPrice": null,
         *   "maxPriorityFeePerGas": "0x3b9aca00",
         *   "maxFeePerGas": "0x3ba964dc",
         *   "value": "0x0",
         *   "input": "0x7cf5dab00000000000000000000000000000000000000000000000000000000000000001",
         *   "accessList": [],
         *   "v": "0x1",
         *   "r": "0xeccc275cb449e8461cf5b7e4e86689d0ee19155493b4038786b86e3c2ccbb12f",
         *   "s": "0x60af5c4eb173aa732fb8a5b0ee4e1f650c1f09b90cde9df5aee8562d795c5dca",
         *   "yParity": "0x1",
         *   "hash": "0x9815a0a0011eb6830e339700e100b7c22945476f1ee8ceeae93211cf47b26e64"
         * }
         */
        bytes memory txBytes =
            hex"02f89183aa36a707843b9aca00843ba964dc82ac77947932861c00e3f88a39206a62a1d2e774ab938af680a47cf5dab00000000000000000000000000000000000000000000000000000000000000001c001a0eccc275cb449e8461cf5b7e4e86689d0ee19155493b4038786b86e3c2ccbb12fa060af5c4eb173aa732fb8a5b0ee4e1f650c1f09b90cde9df5aee8562d795c5dca";
        Transaction.Tx memory txn = Transaction.decode(txBytes);
        assertTrue(txn.txType() == Transaction.TxType.DYNAMIC_FEE);
        assertEq(txn.nonce, 0x7);
        assertEq(txn.chainId, 0xaa36a7);
        assertEq(txn.maxPriorityFeePerGas, 0x3b9aca00);
        assertEq(txn.maxFeePerGas, 0x3ba964dc);
        assertEq(txn.gasPrice, 0x0);
        assertEq(txn.gasLimit, 0xac77);
        assertEq(txn.to, 0x7932861c00E3f88A39206a62a1d2e774ab938AF6);
        assertEq(txn.value, 0x0);
        assertEq(txn.data, hex"7cf5dab00000000000000000000000000000000000000000000000000000000000000001");
        assertEq(txn.from, 0x1F04a27318DB3EC532e517dD0396f9a0C40349B6);
        assertEq(txn.v, 0x1);
        assertEq(txn.r, 0xeccc275cb449e8461cf5b7e4e86689d0ee19155493b4038786b86e3c2ccbb12f);
        assertEq(txn.s, 0x60af5c4eb173aa732fb8a5b0ee4e1f650c1f09b90cde9df5aee8562d795c5dca);
        assertEq(txn.txHash(), hex"9815a0a0011eb6830e339700e100b7c22945476f1ee8ceeae93211cf47b26e64");
    }
}
