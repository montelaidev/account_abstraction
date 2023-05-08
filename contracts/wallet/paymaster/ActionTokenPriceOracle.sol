// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./interfaces/IPriceOracle.sol";

contract ActionPriceOracle is IPriceOracle {
    // This is a mock oracle for action tokens that do not have a price
    function exchangePrice(
        address token
    ) external view override returns (uint256 price, uint8 decimals) {
        return (1, 18);
    }
}
