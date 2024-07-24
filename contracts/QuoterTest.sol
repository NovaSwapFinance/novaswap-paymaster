// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./interfaces/IQuoter.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract QuoterTest is UUPSUpgradeable, OwnableUpgradeable {
    address public quoter = 0x86Fc6ab84CFc6a506d51FC722D3aDe959599A98A;
    address public WETH = 0x8280a4e7D5B3B658ec4580d3Bc30f5e50454F169;
    uint256 public constant MAX_FACTOR = 1e10;
    uint256 public gasFactor = 5000000000;
    mapping(address => uint24) public allowedTokenList;
    event PriceForPayingFees(address indexed token, uint256 indexed price);

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function initialize() public initializer {
        __UUPSUpgradeable_init_unchained();
        __Ownable_init_unchained();
    }

    function getPriceForPayingFees(uint256 _requiredETH, address _allowedToken) public returns (uint256) {
        uint24 fee = allowedTokenList[_allowedToken];
        bytes memory bytesPath = abi.encodePacked(WETH, fee, address(_allowedToken));

        uint256 usedETH = (_requiredETH * gasFactor) / MAX_FACTOR;

        (uint256 amountOut, , , ) = IQuoter(quoter).quoteExactInput(bytesPath, usedETH);
        emit PriceForPayingFees(_allowedToken, amountOut);
        return amountOut;
    }

    function setQuoter(address _quoter) public {
        quoter = _quoter;
    }

    function setGasFactor(uint256 _gasFactor) external {
        require(_gasFactor <= MAX_FACTOR, "setGasRefunded: invalid value");
        gasFactor = _gasFactor;
    }

    function setAllowedTokenList(address _allowedToken, uint24 _fee) external {
        require(_allowedToken != address(0), "setAllowedTokenList: invalid address");
        require(_fee > 0, "setAllowedTokenList: invalid fee");
        allowedTokenList[_allowedToken] = _fee;
    }

}
