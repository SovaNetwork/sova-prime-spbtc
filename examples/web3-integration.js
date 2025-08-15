/**
 * Multi-Collateral BTC Vault Web3 Integration Example
 * 
 * This example demonstrates how to interact with the MultiBTCVault system
 * using Web3.js or Ethers.js in a frontend application.
 */

import { ethers } from 'ethers';

// Contract ABIs (simplified for example)
const VAULT_ABI = [
    "function deposit(uint256 assets, address receiver) returns (uint256 shares)",
    "function requestRedeem(uint256 shares, address receiver, address owner) returns (uint256)",
    "function totalAssets() view returns (uint256)",
    "function balanceOf(address owner) view returns (uint256)",
    "function convertToShares(uint256 assets) view returns (uint256)",
    "function convertToAssets(uint256 shares) view returns (uint256)",
    "function previewDeposit(uint256 assets) view returns (uint256)",
    "function previewRedeem(uint256 shares) view returns (uint256)",
    "event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares)",
    "event RedemptionRequested(uint256 indexed requestId, address indexed requester, address indexed receiver, uint256 shares, uint256 maturityTimestamp)"
];

const ERC20_ABI = [
    "function approve(address spender, uint256 amount) returns (bool)",
    "function balanceOf(address owner) view returns (uint256)",
    "function decimals() view returns (uint8)",
    "function allowance(address owner, address spender) view returns (uint256)"
];

const QUEUE_ABI = [
    "function redemptionRequests(uint256 requestId) view returns (address requester, address receiver, uint256 shares, uint256 requestTimestamp, uint256 maturityTimestamp)",
    "function isRequestMature(uint256 requestId) view returns (bool)",
    "function queueLength() view returns (uint256)"
];

// Contract addresses (update with deployed addresses)
const ADDRESSES = {
    VAULT: '0x...', // MultiBTCVault address
    QUEUE: '0x...', // ManagedRedemptionQueue address
    WBTC: '0x...', // WBTC token address
    TBTC: '0x...', // TBTC token address
    SOVABTC: '0x...', // sovaBTC token address
};

/**
 * Main vault integration class
 */
class MultiBTCVaultIntegration {
    constructor(provider, signer) {
        this.provider = provider;
        this.signer = signer;
        
        // Initialize contracts
        this.vault = new ethers.Contract(ADDRESSES.VAULT, VAULT_ABI, signer);
        this.queue = new ethers.Contract(ADDRESSES.QUEUE, QUEUE_ABI, signer);
        
        // Initialize token contracts
        this.wbtc = new ethers.Contract(ADDRESSES.WBTC, ERC20_ABI, signer);
        this.tbtc = new ethers.Contract(ADDRESSES.TBTC, ERC20_ABI, signer);
        this.sovaBTC = new ethers.Contract(ADDRESSES.SOVABTC, ERC20_ABI, signer);
        
        this.setupEventListeners();
    }
    
    /**
     * Setup event listeners for vault events
     */
    setupEventListeners() {
        // Listen for deposits
        this.vault.on("Deposit", (sender, owner, assets, shares, event) => {
            console.log(`Deposit Event:`, {
                sender: sender,
                owner: owner,
                assets: assets.toString(),
                shares: shares.toString(),
                blockNumber: event.blockNumber,
                txHash: event.transactionHash
            });
            
            // Update UI or trigger notifications
            this.onDepositReceived(sender, owner, assets, shares);
        });
        
        // Listen for redemption requests
        this.vault.on("RedemptionRequested", (requestId, requester, receiver, shares, maturity, event) => {
            console.log(`Redemption Requested:`, {
                requestId: requestId.toString(),
                requester: requester,
                receiver: receiver,
                shares: shares.toString(),
                maturityDate: new Date(maturity.toNumber() * 1000),
                txHash: event.transactionHash
            });
            
            // Update UI with redemption info
            this.onRedemptionRequested(requestId, requester, shares, maturity);
        });
    }
    
