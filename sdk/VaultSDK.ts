import { ethers, Contract, Signer, Provider, ContractTransaction, BigNumberish } from 'ethers';

export interface VaultStats {
  tvl: string;
  totalShares: string;
  sharePrice: string;
}

export interface UserPosition {
  shares: string;
  value: string;
  address: string;
}

export interface RedemptionRequest {
  id?: string;
  user: string;
  shares: string;
  requestedAt: Date;
  processed: boolean;
  claimed: boolean;
  redeemableAmount: string;
}

export interface TokenBalances {
  wbtc: string;
  tbtc: string;
  sovaBTC: string;
}

export enum CollateralToken {
  WBTC = 'wbtc',
  TBTC = 'tbtc',
  SOVABTC = 'sovaBTC'
}

export interface ContractAddresses {
  vault: string;
  strategy: string;
  roleManager: string;
  wbtc: string;
  tbtc: string;
  sovaBTC: string;
}

// Base Sepolia addresses - deployed on 2025-08-12
export const BASE_SEPOLIA_ADDRESSES: ContractAddresses = {
  vault: "0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a", // BtcVaultToken address (deployed)
  strategy: "0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8", // BtcVaultStrategy address (deployed)
  roleManager: "0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72",
  wbtc: "0xe44b2870eFcd6Bb3C9305808012621f438e9636D",
  tbtc: "0xE2b47f0dD766834b9DD2612D2d3632B05Ca89802",
  sovaBTC: "0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9"
};

// Updated ABIs for new architecture
const VAULT_ABI = [
  // BtcVaultToken (ERC4626 + custom)
  "function depositCollateral(address token, uint256 amount, address receiver) returns (uint256 shares)",
  "function previewDepositCollateral(address token, uint256 amount) view returns (uint256)",
  "function requestWithdraw(uint256 assets, address receiver, address owner) returns (uint256 requestId)",
  "function totalAssets() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function convertToAssets(uint256 shares) view returns (uint256)",
  "function convertToShares(uint256 assets) view returns (uint256)",
  "function pause()",
  "function unpause()",
  "function paused() view returns (bool)",
  "event CollateralDeposited(address indexed depositor, address indexed token, uint256 amount, uint256 shares, address indexed receiver)"
];

const STRATEGY_ABI = [
  // BtcVaultStrategy
  "function addCollateral(address token, uint8 decimals)",
  "function removeCollateral(address token)",
  "function isSupportedAsset(address token) view returns (bool)",
  "function getSupportedCollaterals() view returns (address[])",
  "function addLiquidity(uint256 amount)",
  "function removeLiquidity(uint256 amount, address to)",
  "function rebalanceCollateral(address fromToken, address toToken, uint256 amount)",
  "function totalAssets() view returns (uint256)",
  "function collateralBalance(address token) view returns (uint256)",
  "function availableLiquidity() view returns (uint256)",
  "function approveWithdrawal(uint256 requestId)",
  "function rejectWithdrawal(uint256 requestId)",
  "function processWithdrawals(uint256[] calldata requestIds)",
  "function withdrawCollateral(address token, uint256 amount, address to)"
];

const ERC20_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function mint(uint256 amount)",
  "function decimals() view returns (uint8)",
  "function symbol() view returns (string)"
];

export class BtcVaultSDK {
  private provider: Provider;
  private signer?: Signer;
  private vaultToken: Contract;
  private strategy: Contract;
  private tokens: Record<CollateralToken, Contract>;
  private addresses: ContractAddresses;

  constructor(
    provider: Provider,
    signer?: Signer,
    addresses: ContractAddresses = BASE_SEPOLIA_ADDRESSES
  ) {
    this.provider = provider;
    this.signer = signer;
    this.addresses = addresses;
    
    const signerOrProvider = signer || provider;
    
    // Initialize contracts - now using vaultToken and strategy
    this.vaultToken = new Contract(addresses.vault, VAULT_ABI, signerOrProvider);
    this.strategy = new Contract(addresses.strategy, STRATEGY_ABI, signerOrProvider);
    
    // Initialize token contracts
    this.tokens = {
      [CollateralToken.WBTC]: new Contract(addresses.wbtc, ERC20_ABI, signerOrProvider),
      [CollateralToken.TBTC]: new Contract(addresses.tbtc, ERC20_ABI, signerOrProvider),
      [CollateralToken.SOVABTC]: new Contract(addresses.sovaBTC, ERC20_ABI, signerOrProvider)
    };
  }

