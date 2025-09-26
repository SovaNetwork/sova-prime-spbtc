import { ethers } from 'ethers';
import { PrismaClient } from '@prisma/client';
import { BTC_VAULT_STRATEGY_ABI } from '../abis.js';

// RPC configurations for each network
const RPC_URLS: Record<number, string> = {
  1: process.env.ETHEREUM_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/demo',
  8453: process.env.BASE_RPC_URL || 'https://base-mainnet.g.alchemy.com/v2/demo',
  42161: process.env.ARBITRUM_RPC_URL || 'https://arb-mainnet.g.alchemy.com/v2/demo',
  10: process.env.OPTIMISM_RPC_URL || 'https://opt-mainnet.g.alchemy.com/v2/demo',
  137: process.env.POLYGON_RPC_URL || 'https://polygon-mainnet.g.alchemy.com/v2/demo',
  43114: process.env.AVALANCHE_RPC_URL || 'https://api.avax.network/ext/bc/C/rpc',
  84532: process.env.BASE_SEPOLIA_RPC_URL || 'https://base-sepolia.g.alchemy.com/v2/demo',
  11155111: process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/demo',
};

// ERC20 ABI for fetching token metadata
const ERC20_ABI = [
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
];

export class BlockchainService {
  private prisma: PrismaClient;
  private providers: Map<number, ethers.JsonRpcProvider> = new Map();

  constructor(prisma?: PrismaClient) {
    this.prisma = prisma || new PrismaClient();
  }

  /**
   * Get or create a provider for the specified chain
   */
  private getProvider(chainId: number): ethers.JsonRpcProvider {
    if (!this.providers.has(chainId)) {
      const rpcUrl = RPC_URLS[chainId];
      if (!rpcUrl) {
        throw new Error(`No RPC URL configured for chain ${chainId}`);
      }
      this.providers.set(chainId, new ethers.JsonRpcProvider(rpcUrl));
    }
    return this.providers.get(chainId)!;
  }

  /**
   * Fetch supported collaterals from the strategy contract
   */
  async fetchCollateralsFromChain(chainId: number, strategyAddress: string) {
    try {
      const provider = this.getProvider(chainId);
      const strategy = new ethers.Contract(strategyAddress, BTC_VAULT_STRATEGY_ABI, provider);

      // Get the list of supported collateral addresses
      // Note: This assumes the strategy has a method to get all supported collaterals
      // You may need to adjust based on actual contract interface
      const collateralAddresses: string[] = await strategy.getSupportedCollaterals?.() || [];
      
      // If getSupportedCollaterals doesn't exist, try alternative methods
      if (collateralAddresses.length === 0) {
        // Try checking known collateral addresses
        const knownCollaterals = await this.getKnownCollateralsForChain(chainId);
        for (const address of knownCollaterals) {
          try {
            const isSupported = await strategy.isSupportedCollateral(address);
            if (isSupported) {
              collateralAddresses.push(address);
            }
          } catch (e) {
            // Skip if method doesn't exist or fails
          }
        }
      }

      // Fetch metadata for each collateral
      const collaterals = [];
      for (const address of collateralAddresses) {
        try {
          const token = new ethers.Contract(address, ERC20_ABI, provider);
          const [name, symbol, decimals] = await Promise.all([
            token.name(),
            token.symbol(),
            token.decimals(),
          ]);

          collaterals.push({
            address,
            name,
            symbol,
            decimals,
            chainId,
          });
        } catch (error) {
          console.error(`Failed to fetch metadata for token ${address}:`, error);
        }
      }

      return collaterals;
    } catch (error) {
      console.error('Failed to fetch collaterals from chain:', error);
      throw error;
    }
  }

  /**
   * Get known collateral addresses for a chain from token registry
   */
  private async getKnownCollateralsForChain(chainId: number): Promise<string[]> {
    const tokens = await this.prisma.sovaBtcTokenRegistry.findMany({
      where: {
        category: 'btc',
      },
    });

    const addresses: string[] = [];
    for (const token of tokens) {
      const tokenAddresses = token.addresses as Record<string, string>;
      if (tokenAddresses[chainId.toString()]) {
        addresses.push(tokenAddresses[chainId.toString()]);
      }
    }

    return addresses;
  }

