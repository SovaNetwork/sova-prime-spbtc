// Deployment script for the hook-based system

async function main() {
  console.log("Deploying hook-based system...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy or connect to existing tRWA token
  const tRWAAddress = process.env.TRWA_ADDRESS;
  let tRWA;

  if (tRWAAddress) {
    console.log("Connecting to existing tRWA at:", tRWAAddress);
    const tRWAFactory = await ethers.getContractFactory("tRWA");
    tRWA = tRWAFactory.attach(tRWAAddress);
  } else {
    // If we need to deploy a new tRWA token, add deployment code here
    console.error("tRWA address not provided. Set TRWA_ADDRESS environment variable.");
    return;
  }

  // Deploy TransferApprovalHook
  console.log("Deploying TransferApprovalHook...");
  const TransferApprovalHook = await ethers.getContractFactory("TransferApprovalHook");
  const transferApprovalHook = await TransferApprovalHook.deploy(
    tRWA.address,
    deployer.address
  );
  await transferApprovalHook.deployed();
  console.log("TransferApprovalHook deployed to:", transferApprovalHook.address);

  // Deploy SubscriptionHook
  console.log("Deploying SubscriptionHook...");
  const SubscriptionHook = await ethers.getContractFactory("SubscriptionHook");

  // Get subscription module address if it exists
  const subscriptionModuleAddress = process.env.SUBSCRIPTION_MODULE_ADDRESS || deployer.address;

  const subscriptionHook = await SubscriptionHook.deploy(
    tRWA.address,
    subscriptionModuleAddress,
    deployer.address
  );
  await subscriptionHook.deployed();
  console.log("SubscriptionHook deployed to:", subscriptionHook.address);

  // Add hooks to tRWA
  console.log("Adding hooks to tRWA...");

  // Add transfer approval hook
  let tx = await tRWA.addHook(transferApprovalHook.address);
  let receipt = await tx.wait();
  const transferHookId = receipt.events.find(e => e.event === "HookAdded").args.hookId;
  console.log("TransferApprovalHook added with ID:", transferHookId.toString());

  // Add subscription hook
  tx = await tRWA.addHook(subscriptionHook.address);
  receipt = await tx.wait();
  const subscriptionHookId = receipt.events.find(e => e.event === "HookAdded").args.hookId;
  console.log("SubscriptionHook added with ID:", subscriptionHookId.toString());

  // If subscription module exists, update it to use the new hook
  if (process.env.SUBSCRIPTION_MODULE_ADDRESS) {
    console.log("Updating subscription module to use hook...");
    const ApprovalSubscriptionModule = await ethers.getContractFactory("ApprovalSubscriptionModule");
    const subscriptionModule = ApprovalSubscriptionModule.attach(subscriptionModuleAddress);

    tx = await subscriptionModule.setSubscriptionHook(subscriptionHook.address);
    await tx.wait();
    console.log("Subscription module updated");
  }

  // Disable legacy transfer approval if it was being used
  const transferApprovalEnabled = await tRWA.transferApprovalEnabled();
  if (transferApprovalEnabled) {
    console.log("Disabling legacy transfer approval...");
    tx = await tRWA.toggleTransferApproval(false);
    await tx.wait();
    console.log("Legacy transfer approval disabled");
  }

  console.log("Hook-based system deployed successfully!");
  console.log({
    tRWA: tRWA.address,
    transferApprovalHook: transferApprovalHook.address,
    subscriptionHook: subscriptionHook.address,
    transferHookId: transferHookId.toString(),
    subscriptionHookId: subscriptionHookId.toString()
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });