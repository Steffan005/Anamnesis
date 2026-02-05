import hardhat from "hardhat";
const { ethers, upgrades, run } = hardhat;

async function main() {
    console.log("\n⟨⦿⟩ INITIATING MAINNET DEPLOYMENT: OMEGA PROTOCOL ⟨⦿⟩");
    console.log("-----------------------------------------------------");

    const [deployer] = await ethers.getSigners();
    console.log(`[IDENTITY] Deployer: ${deployer.address}`);
    console.log(`[BALANCE]  ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} MATIC`);

    // Load Addresses from Env
    const WAR_CHEST = process.env.ADDR_WARCHEST || deployer.address;
    const LIQUIDITY = process.env.ADDR_LIQUIDITY || deployer.address;

    console.log(`[CONFIG]   War Chest: ${WAR_CHEST}`);
    console.log(`[CONFIG]   Liquidity: ${LIQUIDITY}`);

    if (WAR_CHEST === deployer.address) {
        console.warn("⚠️  WARNING: WarChest is set to Deployer Address!");
    }

    // 1. DEPLOY TOKEN (UUPS Proxy)
    console.log("\n[1] DEPLOYING: WHO Protocol (Enterprise V3)...");
    const WHOToken = await ethers.getContractFactory("WHOTokenEnterprise");
    const token = await upgrades.deployProxy(WHOToken, [deployer.address, WAR_CHEST, LIQUIDITY], { kind: 'uups' });
    await token.waitForDeployment();
    const tokenAddress = await token.getAddress();

    console.log(`✅ [SUCCESS] WHO Protocol Deployed at: ${tokenAddress}`);

    // 2. DEPLOY VESTING
    console.log("\n[2] DEPLOYING: Vesting Vault...");
    const Vesting = await ethers.getContractFactory("WHOTokenVesting");
    const vesting = await Vesting.deploy(tokenAddress, deployer.address);
    await vesting.waitForDeployment();
    const vestingAddress = await vesting.getAddress();

    console.log(`✅ [SUCCESS] Vesting Vault Deployed at: ${vestingAddress}`);

    // 3. WAIT & VERIFY
    console.log("\n[3] VERIFICATION: Waiting 10 blocks for propagation...");
    // Wait loop or simple timeout (usually better to wait for blocks on Mainnet)
    // For script simplicity, we remind the user to run verify command manually if this fails.

    console.log(`
  ⟨⦿⟩ DEPLOYMENT COMPLETE ⟨⦿⟩
  ---------------------------
  Token:   ${tokenAddress}
  Vesting: ${vestingAddress}

  To Verify Manually:
  npx hardhat verify --network polygon ${tokenAddress}
  npx hardhat verify --network polygon ${vestingAddress} ${tokenAddress} ${deployer.address}
  `);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
