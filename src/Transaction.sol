// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {RLPReader} from "./RLPReader.sol";
import {RLPEncoder} from "./RLPEncoder.sol";

library Transaction {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using Transaction for Tx;

    error TransactionUnexpectedListLength(uint256 length);

    struct Tx {
        uint256 nonce;
        uint256 gasLimit;
        address to;
        uint256 value;
        bytes data;
        uint32 v;
        bytes32 r;
        bytes32 s;
        // legacy
        uint256 gasPrice;
        // eip-2930
        uint256 chainId;
        AccessTuple[] accessList;
        // eip-1559
        uint256 maxPriorityFeePerGas;
        uint256 maxFeePerGas;
        // eip-4844
        uint256 maxFeePerBlobGas;
        bytes32[] blobHashes;
        // additional fields for testing
        address from;
    }

    struct AccessTuple {
        address address_;
        bytes32[] storageKeys;
    }

    enum TxType {
        LEGACY,
        ACCESS_LIST,
        DYNAMIC_FEE,
        BLOB
    }

    function newTx(address from, address to, bytes memory data) internal pure returns (Tx memory) {
        return newTx(from, to, data, 0, 0);
    }

    function newTx(address from, address to, bytes memory data, uint256 value, uint256 gasLimit)
        internal
        pure
        returns (Tx memory)
    {
        return Tx({
            nonce: 0,
            gasLimit: gasLimit,
            to: to,
            value: value,
            data: data,
            v: 0,
            r: bytes32(0),
            s: bytes32(0),
            gasPrice: 0,
            chainId: 0,
            accessList: new AccessTuple[](0),
            maxPriorityFeePerGas: 0,
            maxFeePerGas: 0,
            maxFeePerBlobGas: 0,
            blobHashes: new bytes32[](0),
            from: from
        });
    }

    function txType(Tx memory self) internal pure returns (TxType) {
        if (self.maxFeePerBlobGas != 0 || self.blobHashes.length != 0) {
            return TxType.BLOB;
        } else if (self.maxPriorityFeePerGas != 0 || self.maxFeePerGas != 0) {
            return TxType.DYNAMIC_FEE;
        } else if (self.accessList.length != 0) {
            return TxType.ACCESS_LIST;
        } else {
            return TxType.LEGACY;
        }
    }

    function txTypeFrom(uint256 t) internal pure returns (TxType) {
        if (t == uint256(TxType.LEGACY)) {
            return TxType.LEGACY;
        } else if (t == uint256(TxType.ACCESS_LIST)) {
            return TxType.ACCESS_LIST;
        } else if (t == uint256(TxType.DYNAMIC_FEE)) {
            return TxType.DYNAMIC_FEE;
        } else if (t == uint256(TxType.BLOB)) {
            return TxType.BLOB;
        } else {
            revert("unsupported transaction type");
        }
    }

    function txHash(Tx memory self) internal pure returns (bytes32) {
        return keccak256(self.encode());
    }

    function encode(Tx memory self) internal pure returns (bytes memory) {
        TxType tp = self.txType();
        if (tp == TxType.LEGACY) {
            bytes[] memory items = new bytes[](9);
            items[0] = RLPEncoder.encode(self.nonce);
            items[1] = RLPEncoder.encode(self.gasPrice);
            items[2] = RLPEncoder.encode(self.gasLimit);
            if (self.to == address(0)) {
                items[3] = RLPEncoder.encode(bytes(""));
            } else {
                items[3] = RLPEncoder.encode(self.to);
            }
            items[4] = RLPEncoder.encode(self.value);
            items[5] = RLPEncoder.encode(self.data);
            items[6] = RLPEncoder.encode(self.v);
            items[7] = RLPEncoder.encode(abi.encodePacked(self.r));
            items[8] = RLPEncoder.encode(abi.encodePacked(self.s));
            return RLPEncoder.encode(items);
        } else if (tp == TxType.ACCESS_LIST) {
            bytes[] memory items = new bytes[](11);
            items[0] = RLPEncoder.encode(self.chainId);
            items[1] = RLPEncoder.encode(self.nonce);
            items[2] = RLPEncoder.encode(self.gasPrice);
            items[3] = RLPEncoder.encode(self.gasLimit);
            if (self.to == address(0)) {
                items[4] = RLPEncoder.encode(bytes(""));
            } else {
                items[4] = RLPEncoder.encode(self.to);
            }
            items[5] = RLPEncoder.encode(self.value);
            items[6] = RLPEncoder.encode(self.data);
            items[7] = rlpEncode(self.accessList);
            items[8] = RLPEncoder.encode(self.v);
            items[9] = RLPEncoder.encode(abi.encodePacked(self.r));
            items[10] = RLPEncoder.encode(abi.encodePacked(self.s));
            return abi.encodePacked(uint8(TxType.ACCESS_LIST), RLPEncoder.encode(items));
        } else if (tp == TxType.DYNAMIC_FEE) {
            bytes[] memory items = new bytes[](12);
            items[0] = RLPEncoder.encode(self.chainId);
            items[1] = RLPEncoder.encode(self.nonce);
            items[2] = RLPEncoder.encode(self.maxPriorityFeePerGas);
            items[3] = RLPEncoder.encode(self.maxFeePerGas);
            items[4] = RLPEncoder.encode(self.gasLimit);
            if (self.to == address(0)) {
                items[5] = RLPEncoder.encode(bytes(""));
            } else {
                items[5] = RLPEncoder.encode(self.to);
            }
            items[6] = RLPEncoder.encode(self.value);
            items[7] = RLPEncoder.encode(self.data);
            items[8] = rlpEncode(self.accessList);
            items[9] = RLPEncoder.encode(self.v);
            items[10] = RLPEncoder.encode(abi.encodePacked(self.r));
            items[11] = RLPEncoder.encode(abi.encodePacked(self.s));
            return abi.encodePacked(uint8(TxType.DYNAMIC_FEE), RLPEncoder.encode(items));
        } else {
            revert("unsupported transaction type");
        }
    }

    function decode(bytes memory txBytes) internal pure returns (Tx memory) {
        RLPReader.RLPItem memory item = txBytes.toRlpItem();
        if (item.isList()) {
            return decodeLegacyTx(txBytes);
        }
        if (txBytes[0] == bytes1(uint8(TxType.ACCESS_LIST))) {
            return decodeAccessListTx(txBytes);
        } else if (txBytes[0] == bytes1(uint8(TxType.DYNAMIC_FEE))) {
            return decodeDynamicFeeTx(txBytes);
        } else if (txBytes[0] == bytes1(uint8(TxType.BLOB))) {
            revert("unsupported transaction type BLOB");
        } else {
            revert("unsupported transaction type");
        }
    }

    function decodeLegacyTx(bytes memory txBytes) internal pure returns (Tx memory) {
        /**
         *     uint256 nonce;
         *     uint256 gasPrice;
         *     uint256 gasLimit;
         *     address to;
         *     uint256 value;
         *     bytes data;
         *     uint32 v;
         *     bytes32 r;
         *     bytes32 s;
         */
        RLPReader.RLPItem[] memory items = txBytes.toRlpItem().toList();
        uint256 v = uint32(items[6].toUint());
        uint256 chainId;
        if (v % 2 == 0) {
            chainId = (v - 36) / 2;
        } else {
            chainId = (v - 35) / 2;
        }
        RLPReader.RLPItem memory addressRLP = items[3];
        address to = address(0);
        if (addressRLP.payloadLen() > 0) {
            to = address(addressRLP.toAddress());
        }
        Tx memory txn = Tx({
            chainId: chainId,
            nonce: items[0].toUint(),
            maxPriorityFeePerGas: 0,
            maxFeePerGas: 0,
            gasPrice: items[1].toUint(),
            gasLimit: items[2].toUint(),
            to: to,
            value: items[4].toUint(),
            data: items[5].toBytes(),
            v: uint32(v),
            r: bytes32(items[7].toUint()),
            s: bytes32(items[8].toUint()),
            accessList: new AccessTuple[](0),
            maxFeePerBlobGas: 0,
            blobHashes: new bytes32[](0),
            from: address(0)
        });
        txn.from = verifySignature(txn);
        return txn;
    }

    function decodeAccessListTx(bytes memory txBytes) internal pure returns (Tx memory) {
        /**
         *     uint256 chainId;
         *     uint256 nonce;
         *     uint256 gasPrice;
         *     uint256 gasLimit;
         *     address to;
         *     uint256 value;
         *     bytes data;
         *     AccessTuple[] accessList;
         *     uint32 v;
         *     bytes32 r;
         *     bytes32 s;
         */
        RLPReader.RLPItem[] memory items = toRlpItemOffset1(txBytes).toList();
        if (items.length != 11) {
            revert TransactionUnexpectedListLength(items.length);
        }
        RLPReader.RLPItem memory addressRLP = items[4];
        address to = address(0);
        if (addressRLP.payloadLen() > 0) {
            to = address(addressRLP.toAddress());
        }
        Tx memory txn = Tx({
            chainId: items[0].toUint(),
            nonce: items[1].toUint(),
            maxPriorityFeePerGas: 0,
            maxFeePerGas: 0,
            gasPrice: items[2].toUint(),
            gasLimit: items[3].toUint(),
            to: to,
            value: items[5].toUint(),
            data: items[6].toBytes(),
            accessList: rlpDecodeAccessList(items[7]),
            v: uint32(items[8].toUint()),
            r: bytes32(items[9].toUint()),
            s: bytes32(items[10].toUint()),
            maxFeePerBlobGas: 0,
            blobHashes: new bytes32[](0),
            from: address(0)
        });
        txn.from = verifySignature(txn);
        return txn;
    }

    function decodeDynamicFeeTx(bytes memory txBytes) internal pure returns (Tx memory) {
        /**
         *     uint256 chainId;
         *     uint256 nonce;
         *     uint256 maxPriorityFeePerGas;
         *     uint256 maxFeePerGas;
         *
         *     uint256 gasLimit;
         *     address to;
         *     uint256 value;
         *     bytes data;
         *     AccessTuple[] accessList;
         *
         *     uint32 v;
         *     bytes32 r;
         *     bytes32 s;
         */
        RLPReader.RLPItem[] memory items = toRlpItemOffset1(txBytes).toList();
        if (items.length != 12) {
            revert TransactionUnexpectedListLength(items.length);
        }
        RLPReader.RLPItem memory addressRLP = items[5];
        address to = address(0);
        if (addressRLP.payloadLen() > 0) {
            to = address(addressRLP.toAddress());
        }
        Tx memory txn = Tx({
            chainId: items[0].toUint(),
            nonce: items[1].toUint(),
            maxPriorityFeePerGas: items[2].toUint(),
            maxFeePerGas: items[3].toUint(),
            gasPrice: 0,
            gasLimit: items[4].toUint(),
            to: to,
            value: items[6].toUint(),
            data: items[7].toBytes(),
            accessList: rlpDecodeAccessList(items[8]),
            v: uint32(items[9].toUint()),
            r: bytes32(items[10].toUint()),
            s: bytes32(items[11].toUint()),
            maxFeePerBlobGas: 0,
            blobHashes: new bytes32[](0),
            from: address(0)
        });
        txn.from = verifySignature(txn);
        return txn;
    }

    // ------------------------------- Private Functions -------------------------------

    function isFrontierSigner(Tx memory self) private pure returns (bool) {
        return self.txType() == TxType.LEGACY && (self.v == 27 || self.v == 28);
    }

    function signingHash(Tx memory self) private pure returns (bytes32) {
        if (isFrontierSigner(self)) {
            return signingHashFrontier(self);
        }
        TxType tp = self.txType();
        if (tp == TxType.LEGACY) {
            return signingHashEIP155(self);
        } else if (tp == TxType.ACCESS_LIST) {
            return signingHashEIP2930(self);
        } else if (tp == TxType.DYNAMIC_FEE) {
            return signingHashLondon(self);
        }
        revert("unsupported transaction type");
    }

    function signingHashFrontier(Tx memory self) private pure returns (bytes32) {
        bytes[] memory items = new bytes[](6);
        items[0] = RLPEncoder.encode(self.nonce);
        items[1] = RLPEncoder.encode(self.gasPrice);
        items[2] = RLPEncoder.encode(self.gasLimit);
        items[3] = RLPEncoder.encode(self.to);
        items[4] = RLPEncoder.encode(self.value);
        items[5] = RLPEncoder.encode(self.data);
        return keccak256(RLPEncoder.encode(items));
    }

    function signingHashEIP155(Tx memory self) private pure returns (bytes32) {
        bytes[] memory items = new bytes[](9);
        items[0] = RLPEncoder.encode(self.nonce);
        items[1] = RLPEncoder.encode(self.gasPrice);
        items[2] = RLPEncoder.encode(self.gasLimit);
        items[3] = RLPEncoder.encode(self.to);
        items[4] = RLPEncoder.encode(self.value);
        items[5] = RLPEncoder.encode(self.data);
        items[6] = RLPEncoder.encode(self.chainId);
        items[7] = RLPEncoder.encode(0);
        items[8] = RLPEncoder.encode(0);
        return keccak256(RLPEncoder.encode(items));
    }

    function signingHashEIP2930(Tx memory self) private pure returns (bytes32) {
        bytes[] memory items = new bytes[](8);
        items[0] = RLPEncoder.encode(self.chainId);
        items[1] = RLPEncoder.encode(self.nonce);
        items[2] = RLPEncoder.encode(self.gasPrice);
        items[3] = RLPEncoder.encode(self.gasLimit);
        items[4] = RLPEncoder.encode(self.to);
        items[5] = RLPEncoder.encode(self.value);
        items[6] = RLPEncoder.encode(self.data);
        items[7] = rlpEncode(self.accessList);
        return keccak256(abi.encodePacked(uint8(TxType.ACCESS_LIST), RLPEncoder.encode(items)));
    }

    function signingHashLondon(Tx memory self) private pure returns (bytes32) {
        bytes[] memory items = new bytes[](9);
        items[0] = RLPEncoder.encode(self.chainId);
        items[1] = RLPEncoder.encode(self.nonce);
        items[2] = RLPEncoder.encode(self.maxPriorityFeePerGas);
        items[3] = RLPEncoder.encode(self.maxFeePerGas);
        items[4] = RLPEncoder.encode(self.gasLimit);
        items[5] = RLPEncoder.encode(self.to);
        items[6] = RLPEncoder.encode(self.value);
        items[7] = RLPEncoder.encode(self.data);
        items[8] = rlpEncode(self.accessList);
        return keccak256(abi.encodePacked(uint8(TxType.DYNAMIC_FEE), RLPEncoder.encode(items)));
    }

    function rlpEncode(AccessTuple[] memory accessList) private pure returns (bytes memory) {
        bytes[] memory items = new bytes[](accessList.length);
        for (uint256 i = 0; i < accessList.length; i++) {
            AccessTuple memory tuple = accessList[i];
            bytes[] memory storageKeys = new bytes[](tuple.storageKeys.length);
            for (uint256 j = 0; j < tuple.storageKeys.length; j++) {
                storageKeys[j] = RLPEncoder.encode(abi.encodePacked(tuple.storageKeys[j]));
            }
            bytes[] memory accessItem = new bytes[](2);
            accessItem[0] = RLPEncoder.encode(tuple.address_);
            accessItem[1] = RLPEncoder.encode(storageKeys);
            items[i] = RLPEncoder.encode(accessItem);
        }
        return RLPEncoder.encode(items);
    }

    function rlpDecodeAccessList(RLPReader.RLPItem memory item) private pure returns (AccessTuple[] memory) {
        require(item.isList(), "access list must be a list");
        RLPReader.RLPItem[] memory items = item.toList();
        AccessTuple[] memory accessList = new AccessTuple[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            RLPReader.RLPItem[] memory accessItem = items[i].toList();
            RLPReader.RLPItem[] memory storageKeys = accessItem[1].toList();
            bytes32[] memory keys = new bytes32[](storageKeys.length);
            for (uint256 j = 0; j < storageKeys.length; j++) {
                keys[j] = bytes32(storageKeys[j].toBytes());
            }
            accessList[i] = AccessTuple({address_: accessItem[0].toAddress(), storageKeys: keys});
        }
        return accessList;
    }

    function verifySignature(Tx memory self) private pure returns (address) {
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1224d197c7335b29cf4b95d03a1db438658e6263/contracts/utils/cryptography/ECDSA.sol#L128
        require(
            self.s <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "invalid signature 's' value"
        );
        bytes32 h = signingHash(self);
        return ecrecover(h, plainV(self.v, self.chainId) + 27, self.r, self.s);
    }

    function plainV(uint32 v, uint256 chainId) private pure returns (uint8) {
        if (v == 0 || v == 1) {
            return uint8(v);
        }
        if (v == 27 || v == 28) {
            return uint8(v - 27);
        }
        if (v % 2 == 0) {
            return uint8(v - chainId * 2 - 36);
        } else {
            return uint8(v - chainId * 2 - 35);
        }
    }

    function toRlpItemOffset1(bytes memory item) private pure returns (RLPReader.RLPItem memory) {
        uint256 memPtr;
        assembly {
            memPtr := add(item, 0x21)
        }

        return RLPReader.RLPItem(item.length - 1, memPtr);
    }
}