  // Static factory methods
  static async connectWallet(
    addresses: ContractAddresses = BASE_SEPOLIA_ADDRESSES
  ): Promise<BtcVaultSDK> {
    if (typeof window === 'undefined' || !window.ethereum) {
      throw new Error('No wallet detected. Please install MetaMask.');
    }
    
    await window.ethereum.request({ method: 'eth_requestAccounts' });
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    
    return new BtcVaultSDK(provider, signer, addresses);
  }

  static connectWithPrivateKey(
    privateKey: string,
    rpcUrl: string,
    addresses: ContractAddresses = BASE_SEPOLIA_ADDRESSES
  ): BtcVaultSDK {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const signer = new ethers.Wallet(privateKey, provider);
    
    return new BtcVaultSDK(provider, signer, addresses);
  }

  static readOnly(
    rpcUrl: string,
    addresses: ContractAddresses = BASE_SEPOLIA_ADDRESSES
  ): BtcVaultSDK {
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    return new BtcVaultSDK(provider, undefined, addresses);
  }

  // Core vault functions
  async getVaultStats(): Promise<VaultStats> {
    const [totalAssets, totalSupply] = await Promise.all([
      this.vaultToken.totalAssets(),
      this.vaultToken.totalSupply()
    ]);
    
    // Calculate share price manually
    const sharePrice = totalSupply > 0n 
      ? (totalAssets * ethers.parseEther("1")) / totalSupply 
      : ethers.parseEther("1");
    
    return {
      tvl: ethers.formatUnits(totalAssets, 8),
      totalShares: ethers.formatEther(totalSupply),
      sharePrice: ethers.formatUnits(sharePrice, 8)
    };
  }

  async getUserPosition(address?: string): Promise<UserPosition> {
    const userAddress = address || await this.requireSigner().getAddress();
    const balance = await this.vaultToken.balanceOf(userAddress);
    const assets = await this.vaultToken.convertToAssets(balance);
    
    return {
      shares: ethers.formatEther(balance),
      value: ethers.formatUnits(assets, 8),
      address: userAddress
    };
  }

  async depositCollateral(
    token: CollateralToken,
    amount: string | number
  ): Promise<ContractTransaction> {
    this.requireSigner();
    
    const tokenContract = this.tokens[token];
    const tokenAddress = await tokenContract.getAddress();
    const decimals = await tokenContract.decimals();
    const amountWei = ethers.parseUnits(amount.toString(), decimals);
    
    // Check and approve if needed
    const userAddress = await this.signer!.getAddress();
    const allowance = await tokenContract.allowance(userAddress, this.addresses.vault);
    
    if (allowance < amountWei) {
      const approveTx = await tokenContract.approve(this.addresses.vault, amountWei);
      await approveTx.wait();
    }
    
    // Deposit collateral
    return await this.vaultToken.depositCollateral(tokenAddress, amountWei, userAddress);
  }

  async previewDepositCollateral(
    token: CollateralToken,
    amount: string | number
  ): Promise<string> {
    const tokenContract = this.tokens[token];
    const tokenAddress = await tokenContract.getAddress();
    const decimals = await tokenContract.decimals();
    const amountWei = ethers.parseUnits(amount.toString(), decimals);
    
    const shares = await this.vaultToken.previewDepositCollateral(tokenAddress, amountWei);
    return ethers.formatEther(shares);
  }

  async requestWithdrawal(assets: string | number): Promise<{
    tx: ContractTransaction;
    requestId?: bigint;
  }> {
    this.requireSigner();
    
    const assetsWei = ethers.parseUnits(assets.toString(), 8); // sovaBTC has 8 decimals
    const userAddress = await this.signer!.getAddress();
    const tx = await this.vaultToken.requestWithdraw(assetsWei, userAddress, userAddress);
    
    // Wait for transaction and get requestId from return value or events
    const receipt = await tx.wait();
    // Note: requestId handling will depend on actual event structure
    
    return { tx };
  }

  // Strategy management functions (admin only)
  async getSupportedCollaterals(): Promise<address[]> {
    return await this.strategy.getSupportedCollaterals();
  }

