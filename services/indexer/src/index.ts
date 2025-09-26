// Import event handlers (they register themselves)
import "./BtcVaultToken";
import "./BtcVaultStrategy";

// Log startup
console.log("🚀 SovaBTC Indexer Started");
console.log(`Network: ${process.env.NETWORK || "base-sepolia"}`);
console.log(`Database: ${process.env.PONDER_DATABASE_URL ? "Connected" : "Not configured"}`);