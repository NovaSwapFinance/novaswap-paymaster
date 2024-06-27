// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPaymaster, ExecutionResult, PAYMASTER_VALIDATION_SUCCESS_MAGIC} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymaster.sol";
import {IPaymasterFlow} from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IPaymasterFlow.sol";
import {TransactionHelper, Transaction} from "@matterlabs/zksync-contracts/l2/system-contracts/libraries/TransactionHelper.sol";

import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IQuoter.sol";

contract Paymaster is Initializable, IPaymaster, OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    address public router;
    address public long;

    uint256 public gasFactor;
    uint256 constant MAX_FACTOR = 1e10;

    bytes private hashKey;

    bool public allowTokenSwitch;

    mapping(address => bool) public allowedTokenList;

    address public WETH;

    modifier onlyBootloader() {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS, "Only bootloader can call this method");
        // Continue execution if called from the bootloader.
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address _router, uint256 _gasFactor) public initializer {
        __UUPSUpgradeable_init_unchained();
        __Ownable_init_unchained();
        require(_router != address(0), "invalid router");
        router = _router;
        require(_gasFactor <= MAX_FACTOR, "invalid gasFactor");
        gasFactor = _gasFactor;
        WETH = address(0x8280a4e7D5B3B658ec4580d3Bc30f5e50454F169);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function validateAndPayForPaymasterTransaction(
        bytes32,
        bytes32,
        Transaction calldata _transaction
    ) external payable onlyBootloader returns (bytes4 magic, bytes memory context) {
        // By default we consider the transaction as accepted.
        magic = PAYMASTER_VALIDATION_SUCCESS_MAGIC;
        require(_transaction.paymasterInput.length >= 4, "The standard paymaster input must be at least 4 bytes long");

        bytes4 paymasterInputSelector = bytes4(_transaction.paymasterInput[0:4]);

        if (paymasterInputSelector == IPaymasterFlow.approvalBased.selector) {
            // While the transaction data consists of address, uint256 and bytes data,
            // the data is not needed for this paymaster
            (address token, , bytes memory inner) = abi.decode(
                _transaction.paymasterInput[4:],
                (address, uint256, bytes)
            );

            address userAddress = address(uint160(_transaction.from));

            // Verify if token is the correct one
            if (allowTokenSwitch) {
                require(allowedTokenList[token], "Invalid token for paying fee");
            }

            // We verify that the user has provided enough allowance
            uint256 providedAllowance = IERC20(token).allowance(userAddress, address(this));

            // Note, that while the minimal amount of ETH needed is tx.gasPrice * tx.gasLimit,
            // neither paymaster nor account are allowed to access this context variable.
            uint256 requiredETH = _transaction.gasLimit * _transaction.maxFeePerGas;
            uint256 priceForPayingFees = getPriceForPayingFees(requiredETH, token);

            require(providedAllowance >= priceForPayingFees, "Min allowance too low");

            require(_transaction.paymasterInput.length >= 164, "Invalid paymasterInput length");

            bytes32 hashCheck = bytes32(_transaction.paymasterInput[132:164]);
            bytes32 hashGen = keccak256(abi.encodePacked(hashKey, _transaction.nonce));

            if (hashCheck != hashGen) {
                try IERC20(token).transferFrom(userAddress, address(this), priceForPayingFees) {} catch (
                    bytes memory revertReason
                ) {
                    // If the revert reason is empty or represented by just a function selector,
                    // we replace the error with a more user-friendly message
                    if (revertReason.length <= 4) {
                        revert("Failed to transferFrom from users' account");
                    } else {
                        assembly {
                            revert(add(0x20, revertReason), mload(revertReason))
                        }
                    }
                }
            }

            // The bootloader never returns any data, so it can safely be ignored here.
            (bool success, ) = payable(BOOTLOADER_FORMAL_ADDRESS).call{value: requiredETH}("");
            require(success, "Failed to transfer tx fee to the bootloader. Paymaster balance might not be enough.");
        } else {
            revert("Unsupported paymaster flow in paymasterParams.");
        }
    }

    function postTransaction(
        bytes calldata _context,
        Transaction calldata _transaction,
        bytes32,
        bytes32,
        ExecutionResult _txResult,
        uint256 _maxRefundedGas
    ) external payable override onlyBootloader {}

    receive() external payable {}

    function getPriceForPayingFees(uint256 _requiredETH, address _allowedToken) internal returns (uint256 amountOut) {
        uint24 fee = 3000;
        bytes memory bytesPath = abi.encodePacked(WETH, fee, address(_allowedToken));

        uint256 usedETH = (_requiredETH * gasFactor) / MAX_FACTOR;

        (amountOut, , , ) = IQuoter(router).quoteExactInput(bytesPath, usedETH);
    }

    function withdrawFee(address _token, uint256 _value) external onlyOwner {
        address NATIVE_TOKEN = 0x000000000000000000000000000000000000800A;
        if (_token == NATIVE_TOKEN) {
            (bool success, ) = payable(msg.sender).call{value: _value}("");
            require(success, "_safeTransferETH: failed");
        } else {
            IERC20(_token).safeTransfer(msg.sender, _value);
        }
    }

    function setRouter(address _router) external onlyOwner {
        require(_router != address(0), "setRouter: invalid router");
        router = _router;
    }

    function setGasFactor(uint256 _gasFactor) external onlyOwner {
        require(_gasFactor <= MAX_FACTOR, "setGasRefunded: invalid value");
        gasFactor = _gasFactor;
    }

    function setAllowedTokenList(address _allowedToken, bool _isAllowed) external onlyOwner {
        require(_allowedToken != address(0), "setAllowedTokenList: invalid address");

        bool isAllowed = allowedTokenList[_allowedToken];
        if (isAllowed != _isAllowed) {
            allowedTokenList[_allowedToken] = _isAllowed;
        }
    }

    function setHashKey(bytes calldata value) external onlyOwner {
        hashKey = value;
    }

    function setAllowTokenSwitch(bool _switch) external onlyOwner {
        allowTokenSwitch = _switch;
    }
}
