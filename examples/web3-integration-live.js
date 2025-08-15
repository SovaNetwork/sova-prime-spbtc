const { ethers } = require('ethers');

// Live Base Sepolia Contract Addresses
const CONTRACTS = {
    vault: "0x73E27097221d4d9D5893a83350dC7A967b46fab7",
    queue: "0x22BC73098CE1Ba2CaE5431fb32051cB4fc0F9C52",
    registry: "0x15a9983784617aa8892b2677bbaEc23539482B65",
    strategy: "0x740907524EbD6A481a81cE76B5115A4cDDb80099",
    priceOracle: "0xDB4479A2360E118CCbD99B88e82522813BDE48f5",
    roleManager: "0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72",
    // Token addresses
    wbtc: "0xe44b2870eFcd6Bb3C9305808012621f438e9636D",
    tbtc: "0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802",
    sovaBTC: "0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9"
};

// ABIs (simplified for key functions)
const VAULT_ABI = [
    "function deposit(address asset, uint256 assets, address receiver) returns (uint256 shares)",
    "function requestRedemption(uint256 shares) returns (uint256 requestId)",
    "function totalAssets() view returns (uint256)",
    "function totalSupply() view returns (uint256)",
    "function balanceOf(address account) view returns (uint256)",
    "function sharePrice() view returns (uint256)"
];

const QUEUE_ABI = [
    "function claimRedemption(uint256 requestId)",
    "function getRedemptionRequest(uint256 requestId) view returns (tuple(address user, uint256 shares, uint256 requestedAt, bool processed, bool claimed, uint256 redeemableAmount))",
    "function getUserRequests(address user) view returns (uint256[])",
    "function getTotalPendingShares() view returns (uint256)"
];

const ERC20_ABI = [
    "function balanceOf(address account) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)",
    "function mint(uint256 amount)",
    "function decimals() view returns (uint8)",
    "function symbol() view returns (string)"
];

class MultiBTCVaultClient {
    constructor(provider, signer) {
        this.provider = provider;
        this.signer = signer || provider;
        
        // Initialize contract instances
        this.vault = new ethers.Contract(CONTRACTS.vault, VAULT_ABI, this.signer);
        this.queue = new ethers.Contract(CONTRACTS.queue, QUEUE_ABI, this.signer);
        
        // Initialize token contracts
        this.tokens = {
            wbtc: new ethers.Contract(CONTRACTS.wbtc, ERC20_ABI, this.signer),
            tbtc: new ethers.Contract(CONTRACTS.tbtc, ERC20_ABI, this.signer),
            sovaBTC: new ethers.Contract(CONTRACTS.sovaBTC, ERC20_ABI, this.signer)
        };
    }
    
    // Connect wallet
    static async connectWallet() {
        if (typeof window !== 'undefined' && window.ethereum) {
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            const provider = new ethers.BrowserProvider(window.ethereum);
            const signer = await provider.getSigner();
            return new MultiBTCVaultClient(provider, signer);
        } else {
            throw new Error('No wallet detected');
        }
    }
    
    // Connect with private key (for scripts)
    static connectWithPrivateKey(privateKey, rpcUrl) {
        const provider = new ethers.JsonRpcProvider(rpcUrl);
        const signer = new ethers.Wallet(privateKey, provider);
        return new MultiBTCVaultClient(provider, signer);
    }
    
    // Get vault statistics
    async getVaultStats() {
        const [totalAssets, totalSupply, sharePrice] = await Promise.all([
            this.vault.totalAssets(),
            this.vault.totalSupply(),
            this.vault.sharePrice()
        ]);
        
        return {
            tvl: ethers.formatUnits(totalAssets, 8), // BTC has 8 decimals
            totalShares: ethers.formatEther(totalSupply),
            sharePrice: ethers.formatEther(sharePrice)
        };
    }
    
    // Get user position
    async getUserPosition(address) {
        const userAddress = address || await this.signer.getAddress();
        const balance = await this.vault.balanceOf(userAddress);
        const sharePrice = await this.vault.sharePrice();
        
        const shares = ethers.formatEther(balance);
        const value = parseFloat(shares) * parseFloat(ethers.formatEther(sharePrice));
        
        return {
            shares,
            value: value.toFixed(8),
            address: userAddress
        };
    }
    
    // Deposit collateral
    async depositCollateral(tokenSymbol, amount) {
        const token = this.tokens[tokenSymbol.toLowerCase()];
        if (!token) throw new Error(`Invalid token: ${tokenSymbol}`);
        
        const decimals = await token.decimals();
        const amountWei = ethers.parseUnits(amount.toString(), decimals);
        
        // Check allowance
        const userAddress = await this.signer.getAddress();
        const allowance = await token.allowance(userAddress, CONTRACTS.vault);
        
        // Approve if needed
        if (allowance < amountWei) {
            console.log('Approving tokens...');
            const approveTx = await token.approve(CONTRACTS.vault, amountWei);
            await approveTx.wait();
            console.log('Approval confirmed');
        }
        
        // Deposit
        console.log(`Depositing ${amount} ${tokenSymbol}...`);
        const depositTx = await this.vault.deposit(
            token.target || token.address,
            amountWei,
            userAddress
        );
        
        const receipt = await depositTx.wait();
        console.log('Deposit confirmed:', receipt.hash);
        
        return receipt;
    }
    
