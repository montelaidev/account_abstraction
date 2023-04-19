// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.19;

import {BaseAccount} from "../aa-4337/core/BaseAccount.sol";
import {Exec} from "../aa-4337/utils/Exec.sol";
import {ERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { WalletSignature } from "./utils/Signature.sol";

contract AADemoWallet is BaseAccount, ERC1271 {
    using WalletSignature for bytes;
    using WalletSignature for bytes32;
    using Exec for address;
    uint256 public nonce;

    uint8 public threshold = 1;

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
  bytes4 constant internal MAGICVALUE = 0x1626ba7e;

    function nonce() public view override returns (uint256) {
        return nonce;
    }

    function threshold() public view override returns (uint256) {
        return 1;
    }

    // handle transactions here
    function executeTransaction(address _target, uint256 value, bytes _data ) external
    virtual returns (bool) {
        // only owner of contract

        _target.call{value: value}(data);
    }

    function executeTransactions() external virtual returns (Result memory) {

    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
    overrides internal returns (uint256 validationData) {
        // decode signature to SignatureData
        Signatures memory signatures = userOp.signature.decodeSignature();

        // check if signature type is valid
        require(signatures.version == 1 || signatures.version == 2 , 'Invalid Signature Version');
        require(signatures.signatureData.length > 0, 'Missing Signature');

        if (signatures.version == 1) {
        } else {
            uint8 signatureCount = 0;
             unchecked {
        for(uint256 n = 0; n < 100;) {
            require(isValidSigantrueNow(signatures.signatureData[n].signature, userOpHash), 'Invalid Signature');
            signatureCount += n;
            n++;
        }
    }
        }

        // validate the signature here if it is signed by owner
        address memory signerAddress = tryRecover
        // address of signer, hash, signature

        // check if is owner

        // check if signature is valid with open zeppellin
        bool isValid = isValidSignatureNow(userOp.)
    }

    function _validateSignature(SignatureData memory _signatureData, bytes32 userOpHash) internal returns (bool) {
        address signer = _signatureData;
        // check if signature is valid with open zeppellin
        bool isValid = isValidSignatureNow(_signatureData, userOpHash))
    }

    function _validateAdminSignature(Signature _signature, bytes32 userOpHash) internal returns (bool) {
        address signer = _signature.signature;
        // check if signature is valid with open zeppellin
        bool isValid = isValidSignatureNow(_signature, userOpHash))
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal override {
        if (userOp.nonce !== nonce()){
            revert('Invalid Nonce');
        }
        nonce = nonce += 1;
    }
}
