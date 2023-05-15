// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract MockUSDC is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("Mock USDC", "USDC") {}
}
