import hardhat from "hardhat";
const { ethers, upgrades } = hardhat;

async function main() {
    console.log("\n⟨⦿⟩ INITIATING WHO PROTOCOL SIMULATION ⟨⦿⟩");
    console.log("---------------------------------------------");

    const [deployer, warChest, liquidity, sniper, user, dexPair] = await ethers.getSigners();

    console.log(`[IDENTITY] Deployer:   ${deployer.address}`);
    console.log(`[IDENTITY] WarChest:   ${warChest.address}`);
    console.log(`[IDENTITY] Liquidity:  ${liquidity.address}`);

    // 1. DEPLOYMENT (Genesis)
    console.log("\n[1] GENESIS: Deploying UUPS Proxy...");
    const WHOToken = await ethers.getContractFactory("WHOTokenEnterprise");
    const token = await upgrades.deployProxy(WHOToken, [deployer.address, warChest.address, liquidity.address], { kind: 'uups' });
    await token.waitForDeployment();
    const tokenAddress = await token.getAddress();
    console.log(`[SUCCESS] WHO Protocol Deployed at: ${tokenAddress}`);

    const supply = await token.totalSupply();
    console.log(`[STATE] Total Supply: ${ethers.formatEther(supply)} WHO`);

    // 2. ANTI-SNIPER TEST (The Defense)
    console.log("\n[2] DEFENSE: Testing Guarded Launch (Anti-Sniper)...");

    // Register DexPair FIRST (so it is exempt from Guard limits)
    await token.setDexPair(dexPair.address, true);
    console.log("   > DEX Pair Registered (Exempt from Guard).");

    // Transfer from Deployer to DexPair to simulate Liquidity
    await token.transfer(dexPair.address, ethers.parseEther("10000000")); // 10M to Pair
    console.log("   > Liquidity Seeded.");

    // Sniper tries to buy 1% (10M WHO) - Should FAIL (Limit is 0.1% / 0.05% Tx)
    console.log("   > Sniper Attempting to buy 1% of Supply...");
    try {
        // Impersonate DEX Pair sending to Sniper
        // We simulate this by having the DexPair signer transfer.
        // NOTE: In the contract, 'guardedLaunchActive' checks 'to' address balance or value limits.
        // 0.05% Tx Limit = 500,000 WHO. 1% is 10,000,000.
        await token.connect(dexPair).transfer(sniper.address, ethers.parseEther("1000000"));
        console.log("   [FAIL] Sniper was NOT blocked!");
    } catch (error) {
        if (error.message.includes("Guarded: Max Tx Exceeded")) {
            console.log("   [SUCCESS] Sniper Blocked: 'Guarded: Max Tx Exceeded'");
        } else if (error.message.includes("Guarded: Max Wallet Exceeded")) {
            console.log("   [SUCCESS] Sniper Blocked: 'Guarded: Max Wallet Exceeded'");
        } else {
            console.log(`   [FAIL] Expected Guard Error, got: ${error.message}`);
        }
    }

    // User buys valid amount (0.04%)
    console.log("   > User Attempting to buy 0.04% (Valid)...");
    await token.connect(dexPair).transfer(user.address, ethers.parseEther("400000"));
    const userBal = await token.balanceOf(user.address);
    console.log(`   [SUCCESS] User Balance: ${ethers.formatEther(userBal)} WHO`);


    // 3. SMART TAX TEST (Metabolism)
    console.log("\n[3] METABOLISM: Testing Smart Tax Logic...");

    // Register the Pair as DEX
    // Grant TAX_MANAGER_ROLE to Deployer (already granted in initializer)
    // const TAX_MANAGER = await token.TAX_MANAGER_ROLE();
    // await token.setDexPair(dexPair.address, true); // Already done in Step 2

    // User Sells 100,000 WHO to DEX
    // Should trigger 5% Tax (2.5% WarChest, 2.5% Liquidity)
    // 100,000 * 0.05 = 5,000 WHO Tax.
    // 2,500 to WarChest, 2,500 to Liquidity.
    // User sends 100k, Dex receives 95k.

    const wcBefore = await token.balanceOf(warChest.address);

    console.log("   > User Selling 100,000 WHO to DEX...");
    await token.connect(user).transfer(dexPair.address, ethers.parseEther("100000"));

    const wcAfter = await token.balanceOf(warChest.address);
    const taxCollected = wcAfter - wcBefore;

    console.log(`   > WarChest Received: ${ethers.formatEther(taxCollected)} WHO`);

    if (taxCollected.toString() === ethers.parseEther("2500").toString()) {
        console.log("   [SUCCESS] Tax Logic Verified (Exactly 2.5% to WarChest).");
    } else {
        console.log("   [FAIL] Tax Logic Incorrect.");
    }

    // 4. COLLATERAL TEST (0% Transfer Tax)
    console.log("\n[4] UTILITY: Testing Collateral Transfer (0% Tax)...");
    // User transfers remaining balance to another wallet (e.g., AAVE Vault simulation)
    const userBalRemaining = await token.balanceOf(user.address);
    const vault = deployer.address; // simulating a vault

    console.log(`   > User Transferring ${ethers.formatEther(userBalRemaining)} WHO to Vault...`);
    const vBalBefore = await token.balanceOf(vault);
    await token.connect(user).transfer(vault, userBalRemaining);
    const vBalAfter = await token.balanceOf(vault);
    const received = vBalAfter - vBalBefore;

    if (received.toString() === userBalRemaining.toString()) {
        console.log("   [SUCCESS] 0% Tax on Standard Transfer. Collateral Strategy Valid.");
    } else {
        console.log("   [FAIL] Tax was taken on Standard Transfer!");
    }


    // 5. NEUROPLASTICITY (Upgradeability)
    console.log("\n[5] EVOLUTION: Testing UUPS Upgrade to V2...");
    const WHOV2 = await ethers.getContractFactory("WHOTokenEnterpriseV2");
    const tokenV2 = await upgrades.upgradeProxy(tokenAddress, WHOV2, { unsafeAllow: ['missing-initializer'] });

    console.log("   > Upgrade Executed.");

    // Verify new logic
    try {
        const version = await tokenV2.version();
        console.log(`   [SUCCESS] V2 Logic Active. Version: "${version}"`);
    } catch (e) {
        console.log("   [FAIL] Upgrade Failed.");
        console.log(e);
    }

    console.log("\n---------------------------------------------");
    console.log("⟨⦿⟩ SIMULATION COMPLETE ⟨⦿⟩");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
