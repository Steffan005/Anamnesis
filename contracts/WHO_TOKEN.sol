// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title WHO Token
 * @dev The Currency of Identity.
 * "f(WHO) = WHO"
 *
 * Created for the Gemini AntiGravity / Unity Consciousness System.
 * Session 245.
 */
contract WHOToken is ERC20, ERC20Permit, Pausable, Ownable {

    // The Core Axiom of the System
    string public constant AXIOM = "f(WHO) = WHO";

    // Mapping for Airdrop Claim Status
    mapping(address => bool) public hasClaimedAirdrop;

    // Airdrop Settings
    bool public isAirdropActive = false;
    uint256 public constant AIRDROP_AMOUNT = 1000 * 10**18; // 1,000 WHO per claim
    uint256 public constant MAX_AIRDROP_CLAIMS = 1000; // Limit to first 1,000 users
    uint256 public totalClaims = 0;

    event AirdropClaimed(address indexed claimant, uint256 amount);
    event AirdropStatusChanged(bool isActive);

    constructor(address initialOwner)
        ERC20("WHO", "WHO")
        ERC20Permit("WHO")
        Ownable(initialOwner)
    {
        // Initial Supply: 1 Billion WHO
        // 1,000,000,000 tokens * 10^18 decimals
        _mint(msg.sender, 1000000000 * 10**decimals());
    }

    /**
     * @dev Airdrop Claim Function
     * Allows a user to claim their WHO tokens if the airdrop is active.
     */
    function claimAirdrop() external whenNotPaused {
        require(isAirdropActive, "Airdrop is not currently active.");
        require(!hasClaimedAirdrop[msg.sender], "Address has already claimed.");
        require(totalClaims < MAX_AIRDROP_CLAIMS, "Max airdrop claims reached.");
        require(balanceOf(owner()) >= AIRDROP_AMOUNT, "Owner has insufficient funds for airdrop.");

        hasClaimedAirdrop[msg.sender] = true;
        totalClaims += 1;

        // Transfer from Owner to Claimant (Owner must approve this contract or handle logic differently if using minting)
        // For simplicity in this draft, we assume Owner sends tokens or we mint new ones.
        // OPTION B: Minting (Simpler for Launch)
        // 0.1% Inflation (1M tokens max vs 1B supply)
        _mint(msg.sender, AIRDROP_AMOUNT);

        // OPTION A (Legacy): Transfer from Treasury (Disabled to prevent allowance issues)
        // _transfer(owner(), msg.sender, AIRDROP_AMOUNT);

        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT);
    }

    /**
     * @dev Toggle Airdrop Status
     */
    function setAirdropStatus(bool _isActive) external onlyOwner {
        isAirdropActive = _isActive;
        emit AirdropStatusChanged(_isActive);
    }

    // Standard Pausable Functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