  /**
   * Sync collaterals from blockchain to database
   */
  async syncCollateralsToDatabase(chainId: number, deploymentId: string) {
    try {
      // Get deployment info
      const deployment = await this.prisma.sovaBtcDeployment.findUnique({
        where: { id: deploymentId },
      });

      if (!deployment) {
        throw new Error(`Deployment ${deploymentId} not found`);
      }

      // Fetch collaterals from chain
      const collaterals = await this.fetchCollateralsFromChain(chainId, deployment.vaultStrategy);

      // Update database
      for (const collateral of collaterals) {
        // Check if collateral exists in token registry
        let tokenRegistry = await this.prisma.sovaBtcTokenRegistry.findUnique({
          where: { symbol: collateral.symbol },
        });

        if (!tokenRegistry) {
          // Create new token registry entry
          tokenRegistry = await this.prisma.sovaBtcTokenRegistry.create({
            data: {
              symbol: collateral.symbol,
              name: collateral.name,
              decimals: collateral.decimals,
              addresses: { [chainId.toString()]: collateral.address },
              category: 'btc',
            },
          });
        } else {
          // Update addresses if needed
          const addresses = tokenRegistry.addresses as Record<string, string>;
          if (!addresses[chainId.toString()]) {
            addresses[chainId.toString()] = collateral.address;
            await this.prisma.sovaBtcTokenRegistry.update({
              where: { id: tokenRegistry.id },
              data: { addresses },
            });
          }
        }

        // Update or create collateral entry
        await this.prisma.sovaBtcCollateral.upsert({
          where: {
            chainId_address: {
              chainId,
              address: collateral.address,
            },
          },
          update: {
            isActive: true,
            isVerified: true,
          },
          create: {
            deploymentId,
            symbol: collateral.symbol,
            name: collateral.name,
            address: collateral.address,
            chainId,
            decimals: collateral.decimals,
            isActive: true,
            isVerified: true,
          },
        });
      }

      // Log activity
      await this.prisma.sovaBtcActivity.create({
        data: {
          deploymentId,
          type: 'COLLATERAL_ADDED',
          description: `Synced ${collaterals.length} collaterals from chain ${chainId}`,
          metadata: { collaterals: collaterals.map(c => c.symbol) },
        },
      });

      return collaterals;
    } catch (error) {
      console.error('Failed to sync collaterals to database:', error);
      throw error;
    }
  }