    /**
     * Connect wallet and initialize
     */
    async connect() {
        try {
            // Request account access
            const accounts = await this.provider.send("eth_requestAccounts", []);
            const address = accounts[0];
            
            // Get network info
            const network = await this.provider.getNetwork();
            console.log(`Connected to ${network.name} (chainId: ${network.chainId})`);
            console.log(`Wallet address: ${address}`);
            
            return address;
        } catch (error) {
            console.error("Failed to connect wallet:", error);
            throw error;
        }
    }
    
    /**
     * Get user's current position in the vault
     */
    async getUserPosition(userAddress = null) {
        try {
            const address = userAddress || await this.signer.getAddress();
            
            // Get mcBTC balance
            const shares = await this.vault.balanceOf(address);
            
            // Convert to BTC value
            const btcValue = await this.vault.convertToAssets(shares);
            
            // Get token balances
            const wbtcBalance = await this.wbtc.balanceOf(address);
            const tbtcBalance = await this.tbtc.balanceOf(address);
            const sovaBTCBalance = await this.sovaBTC.balanceOf(address);
            
            return {
                mcBTCShares: ethers.utils.formatEther(shares),
                btcValue: ethers.utils.formatUnits(btcValue, 8),
                collateralBalances: {
                    wbtc: ethers.utils.formatUnits(wbtcBalance, 8),
                    tbtc: ethers.utils.formatEther(tbtcBalance),
                    sovaBTC: ethers.utils.formatEther(sovaBTCBalance)
                }
            };
        } catch (error) {
            console.error("Failed to get user position:", error);
            throw error;
        }
    }
    
    /**
     * Deposit WBTC into the vault
     */
    async depositWBTC(amountInBTC) {
        try {
            const userAddress = await this.signer.getAddress();
            const amount = ethers.utils.parseUnits(amountInBTC.toString(), 8); // WBTC has 8 decimals
            
            // Check minimum deposit (0.001 BTC)
            const minDeposit = ethers.utils.parseUnits("0.001", 8);
            if (amount.lt(minDeposit)) {
                throw new Error("Deposit amount below minimum of 0.001 BTC");
            }
            
            // Check user balance
            const balance = await this.wbtc.balanceOf(userAddress);
            if (balance.lt(amount)) {
                throw new Error(`Insufficient WBTC balance. Have: ${ethers.utils.formatUnits(balance, 8)} BTC`);
            }
            
            // Check current allowance
            const currentAllowance = await this.wbtc.allowance(userAddress, ADDRESSES.VAULT);
            
            // Approve if needed
            if (currentAllowance.lt(amount)) {
                console.log("Approving WBTC spend...");
                const approveTx = await this.wbtc.approve(ADDRESSES.VAULT, amount);
                await approveTx.wait();
                console.log("Approval confirmed:", approveTx.hash);
            }
            
            // Preview deposit to show expected shares
            const expectedShares = await this.vault.previewDeposit(amount);
            console.log(`Expected mcBTC shares: ${ethers.utils.formatEther(expectedShares)}`);
            
            // Execute deposit
            console.log("Executing deposit...");
            const depositTx = await this.vault.deposit(amount, userAddress);
            const receipt = await depositTx.wait();
            
            // Parse events to get actual shares received
            const depositEvent = receipt.events.find(e => e.event === 'Deposit');
            const actualShares = depositEvent.args.shares;
            
            console.log("Deposit successful!");
            return {
                success: true,
                txHash: receipt.transactionHash,
                deposited: amountInBTC,
                sharesReceived: ethers.utils.formatEther(actualShares),
                gasUsed: receipt.gasUsed.toString()
            };
            
        } catch (error) {
            console.error("Deposit failed:", error);
            return {
                success: false,
                error: error.message
            };
        }
    }
    
