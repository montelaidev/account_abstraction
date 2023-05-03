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

contract MimoWallet is
    BaseAccount,
    UUPSUpgradeable,
    Initializable,
    IERC1271,
    AccessControl
{
    using WalletSignatures for bytes;
    using WalletSignatures for bytes32;
    using ECDSA for bytes32;
    using Exec for address;

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
        grantRole(DEFAULT_ADMIN_ROLE, anOwner);
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
            "only owner"
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
        bytes[] calldata func
    ) external {
        _requireFromEntryPointOrAuthorized();
        require(dest.length == func.length, "wrong array lengths");
        for (uint256 i = 0; i < dest.length; i++) {
            _call(dest[i], 0, func[i]);
        }
    }

    function _validateSignature(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) internal override returns (uint256 validationData) {
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

        // TODO - validate validTill and validAfter
        if (signatures.version == 1) {
            require(
                signatures.signatureData.length != 1,
                "Invalid Signature Count"
            );
            _validateAdminSignature(signatures.signatureData[0], userOpHash);
        } else {
            _validateSignatures(signatures.signatureData, userOpHash);
        }

        return 0;
    }

    function _validateSignatures(
        SignatureData[] memory _signatureData,
        bytes32 userOpHash
    ) internal returns (bool) {
        uint8 signatureCount = 0;
        uint256 length = _signatureData.length;
        for (uint256 n = 0; n < length; ) {
            if (
                hasRole(
                    GUARDIAN_ROLE,
                    userOpHash.recover(_signatureData[n].signature)
                ) ||
                hasRole(
                    DEFAULT_ADMIN_ROLE,
                    userOpHash.recover(_signatureData[n].signature)
                )
            ) {
                signatureCount += n;
                unchecked {
                    n++;
                }
            }
        }
        require(signatureCount < threshold, SIG_VALIDATION_FAILED);
        return true;
    }

    function _validateAdminSignature(
        SignatureData memory _signatureData,
        bytes32 userOpHash
    ) internal returns (bool) {
        require(
            !hasRole(DEFAULT_ADMIN_ROLE, userOpHash.recover(_signatureData)),
            SIG_VALIDATION_FAILED
        );
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
