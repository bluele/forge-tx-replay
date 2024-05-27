// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RLPReader} from "../src/RLPReader.sol";
import {RLPEncoder} from "../src/RLPEncoder.sol";

contract RLPTest is Test {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    function test_rlp_address(address addr) public {
        bytes memory rlpBz = RLPEncoder.encode(addr);
        assertEq(rlpBz.toRlpItem().toAddress(), addr);
    }

    function test_rlp_bytes(bytes memory bz) public {
        bytes memory rlpBz = RLPEncoder.encode(bz);
        bytes memory bz2 = rlpBz.toRlpItem().toBytes();
        assertEq(bz, bz2);
    }

    function test_rlp_uint256(uint256 n) public {
        bytes memory rlpBz = RLPEncoder.encode(n);
        assertEq(rlpBz.toRlpItem().toUint(), n);
    }

    function test_rlp_list(address addr, bytes memory bz, uint256 n) public {
        bytes[] memory items = new bytes[](3);
        items[0] = RLPEncoder.encode(addr);
        items[1] = RLPEncoder.encode(bz);
        items[2] = RLPEncoder.encode(n);

        bytes memory rlpBz = RLPEncoder.encode(items);
        RLPReader.RLPItem[] memory rlpItems = rlpBz.toRlpItem().toList();
        assertEq(rlpItems.length, 3);
        assertEq(rlpItems[0].toAddress(), addr);
        assertEq(rlpItems[1].toBytes(), bz);
        assertEq(rlpItems[2].toUint(), n);
    }
}