    /**
     * Deposit TBTC into the vault
     */
    async depositTBTC(amountInBTC) {
        try {
            const userAddress = await this.signer.getAddress();
            const amount = ethers.utils.parseEther(amountInBTC.toString()); // TBTC has 18 decimals
            
            // Check minimum deposit (0.001 BTC equivalent)
            const minDeposit = ethers.utils.parseEther("0.001");
            if (amount.lt(minDeposit)) {
                throw new Error("Deposit amount below minimum of 0.001 BTC");
            }
            
            // Similar flow as WBTC but with 18 decimals
            const balance = await this.tbtc.balanceOf(userAddress);
            if (balance.lt(amount)) {
                throw new Error(`Insufficient TBTC balance`);
            }
            
            // Approve and deposit
            const currentAllowance = await this.tbtc.allowance(userAddress, ADDRESSES.VAULT);
            if (currentAllowance.lt(amount)) {
                const approveTx = await this.tbtc.approve(ADDRESSES.VAULT, amount);
                await approveTx.wait();
            }
            
            const depositTx = await this.vault.deposit(amount, userAddress);
            const receipt = await depositTx.wait();
            
            return {
                success: true,
                txHash: receipt.transactionHash
            };
            
        } catch (error) {
            console.error("TBTC deposit failed:", error);
            return {
                success: false,
                error: error.message
            };
        }
    }
    
    /**
     * Request redemption of mcBTC shares
     */
    async requestRedemption(shareAmount) {
        try {
            const userAddress = await this.signer.getAddress();
            const shares = ethers.utils.parseEther(shareAmount.toString());
            
            // Check user has enough shares
            const balance = await this.vault.balanceOf(userAddress);
            if (balance.lt(shares)) {
                throw new Error(`Insufficient mcBTC balance. Have: ${ethers.utils.formatEther(balance)}`);
            }
            
            // Preview redemption value
            const expectedAssets = await this.vault.previewRedeem(shares);
            console.log(`Expected sovaBTC to receive: ${ethers.utils.formatEther(expectedAssets)}`);
            
            // Request redemption
            console.log("Requesting redemption...");
            const redeemTx = await this.vault.requestRedeem(shares, userAddress, userAddress);
            const receipt = await redeemTx.wait();
            
            // Get request ID from event
            const event = receipt.events.find(e => e.event === 'RedemptionRequested');
            const requestId = event.args.requestId;
            const maturityTimestamp = event.args.maturityTimestamp;
            
            const maturityDate = new Date(maturityTimestamp.toNumber() * 1000);
            
            console.log("Redemption requested successfully!");
            return {
                success: true,
                requestId: requestId.toString(),
                txHash: receipt.transactionHash,
                sharesQueued: shareAmount,
                expectedSovaBTC: ethers.utils.formatEther(expectedAssets),
                maturityDate: maturityDate.toISOString(),
                daysToWait: 14
            };
            
        } catch (error) {
            console.error("Redemption request failed:", error);
            return {
                success: false,
                error: error.message
            };
        }
    }
    
    /**
     * Check status of a redemption request
     */
    async checkRedemptionStatus(requestId) {
        try {
            const request = await this.queue.redemptionRequests(requestId);
            const isMature = await this.queue.isRequestMature(requestId);
            
            const now = Date.now() / 1000;
            const maturityTimestamp = request.maturityTimestamp.toNumber();
            const timeRemaining = Math.max(0, maturityTimestamp - now);
            
            return {
                requestId: requestId,
                requester: request.requester,
                receiver: request.receiver,
                shares: ethers.utils.formatEther(request.shares),
                requestDate: new Date(request.requestTimestamp.toNumber() * 1000),
                maturityDate: new Date(maturityTimestamp * 1000),
                isMature: isMature,
                timeRemaining: {
                    seconds: timeRemaining,
                    days: Math.floor(timeRemaining / 86400),
                    hours: Math.floor((timeRemaining % 86400) / 3600),
                    minutes: Math.floor((timeRemaining % 3600) / 60)
                },
                status: isMature ? 'Ready for processing' : 'Waiting'
            };
            
        } catch (error) {
            console.error("Failed to check redemption status:", error);
            throw error;
        }
    }
    