  /**
   * Fetch real metrics from the blockchain
   */
  async fetchRealMetrics(chainId: number, deploymentId: string) {
    try {
      const deployment = await this.prisma.sovaBtcDeployment.findUnique({
        where: { id: deploymentId },
      });

      if (!deployment) {
        throw new Error(`Deployment ${deploymentId} not found`);
      }

      const provider = this.getProvider(chainId);
      
      // Get vault token contract
      const vaultToken = new ethers.Contract(
        deployment.vaultToken,
        [
          'function totalSupply() view returns (uint256)',
          'function totalAssets() view returns (uint256)',
          'function convertToAssets(uint256 shares) view returns (uint256)',
        ],
        provider
      );

      // Fetch metrics
      const [totalSupply, totalAssets] = await Promise.all([
        vaultToken.totalSupply(),
        vaultToken.totalAssets(),
      ]);

      // Calculate share price (assets per share)
      let sharePrice = ethers.parseEther('1'); // Default 1:1
      if (totalSupply > 0n) {
        sharePrice = (totalAssets * ethers.parseEther('1')) / totalSupply;
      }

      // Convert to decimal strings for database
      const metrics = {
        totalSupply: ethers.formatUnits(totalSupply, 18),
        totalAssets: ethers.formatUnits(totalAssets, 18),
        tvl: ethers.formatUnits(totalAssets, 18), // TVL = total assets
        sharePrice: ethers.formatUnits(sharePrice, 18),
      };

      // Store in database
      await this.prisma.sovaBtcDeploymentMetrics.create({
        data: {
          deploymentId,
          tvl: metrics.tvl,
          totalSupply: metrics.totalSupply,
          totalAssets: metrics.totalAssets,
          sharePrice: metrics.sharePrice,
          apy: null, // Calculate APY separately based on historical data
          users: 0, // Would need to track from events
          transactions: 0, // Would need to track from events
        },
      });

      // Update network metrics
      const blockNumber = await provider.getBlockNumber();
      const feeData = await provider.getFeeData();
      
      await this.prisma.sovaBtcNetworkMetrics.create({
        data: {
          chainId,
          blockHeight: BigInt(blockNumber),
          gasPrice: feeData.gasPrice || 0n,
          isOnline: true,
          latency: 0, // Would need to measure actual latency
        },
      });

      // Log activity
      await this.prisma.sovaBtcActivity.create({
        data: {
          deploymentId,
          type: 'METRICS_UPDATED',
          description: `Updated metrics for chain ${chainId}`,
          metadata: metrics,
        },
      });

      return metrics;
    } catch (error) {
      console.error('Failed to fetch real metrics:', error);
      
      // Mark network as potentially offline
      await this.prisma.sovaBtcNetworkMetrics.create({
        data: {
          chainId,
          blockHeight: 0n,
          gasPrice: 0n,
          isOnline: false,
          latency: null,
        },
      });

      throw error;
    }
  }

  /**
   * Initialize token registry with common BTC tokens
   */
  async initializeTokenRegistry() {
    const btcTokens = [
      {
        symbol: 'WBTC',
        name: 'Wrapped Bitcoin',
        decimals: 8,
        addresses: {
          '1': '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599', // Ethereum
          '8453': '0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3', // Base
          '42161': '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f', // Arbitrum
          '10': '0x68f180fcCe6836688e9084f035309E29Bf0A2095', // Optimism
          '137': '0x1bfd67037b42cf73acF2047067bd4F2C47D9BfD6', // Polygon
          '43114': '0x50b7545627a5162F82A992c33b87aDc75187B218', // Avalanche
        },
        category: 'btc',
        coingeckoId: 'wrapped-bitcoin',
      },
      {
        symbol: 'tBTC',
        name: 'tBTC v2',
        decimals: 18,
        addresses: {
          '1': '0x18084fbA666a33d37592fA2633fD49a74DD93a88', // Ethereum
          '8453': '0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b', // Base
          '42161': '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40', // Arbitrum
          '10': '0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40', // Optimism
          '137': '0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b', // Polygon
        },
        category: 'btc',
        coingeckoId: 'tbtc',
      },
      {
        symbol: 'BTCB',
        name: 'Bitcoin BEP2',
        decimals: 18,
        addresses: {
          '56': '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c', // BSC
        },
        category: 'btc',
        coingeckoId: 'bitcoin-bep2',
      },
      {
        symbol: 'sovaBTC',
        name: 'Sova Bitcoin',
        decimals: 18,
        addresses: {
          '84532': '0xe44b2870eFcd6Bb3C9305808012621f438e9636D', // Base Sepolia (test)
        },
        category: 'btc',
      },
    ];

    for (const token of btcTokens) {
      await this.prisma.sovaBtcTokenRegistry.upsert({
        where: { symbol: token.symbol },
        update: {
          addresses: token.addresses,
          coingeckoId: token.coingeckoId,
        },
        create: {
          symbol: token.symbol,
          name: token.name,
          decimals: token.decimals,
          addresses: token.addresses,
          category: token.category,
          coingeckoId: token.coingeckoId,
        },
      });
    }

    console.log('Token registry initialized with', btcTokens.length, 'tokens');
  }

  /**
   * Clean up providers
   */
  async disconnect() {
    for (const provider of this.providers.values()) {
      provider.destroy();
    }
    this.providers.clear();
    await this.prisma.$disconnect();
  }
}