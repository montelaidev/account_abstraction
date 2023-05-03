// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import {UserOperation} from "../../aa-4337/interfaces/UserOperation.sol";

struct Signatures {
    uint8 version; // 1 = single signer, 2 = multi-signer
    SignatureData[] signatureData;
}

enum SignerType {
    owner,
    guardian
}

struct SignatureData {
    SignerType signerType;
    bytes signature;
}

library WalletSignatures {
    function decodeSignature(
        UserOperation memory userOp
    ) internal pure returns (Signatures memory) {
        return decodeSignature(userOp.signature);
    }

    function decodeSignature(
        bytes memory _signatures
    ) internal pure returns (Signatures memory) {
        (uint8 version, SignatureData[] memory signatureData) = abi.decode(
            _signatures,
            (uint8, SignatureData[])
        );
        return Signatures(version, signatureData);
    }
}