    /**
     * Get vault statistics
     */
    async getVaultStats() {
        try {
            const totalAssets = await this.vault.totalAssets();
            const totalShares = await this.vault.totalSupply();
            const queueLength = await this.queue.queueLength();
            
            // Calculate NAV (Net Asset Value per share)
            const nav = totalShares.gt(0) 
                ? totalAssets.mul(ethers.utils.parseEther("1")).div(totalShares)
                : ethers.utils.parseEther("1");
            
            return {
                totalValueLocked: ethers.utils.formatUnits(totalAssets, 8) + " BTC",
                totalSharesIssued: ethers.utils.formatEther(totalShares) + " mcBTC",
                navPerShare: ethers.utils.formatEther(nav),
                pendingRedemptions: queueLength.toString(),
                vaultAddress: ADDRESSES.VAULT,
                queueAddress: ADDRESSES.QUEUE
            };
            
        } catch (error) {
            console.error("Failed to get vault stats:", error);
            throw error;
        }
    }
    
    /**
     * Estimate gas for operations
     */
    async estimateGas(operation, ...params) {
        try {
            let gasEstimate;
            
            switch(operation) {
                case 'deposit':
                    gasEstimate = await this.vault.estimateGas.deposit(...params);
                    break;
                case 'redeem':
                    gasEstimate = await this.vault.estimateGas.requestRedeem(...params);
                    break;
                case 'approve':
                    gasEstimate = await this.wbtc.estimateGas.approve(...params);
                    break;
                default:
                    throw new Error("Unknown operation");
            }
            
            const gasPrice = await this.provider.getGasPrice();
            const gasCost = gasEstimate.mul(gasPrice);
            
            return {
                gasLimit: gasEstimate.toString(),
                gasPrice: ethers.utils.formatUnits(gasPrice, "gwei") + " gwei",
                estimatedCost: ethers.utils.formatEther(gasCost) + " ETH"
            };
            
        } catch (error) {
            console.error("Gas estimation failed:", error);
            throw error;
        }
    }
    
    /**
     * Helper: Format BTC amount for display
     */
    formatBTC(amount, decimals = 8) {
        return ethers.utils.formatUnits(amount, decimals) + " BTC";
    }
    
    /**
     * Helper: Format shares for display
     */
    formatShares(shares) {
        return ethers.utils.formatEther(shares) + " mcBTC";
    }
    
    /**
     * Event handlers (override these in your implementation)
     */
    onDepositReceived(sender, owner, assets, shares) {
        // Override this method to handle deposit events
        console.log("Deposit received - update UI");
    }
    
    onRedemptionRequested(requestId, requester, shares, maturity) {
        // Override this method to handle redemption events
        console.log("Redemption requested - update UI");
    }
}

/**
 * Example usage
 */
async function main() {
    // Initialize provider (MetaMask in this example)
    if (typeof window.ethereum === 'undefined') {
        console.error('Please install MetaMask!');
        return;
    }
    
    const provider = new ethers.providers.Web3Provider(window.ethereum);
    const signer = provider.getSigner();
    
    // Create vault integration instance
    const vault = new MultiBTCVaultIntegration(provider, signer);
    
    // Connect wallet
    const address = await vault.connect();
    console.log("Connected:", address);
    
    // Get user position
    const position = await vault.getUserPosition();
    console.log("User Position:", position);
    
    // Get vault stats
    const stats = await vault.getVaultStats();
    console.log("Vault Stats:", stats);
    
    // Example: Deposit 0.1 WBTC
    // const depositResult = await vault.depositWBTC(0.1);
    // console.log("Deposit Result:", depositResult);
    
    // Example: Request redemption of 0.05 mcBTC
    // const redeemResult = await vault.requestRedemption(0.05);
    // console.log("Redemption Result:", redeemResult);
    
    // Example: Check redemption status
    // const status = await vault.checkRedemptionStatus(1);
    // console.log("Redemption Status:", status);
}

// Export for use in other modules
export default MultiBTCVaultIntegration;
export { ADDRESSES, VAULT_ABI, ERC20_ABI, QUEUE_ABI };

// Run if called directly
if (typeof window !== 'undefined') {
    window.MultiBTCVaultIntegration = MultiBTCVaultIntegration;
    window.addEventListener('load', main);
}