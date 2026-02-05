// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../WHO_TOKEN_ENTERPRISE.sol";

/**
 * @title WHO Protocol (V2 Mock)
 * @dev Used to simulate an upgrade in the test script.
 */
contract WHOTokenEnterpriseV2 is WHOTokenEnterprise {
    /**
     * @dev Re-initializer for V2 Upgrade.
     */
    function initializeV2() reinitializer(2) public {
        // No state changes needed for this mock, but function signals V2 readiness.
    }

    function version() public pure returns (string memory) {
        return "V2 - Ascension";
    }

    // Example of new functionality added in an upgrade
    function newFeature() public pure returns (bool) {
        return true;
    }
}
