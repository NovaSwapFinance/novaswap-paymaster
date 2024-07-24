// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title MyERC20Token
 * @dev This is a basic ERC20 token using the OpenZeppelin's ERC20PresetFixedSupply preset.
 * You can edit the default values as needed.
 */
contract Token is ERC20Burnable {
    /**
     * @dev Constructor to initialize the token with default values.
     * You can edit these values as needed.
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Default initial supply of 1 million tokens (with 18 decimals)
        uint256 initialSupply = 1_000_000_000_000_000 * (10 ** decimals());

        // The initial supply is minted to the deployer's address
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    // Additional functions or overrides can be added here if needed.
}
