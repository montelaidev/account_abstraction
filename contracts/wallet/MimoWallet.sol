// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import {BaseAccount} from "../aa-4337/core/BaseAccount.sol";
import {Exec} from "../aa-4337/utils/Exec.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import {WalletSignatures, SignatureData, Signatures} from "./utils/Signature.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../aa-4337/interfaces/IEntryPoint.sol";
import "hardhat/console.sol";

contract MimoWallet is
    BaseAccount,
    UUPSUpgradeable,
    Initializable,
    // IERC1271,
    AccessControl
{
    using WalletSignatures for bytes;
    using WalletSignatures for bytes32;
    using ECDSA for bytes32;
    using Exec for address;
    using UserOperationLib for UserOperation;

    //filler member, to push the nonce and owner to the same slot
    // the "Initializeble" class takes 2 bytes in the first slot
    bytes28 private _filler;

    //explicit sizes of nonce, to fit a single storage cell with "owner"
    uint96 private _nonce;

    IEntryPoint private immutable _entryPoint;

    uint8 public _threshold = 1;

    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    event MimoAccountInitialized(address _entrypoint, address _owner);

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(
        address anOwner,
        address[] calldata guardians
    ) public virtual initializer {
        _initialize(anOwner, guardians);
    }

    function _initialize(
        address anOwner,
        address[] calldata guardians
    ) internal virtual {
        _setupRole(DEFAULT_ADMIN_ROLE, anOwner);
        for (uint i = 0; i < guardians.length; i++) {
            grantRole(GUARDIAN_ROLE, guardians[i]);
        }
        emit MimoAccountInitialized(address(_entryPoint), anOwner);
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                msg.sender == address(this),
            "MimoAccountWallet: unauthorized"
        );
    }

    function addOwner(address newOwner) external {
        _onlyOwner();
        grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }

    function removeOwner(address oldOwner) external {
        _onlyOwner();
        revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);
    }

    function addGuardian(address newGuardian) external {
        _onlyOwner();
        grantRole(GUARDIAN_ROLE, newGuardian);
    }

    function removeGuardian(address oldGuardian) external {
        _onlyOwner();
        revokeRole(GUARDIAN_ROLE, oldGuardian);
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrAuthorized() internal view {
        console.log("msg.sender", msg.sender);
        console.log(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        require(
            msg.sender == address(entryPoint()) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "MimoAccountWallet: not Owner or EntryPoint"
        );
    }

    /// @inheritdoc BaseAccount
    function nonce() public view virtual override returns (uint256) {
        return _nonce;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function threshold() public view returns (uint256) {
        return _threshold;
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata func
    ) external {
        _requireFromEntryPointOrAuthorized();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrAuthorized();
        require(
            dest.length == func.length || dest.length == value.length,
            "wrong array lengths"
        );
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], value[i], func[i]);
        }
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view override returns (uint256 validationData) {
        console.log("before operationhash");
        console.log(block.chainid, address(_entryPoint));
        // console.logBytes32(userOp.hash());
        // console.log(userOp.sender);
        // console.log(userOp.nonce);
        // console.logBytes(userOp.initCode);
        // console.logBytes(userOp.callData);
        // console.log(userOp.callGasLimit);
        // console.log(userOp.verificationGasLimit);
        // console.log(userOp.preVerificationGas);
        // console.log(userOp.maxFeePerGas);
        // console.log(userOp.maxPriorityFeePerGas);
        // console.logBytes(userOp.paymasterAndData);

        // validate taht the entrypoint address and the chain id is the same as teh one in the hash
        bytes32 operationHash = keccak256(
            abi.encode(userOp.hash(), address(_entryPoint), block.chainid)
        );
        console.logBytes32(operationHash);
        console.log("chaindId in evm", block.chainid);
        // console.log("operationHash");
        // console.logBytes32(operationHash);
        // console.logBytes32(userOpHash);

        require(userOpHash == operationHash, "Invalid Operation Hash");

        bytes32 hash = userOpHash.toEthSignedMessageHash();
        console.log("eth signed hash");
        console.logBytes32(hash);
        console.log("recovered address", hash.recover(userOp.signature));
        console.log(
            "has role",
            hasRole(DEFAULT_ADMIN_ROLE, hash.recover(userOp.signature))
        );
        if (!hasRole(DEFAULT_ADMIN_ROLE, hash.recover(userOp.signature)))
            return SIG_VALIDATION_FAILED;

        // TODO: fix multi signatures
        // decode signature to SignatureData
        // Signatures memory signatures = userOp.signature.decodeSignature();

        // console.log("after signatures decode");
        // check if signature type is valid
        // type 1 = single admin
        // type 2 = mix of admin and guardian meeting a threshold
        // require(
        //     signatures.version == 1 || signatures.version == 2,
        //     "Invalid Signature Version"
        // );
        // require(signatures.signatureData.length > 0, "Missing Signature");

        // // TODO - validate validTill and validAfter
        // if (signatures.version == 1) {
        //     console.log("in version 1");
        //     require(
        //         signatures.signatureData.length != 1,
        //         "Invalid Signature Count"
        //     );
        //     _validateAdminSignature(signatures.signatureData[0], operationHash);
        // } else {
        //     _validateSignatures(signatures.signatureData, operationHash);
        // }

        return 0;
    }

    function _validateSignatures(
        SignatureData[] memory _signatureData,
        bytes32 userOpHash
    ) internal view returns (bool) {
        console.log("in validate signatures");
        require(
            _signatureData.length < _threshold,
            "Not enough valid signatures"
        );
        uint256 signatureCount = 0;
        uint256 length = _signatureData.length;
        for (uint256 n = 0; n < length; ) {
            require(
                hasRole(
                    GUARDIAN_ROLE,
                    userOpHash.recover(_signatureData[n].signature)
                ) ||
                    hasRole(
                        DEFAULT_ADMIN_ROLE,
                        userOpHash.recover(_signatureData[n].signature)
                    ),
                "Invalid Signature"
            );
            (
                uint256 _chainId,
                address _entryPointFromSiganture
            ) = WalletSignatures.retrieveChainIdAndEntrypoint(
                    _signatureData[n].signature
                );
            // _validateChainIdAndEntrypoint(_chainId, _entryPointFromSiganture);

            signatureCount += n;
            unchecked {
                n++;
            }
        }
        return true;
    }

    function _validateAdminSignature(
        SignatureData memory _signatureData,
        bytes32 userOpHash
    ) internal view returns (bool) {
        console.log(
            "has role",
            hasRole(
                DEFAULT_ADMIN_ROLE,
                userOpHash.recover(_signatureData.signature)
            )
        );
        require(
            hasRole(
                DEFAULT_ADMIN_ROLE,
                userOpHash.recover(_signatureData.signature)
            ),
            "Invalid Signature"
        );
        (uint256 _chainId, address _entryPointFromSiganture) = WalletSignatures
            .retrieveChainIdAndEntrypoint(_signatureData.signature);
        console.log("chainId", _chainId);
        console.log("entryPoint", _entryPointFromSiganture);
        // _validateChainIdAndEntrypoint(_chainId, _entryPointFromSiganture);
        return true;
    }

    /// implement template method of BaseAccount
    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override {
        require(_nonce++ == userOp.nonce, "account: invalid nonce");
        console.log("after nonce");
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    function getNonce() public view returns (uint256) {
        return _nonce;
    }

    /**
     * deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable {
        entryPoint().depositTo{value: msg.value}(address(this));
    }

    /**
     * withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public {
        _onlyOwner();
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }
}
