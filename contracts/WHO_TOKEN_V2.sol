// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WHO Token V2
 * @dev The Currency of Identity.
 * "f(WHO) = WHO"
 *
 * Updates:
 * - 5% Tax (2.5% WarChest, 2.5% Liquidity)
 * - Scalable Airdrop Logic
 */
contract WHOTokenV2 is ERC20, ERC20Permit, Ownable {

    string public constant AXIOM = "f(WHO) = WHO";

    // Tax Settings
    uint256 public constant TAX_RATE = 500; // 5.00%
    uint256 public constant SPLIT_RATE = 250; // 2.5% each
    bool public isTaxActive = true;

    address public warChestWallet;
    address public liquidityWallet;

    // Airdrop Mappings
    mapping(address => bool) public hasClaimed;
    bool public isAirdropActive = false;
    uint256 public constant AIRDROP_CAP = 100000000 * 10**18; // 100M WHO (10%)
    uint256 public totalAirdropped = 0;

    event TaxDistributed(uint256 warChest, uint256 liquidity);

    constructor(address initialOwner, address _warChest, address _liquidity)
        ERC20("WHO", "WHO")
        ERC20Permit("WHO")
        Ownable(initialOwner)
    {
        warChestWallet = _warChest;
        liquidityWallet = _liquidity;
        _mint(msg.sender, 1000000000 * 10**decimals());
    }

    /**
     * @dev Overridden Transfer with Tax Logic
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        uint256 amountToSend = value;

        // Apply Tax if applicable
        // Skip tax for owner, contract itself, or minting/burning
        if (isTaxActive && from != address(0) && to != address(0) && from != owner() && to != owner()) {
            uint256 taxAmount = (value * TAX_RATE) / 10000;
            uint256 halfTax = taxAmount / 2;

            // Distribute
            super._update(from, warChestWallet, halfTax);
            super._update(from, liquidityWallet, halfTax);

            amountToSend = value - taxAmount;
            emit TaxDistributed(halfTax, halfTax);
        }

        super._update(from, to, amountToSend);
    }

    function setTaxActive(bool _active) external onlyOwner {
        isTaxActive = _active;
    }

    function setWallets(address _warChest, address _liquidity) external onlyOwner {
        warChestWallet = _warChest;
        liquidityWallet = _liquidity;
    }

    /**
     * @dev Simple Node Claim (Restricted by Backend Signature in Prod)
     * For now, open claim for ease of testing
     */
    function claimNodeReward(uint256 amount) external {
        require(isAirdropActive, "Airdrop Closed");
        require(!hasClaimed[msg.sender], "Claimed");
        require(totalAirdropped + amount <= AIRDROP_CAP, "Cap Hit");

        hasClaimed[msg.sender] = true;
        totalAirdropped += amount;

        _transfer(owner(), msg.sender, amount);
    }

    function setAirdropStatus(bool _status) external onlyOwner {
        isAirdropActive = _status;
    }
}