  async isSupportedAsset(token: CollateralToken): Promise<boolean> {
    const tokenContract = this.tokens[token];
    const tokenAddress = await tokenContract.getAddress();
    return await this.strategy.isSupportedAsset(tokenAddress);
  }

  async getCollateralBalance(token: CollateralToken): Promise<string> {
    const tokenContract = this.tokens[token];
    const tokenAddress = await tokenContract.getAddress();
    const balance = await this.strategy.collateralBalance(tokenAddress);
    const decimals = await tokenContract.decimals();
    return ethers.formatUnits(balance, decimals);
  }

  async getAvailableLiquidity(): Promise<string> {
    const liquidity = await this.strategy.availableLiquidity();
    return ethers.formatUnits(liquidity, 8); // sovaBTC has 8 decimals
  }

  // Admin functions
  async addCollateral(token: CollateralToken): Promise<ContractTransaction> {
    this.requireSigner();
    const tokenContract = this.tokens[token];
    const tokenAddress = await tokenContract.getAddress();
    const decimals = await tokenContract.decimals();
    return await this.strategy.addCollateral(tokenAddress, decimals);
  }

  async addLiquidity(amount: string | number): Promise<ContractTransaction> {
    this.requireSigner();
    const amountWei = ethers.parseUnits(amount.toString(), 8);
    
    // Approve sovaBTC transfer
    const sovaBTCContract = this.tokens[CollateralToken.SOVABTC];
    const userAddress = await this.signer!.getAddress();
    const allowance = await sovaBTCContract.allowance(userAddress, this.addresses.strategy);
    
    if (allowance < amountWei) {
      const approveTx = await sovaBTCContract.approve(this.addresses.strategy, amountWei);
      await approveTx.wait();
    }
    
    return await this.strategy.addLiquidity(amountWei);
  }

  async processWithdrawals(requestIds: BigNumberish[]): Promise<ContractTransaction> {
    this.requireSigner();
    return await this.strategy.processWithdrawals(requestIds);
  }

  async approveWithdrawal(requestId: BigNumberish): Promise<ContractTransaction> {
    this.requireSigner();
    return await this.strategy.approveWithdrawal(requestId);
  }

  async rejectWithdrawal(requestId: BigNumberish): Promise<ContractTransaction> {
    this.requireSigner();
    return await this.strategy.rejectWithdrawal(requestId);
  }

  // Token functions
  async getTokenBalances(address?: string): Promise<TokenBalances> {
    const userAddress = address || await this.requireSigner().getAddress();
    const balances: TokenBalances = { wbtc: '0', tbtc: '0', sovaBTC: '0' };
    
    for (const [token, contract] of Object.entries(this.tokens)) {
      const balance = await contract.balanceOf(userAddress);
      const decimals = await contract.decimals();
      balances[token as keyof TokenBalances] = ethers.formatUnits(balance, decimals);
    }
    
    return balances;
  }

  async mintTestTokens(
    token: CollateralToken,
    amount: string | number
  ): Promise<ContractTransaction> {
    this.requireSigner();
    
    const tokenContract = this.tokens[token];
    const decimals = await tokenContract.decimals();
    const amountWei = ethers.parseUnits(amount.toString(), decimals);
    
    return await tokenContract.mint(amountWei);
  }


  // Helper methods
  private requireSigner(): Signer {
    if (!this.signer) {
      throw new Error('Signer required for this operation. Please connect a wallet.');
    }
    return this.signer;
  }

  getSigner(): Signer | undefined {
    return this.signer;
  }

  getProvider(): Provider {
    return this.provider;
  }

  getAddresses(): ContractAddresses {
    return this.addresses;
  }
}

// Export default RPC URL for Base Sepolia
export const BASE_SEPOLIA_RPC = "https://base-sepolia.g.alchemy.com/v2/e7qIcHOK60Sc4-hvyWA68";

// Convenience function for quick setup
export async function createVaultSDK(
  privateKeyOrConnect: string | 'wallet',
  rpcUrl: string = BASE_SEPOLIA_RPC
): Promise<BtcVaultSDK> {
  if (privateKeyOrConnect === 'wallet') {
    return BtcVaultSDK.connectWallet();
  } else {
    return BtcVaultSDK.connectWithPrivateKey(privateKeyOrConnect, rpcUrl);
  }
}