// Export all event handlers
export * from "./BtcVaultToken";
export * from "./BtcVaultStrategy";

// Log startup
console.log("🚀 SovaBTC Indexer Started");
console.log(`Network: ${process.env.NETWORK || "base-sepolia"}`);
console.log(`Database: ${process.env.PONDER_DATABASE_URL ? "Connected" : "Not configured"}`);