    // Request redemption
    async requestRedemption(shares) {
        const sharesWei = ethers.parseEther(shares.toString());
        
        console.log(`Requesting redemption of ${shares} mcBTC...`);
        const tx = await this.vault.requestRedemption(sharesWei);
        const receipt = await tx.wait();
        
        // Parse request ID from events
        const event = receipt.logs.find(log => 
            log.topics[0] === ethers.id("RedemptionRequested(uint256,address,uint256)")
        );
        
        const requestId = event ? ethers.toBigInt(event.topics[1]) : null;
        
        console.log('Redemption requested. Request ID:', requestId?.toString());
        return { receipt, requestId };
    }
    
    // Check redemption status
    async checkRedemptionStatus(requestId) {
        const request = await this.queue.getRedemptionRequest(requestId);
        
        return {
            user: request[0],
            shares: ethers.formatEther(request[1]),
            requestedAt: new Date(Number(request[2]) * 1000),
            processed: request[3],
            claimed: request[4],
            redeemableAmount: ethers.formatUnits(request[5], 8) // sovaBTC has 8 decimals
        };
    }
    
    // Get user's redemption requests
    async getUserRequests(address) {
        const userAddress = address || await this.signer.getAddress();
        const requestIds = await this.queue.getUserRequests(userAddress);
        
        const requests = [];
        for (const id of requestIds) {
            const status = await this.checkRedemptionStatus(id);
            requests.push({ id: id.toString(), ...status });
        }
        
        return requests;
    }
    
    // Claim redemption
    async claimRedemption(requestId) {
        console.log(`Claiming redemption ${requestId}...`);
        const tx = await this.queue.claimRedemption(requestId);
        const receipt = await tx.wait();
        
        console.log('Redemption claimed:', receipt.hash);
        return receipt;
    }
    
    // Mint test tokens (testnet only)
    async mintTestTokens(tokenSymbol, amount) {
        const token = this.tokens[tokenSymbol.toLowerCase()];
        if (!token) throw new Error(`Invalid token: ${tokenSymbol}`);
        
        const decimals = await token.decimals();
        const amountWei = ethers.parseUnits(amount.toString(), decimals);
        
        console.log(`Minting ${amount} ${tokenSymbol}...`);
        const tx = await token.mint(amountWei);
        const receipt = await tx.wait();
        
        console.log('Tokens minted:', receipt.hash);
        return receipt;
    }
    
    // Get token balances
    async getTokenBalances(address) {
        const userAddress = address || await this.signer.getAddress();
        const balances = {};
        
        for (const [symbol, token] of Object.entries(this.tokens)) {
            const balance = await token.balanceOf(userAddress);
            const decimals = await token.decimals();
            balances[symbol] = ethers.formatUnits(balance, decimals);
        }
        
        return balances;
    }
}

// Example usage
async function main() {
    // Connect to Base Sepolia
    const RPC_URL = "https://base-sepolia.g.alchemy.com/v2/e7qIcHOK60Sc4-hvyWA68";
    const PRIVATE_KEY = "your_private_key_here"; // Replace with your key
    
    const client = MultiBTCVaultClient.connectWithPrivateKey(PRIVATE_KEY, RPC_URL);
    
    try {
        // Get vault stats
        console.log('\n=== Vault Statistics ===');
        const stats = await client.getVaultStats();
        console.log('TVL:', stats.tvl, 'BTC');
        console.log('Total Shares:', stats.totalShares, 'mcBTC');
        console.log('Share Price:', stats.sharePrice, 'BTC/mcBTC');
        
        // Get user position
        console.log('\n=== User Position ===');
        const position = await client.getUserPosition();
        console.log('Your Shares:', position.shares, 'mcBTC');
        console.log('Value:', position.value, 'BTC');
        
        // Get token balances
        console.log('\n=== Token Balances ===');
        const balances = await client.getTokenBalances();
        console.log('WBTC:', balances.wbtc);
        console.log('TBTC:', balances.tbtc);
        console.log('sovaBTC:', balances.sovaBTC);
        
        // Example: Mint and deposit
        // await client.mintTestTokens('wbtc', '0.01');
        // await client.depositCollateral('wbtc', '0.01');
        
        // Example: Request redemption
        // const { requestId } = await client.requestRedemption('0.005');
        // const status = await client.checkRedemptionStatus(requestId);
        // console.log('Redemption Status:', status);
        
    } catch (error) {
        console.error('Error:', error);
    }
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { MultiBTCVaultClient, CONTRACTS };
}

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}