// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import {MimoWallet} from "./MimoWallet.sol";
import {IEntryPoint} from "../aa-4337/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MimoWalletFactory {
    MimoWallet public immutable accountImplementation;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new MimoWallet(_entryPoint);
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(
        address owner,
        uint256 salt,
        address[] memory guardians
    ) public returns (MimoWallet ret) {
        address addr = getAddress(owner, salt);
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return MimoWallet(payable(addr));
        }
        ret = MimoWallet(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(MimoWallet.initialize, (owner, guardians))
                )
            )
        );
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(
        address owner,
        uint256 salt
    ) public view returns (address) {
        address[] memory guardians;
        return
            Create2.computeAddress(
                bytes32(salt),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplementation),
                            abi.encodeCall(
                                MimoWallet.initialize,
                                (owner, guardians)
                            )
                        )
                    )
                )
            );
    }
}
