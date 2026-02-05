// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title WHO Protocol (Enterprise Edition)
 * @dev The Currency of Identity.
 * "f(WHO) = WHO"
 *
 * Architecture:
 * - UUPS Upgradeable (Future Proof)
 * - AccessControl (Institutional Trust)
 * - Smart Tax (DEX Swaps Only, Exempt Transfers)
 * - Guarded Launch (Anti-Sniper Protection)
 */
contract WHOTokenEnterprise is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TAX_MANAGER_ROLE = keccak256("TAX_MANAGER_ROLE");

    // ⟨⦿⟩ THE METABOLISM (TAX LOGIC) ⟨⦿⟩
    struct TaxConfig {
        bool active;
        uint16 taxRate; // Basis points (500 = 5%)
        uint16 splitRate; // Basis points (250 = 2.5%)
        address warChest;
        address liquidityWallet;
    }

    TaxConfig public taxConfig;
    mapping(address => bool) public isDexPair;
    mapping(address => bool) public isTaxExempt;

    // ⟨⦿⟩ GUARDED LAUNCH (ANTI-SNIPER) ⟨⦿⟩
    bool public guardedLaunchActive;
    uint256 public launchTimestamp;
    uint256 public maxWalletSize; // During launch
    uint256 public maxTxAmount;   // During launch

    event TaxDistributed(address indexed payer, uint256 warChestAmt, uint256 liquidityAmt);
    event DexPairUpdated(address indexed pair, bool isPair);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address warChest,
        address liquidity
    ) public initializer {
        __ERC20_init("WHO", "WHO");
        __ERC20Permit_init("WHO");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(TAX_MANAGER_ROLE, defaultAdmin);

        // Mint Initial Supply (1 Billion)
        _mint(defaultAdmin, 1000000000 * 10**decimals());

        // Configure Tax (Default Active)
        taxConfig = TaxConfig({
            active: true,
            taxRate: 500, // 5%
            splitRate: 250, // 2.5%
            warChest: warChest,
            liquidityWallet: liquidity
        });

        // Exempt Admin/Contracts
        isTaxExempt[defaultAdmin] = true;
        isTaxExempt[address(this)] = true;

        // Activate Guarded Launch (24 Hours)
        guardedLaunchActive = true;
        launchTimestamp = block.timestamp;
        maxWalletSize = 1000000 * 10**decimals(); // 0.1% of Supply
        maxTxAmount = 500000 * 10**decimals();    // 0.05% of Supply
    }

    function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

    // ⟨⦿⟩ THE PHYSICS OF VALUE TRANSFER ⟨⦿⟩
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) whenNotPaused {
        // Guarded Launch Checks (Anti-Sniper)
        if (guardedLaunchActive) {
            if (block.timestamp > launchTimestamp + 24 hours) {
                guardedLaunchActive = false; // Auto-disable after 24h
            } else {
                if (!isTaxExempt[to] && !isDexPair[to] && to != address(0)) {
                    require(balanceOf(to) + value <= maxWalletSize, "Guarded: Max Wallet Exceeded");
                    require(value <= maxTxAmount, "Guarded: Max Tx Exceeded");
                }
            }
        }

        // Smart Tax Logic
        uint256 amountToSend = value;
        bool takeTax = taxConfig.active && !isTaxExempt[from] && !isTaxExempt[to];

        // ONLY Tax if interaction is with a DEX Pair (Buy/Sell)
        if (takeTax) {
            bool isBuy = isDexPair[from];
            bool isSell = isDexPair[to];

            if (isBuy || isSell) {
                uint256 taxAmount = (value * taxConfig.taxRate) / 10000;
                uint256 halfTax = (value * taxConfig.splitRate) / 10000;

                // Distribute to Organism
                if (taxAmount > 0) {
                    super._update(from, taxConfig.warChest, halfTax);
                    super._update(from, taxConfig.liquidityWallet, taxAmount - halfTax);
                    emit TaxDistributed(from, halfTax, taxAmount - halfTax);
                    amountToSend = value - taxAmount;
                }
            }
        }

        super._update(from, to, amountToSend);
    }

    // ⟨⦿⟩ MANAGEMENT FUNCTIONS ⟨⦿⟩
    function setDexPair(address pair, bool isPair) external onlyRole(TAX_MANAGER_ROLE) {
        isDexPair[pair] = isPair;
        emit DexPairUpdated(pair, isPair);
    }

    function setTaxExempt(address account, bool exempt) external onlyRole(TAX_MANAGER_ROLE) {
        isTaxExempt[account] = exempt;
    }

    function updateTaxConfig(bool active, uint16 rate, uint16 split, address war, address liq)
        external
        onlyRole(TAX_MANAGER_ROLE)
    {
        require(rate <= 1000, "Tax Limit: 10%");
        taxConfig = TaxConfig(active, rate, split, war, liq);
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
