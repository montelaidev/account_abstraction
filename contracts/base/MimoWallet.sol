// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {BaseAccount} from "../aa-4337/core/BaseAccount.sol";
import {Exec} from "../aa-4337/utils/Exec.sol";
import {ERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {WalletSignature} from "./utils/Signature.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract MimoWallet is
    BaseAccount,
    UUPSUpgradeable,
    Initializable,
    ERC1271,
    AccessControl
{
    using WalletSignature for bytes;
    using WalletSignature for bytes32;
    using ECDSA for bytes32;
    using Exec for address;
    using Counters for Counters.counter;

    //filler member, to push the nonce and owner to the same slot
    // the "Initializeble" class takes 2 bytes in the first slot
    bytes28 private _filler;

    //explicit sizes of nonce, to fit a single storage cell with "owner"
    uint96 private _nonce;

    IEntryPoint private immutable _entryPoint;

    uint8 public threshold = 1;

    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

}
