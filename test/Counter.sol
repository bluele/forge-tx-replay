// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {console2} from "forge-std/Test.sol";

contract BrokenCounter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment(uint256 n) public {
        // bug here
        if (number > 0 && n > 0) {
            revert("increment failed");
        }
        number += n;
    }
}

contract DebugBrokenCounter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment(uint256 n) public {
        // bug here
        if (number > 0 && n > 0) {
            console2.log("number:", number);
            console2.log("n:", n);
            revert("increment failed");
        }
        number += n;
    }
}

contract FixedCounter {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment(uint256 n) public {
        number += n;
    }
}
