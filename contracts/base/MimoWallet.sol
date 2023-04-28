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

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(
        address anOwner,
        address[] guardians
    ) public virtual initializer {
        _initialize(anOwner, guardians);
    }

    function _initialize(
        address anOwner,
        address[] guardians
    ) internal virtual {
        grantRole(DEFAULT_ADMIN_ROLE, anOwner);
        for (uint i = 0; i < guardians.length; i++) {
            grantRole(GUARDIAN_ROLE, guardians[i]);
        }
        emit SimpleAccountInitialized(_entryPoint, owner);
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
                msg.sender == address(this),
            "only owner"
        );
    }

    function addOwner(address newOwner) external onlyOwner {
        grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }

    function removeOwner(address oldOwner) external onlyOwner {
        revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);
    }

    function addGuardian(address newGuardian) external onlyOwner {
        grantRole(GUARDIAN_ROLE, newOwner);
    }

    function removeGuardian(address oldGuardian) external onlyOwner {
        revokeRole(GUARDIAN_ROLE, oldGuardian);
    }

    // Require the function call went through EntryPoint or owner
    function _requireFromEntryPointOrAuthorized() internal view {
        require(
            msg.sender == address(entryPoint()) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "account: not Owner or EntryPoint"
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

    function threshold() public override views returns (uint256) {
        return 1;
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
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrAuthorized();
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    function _validateSignature(
        UserOperation userOp,
        bytes32 userOpHash
    ) internal overrides returns (uint256 validationData) {
        bytes32 hash = userOpHash.toEthSignedMessageHash();
        // decode signature to SignatureData
        Signatures memory signatures = userOp.signature.decodeSignature();

        // check if signature type is valid
        // type 1 = single admin
        // type 2 = mix of admin and guardian meeting a threshold
        require(
            signatures.version == 1 || signatures.version == 2,
            "Invalid Signature Version"
        );
        require(signatures.signatureData.length > 0, "Missing Signature");

        if (signatures.version == 1) {
            require(
                signatures.signatureData.length >= 1,
                "Invalid Signature Count"
            );
            if (owner != hash.recover(userOp.signature))
                return SIG_VALIDATION_FAILED;
            return 0;
        } else {
            uint8 signatureCount = 0;
            uint256 length = signatures.signatureData.length;
            for (uint256 n = 0; n < length; ) {
                require(
                    isValidSignatureNow(
                        signatures.signatureData[n].signature,
                        userOpHash
                    ),
                    "Invalid Signature"
                );
                signatureCount += n;
                unchecked {
                    n++;
                }
            }
            if (signatureCount >= threshold) {
                return 0;
            } else {
                return SIG_VALIDATION_FAILED;
            }
        }
    }

    function _validateSignature(
        SignatureData memory _signatureData,
        bytes32 userOpHash
    ) internal returns (bool) {
        address signer = _signatureData;
        // check if signature is valid with open zeppellin
        // bool isValid = isValidSignatureNow(_signatureData, userOpHash);
        return true;
    }

    function _validateAdminSignature(
        Signature _signature,
        bytes32 userOpHash
    ) internal returns (bool) {
        address signer = _signature.signature;
        // check if signature is valid with open zeppellin
        bool isValid = isValidSignatureNow(_signature, userOpHash);
        return true;
    }

    /// implement template method of BaseAccount
    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override {
        require(_nonce++ == userOp.nonce, "account: invalid nonce");
    }

    /**
     * check current account deposit in the entryPoint
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint().balanceOf(address(this));
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
    ) public onlyOwner {
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        (newImplementation);
        _onlyOwner();
    }
}
