export interface NetworkConfig {
  chainId: number;
  name: string;
  rpcUrl: string;
  blockExplorer: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
}

export interface ContractAddresses {
  btcVaultStrategy: string;
  btcVaultToken: string;
  priceOracle?: string;
}

export interface CollateralToken {
  address: string;
  decimals: number;
  name: string;
  symbol: string;
  oracleId?: string;
}

export interface DeploymentMetadata {
  timestamp: string;
  blockNumber: number;
  deployer: string;
  verified: boolean;
  transactionHash?: string;
}

export interface DeploymentMetrics {
  tvl: string;
  users: number;
  transactions: number;
  apy?: string;
  lastUpdated: string;
}

export type DeploymentStatus = 'active' | 'pending' | 'deprecated' | 'not-deployed';

export interface DeploymentInfo {
  network: NetworkConfig;
  contracts: ContractAddresses;
  collaterals: Record<string, CollateralToken>;
  deployment: DeploymentMetadata;
  status: DeploymentStatus;
  metrics?: DeploymentMetrics;
}

export class DeploymentRegistry {
  private deployments: Map<number, DeploymentInfo>;
  private storageKey = 'sova-btc-deployments';

  constructor() {
    this.deployments = new Map();
    this.loadDeployments();
  }

  private loadDeployments(): void {
    if (typeof window === 'undefined') return;
    
    try {
      const stored = localStorage.getItem(this.storageKey);
      if (stored) {
        const data = JSON.parse(stored) as Record<string, DeploymentInfo>;
        Object.entries(data).forEach(([chainId, info]) => {
          this.deployments.set(Number(chainId), info);
        });
      }
    } catch (error) {
      console.error('Failed to load deployments:', error);
    }

    // Load default deployments if empty
    if (this.deployments.size === 0) {
      this.loadDefaultDeployments();
    }
  }

  private loadDefaultDeployments(): void {
    // Base Sepolia deployment
    const baseSepolia: DeploymentInfo = {
      network: {
        chainId: 84532,
        name: 'Base Sepolia',
        rpcUrl: 'https://sepolia.base.org',
        blockExplorer: 'https://sepolia.basescan.org',
        nativeCurrency: {
          name: 'ETH',
          symbol: 'ETH',
          decimals: 18,
        },
      },
      contracts: {
        btcVaultStrategy: '0x0A039085Ca2AD68a3FC77A9C5191C22B309126F8',
        btcVaultToken: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
        priceOracle: '0x698FBBde2c9FF3aF64C0ec48f174d5e8231FAacF',
      },
      collaterals: {
        WBTC: {
          address: '0xe44b2870eFcd6Bb3C9305808012621f438e9636D',
          decimals: 8,
          name: 'Wrapped Bitcoin',
          symbol: 'WBTC',
        },
        sovaBTC: {
          address: '0xfF09B2B0AfEe51E29941091C4dd6B635780BC34a',
          decimals: 8,
          name: 'Sova Bitcoin',
          symbol: 'sovaBTC',
        },
      },
      deployment: {
        timestamp: '2024-12-10T00:00:00Z',
        blockNumber: 1000000,
        deployer: '0x0000000000000000000000000000000000000000',
        verified: true,
      },
      status: 'active',
    };

    this.deployments.set(84532, baseSepolia);
    this.saveDeployments();
  }

  private saveDeployments(): void {
    if (typeof window === 'undefined') return;
    
    try {
      const data: Record<string, DeploymentInfo> = {};
      this.deployments.forEach((info, chainId) => {
        data[chainId.toString()] = info;
      });
      localStorage.setItem(this.storageKey, JSON.stringify(data));
    } catch (error) {
      console.error('Failed to save deployments:', error);
    }
  }

  addDeployment(chainId: number, info: DeploymentInfo): void {
    this.deployments.set(chainId, info);
    this.saveDeployments();
  }

  updateDeployment(chainId: number, updates: Partial<DeploymentInfo>): void {
    const existing = this.deployments.get(chainId);
    if (existing) {
      const updated = {
        ...existing,
        ...updates,
        network: { ...existing.network, ...(updates.network || {}) },
        contracts: { ...existing.contracts, ...(updates.contracts || {}) },
        collaterals: { ...existing.collaterals, ...(updates.collaterals || {}) },
        deployment: { ...existing.deployment, ...(updates.deployment || {}) },
        metrics: updates.metrics ? { ...existing.metrics, ...updates.metrics } : existing.metrics,
      };
      this.deployments.set(chainId, updated);
      this.saveDeployments();
    }
  }

  removeDeployment(chainId: number): void {
    this.deployments.delete(chainId);
    this.saveDeployments();
  }

  getDeployment(chainId: number): DeploymentInfo | null {
    return this.deployments.get(chainId) || null;
  }

  getAllDeployments(): DeploymentInfo[] {
    return Array.from(this.deployments.values());
  }

  getActiveDeployments(): DeploymentInfo[] {
    return this.getAllDeployments().filter(d => d.status === 'active');
  }

  hasDeployment(chainId: number): boolean {
    return this.deployments.has(chainId);
  }

  exportConfig(): string {
    const data: Record<string, DeploymentInfo> = {};
    this.deployments.forEach((info, chainId) => {
      data[chainId.toString()] = info;
    });
    return JSON.stringify(data, null, 2);
  }

  importConfig(json: string): void {
    try {
      const data = JSON.parse(json) as Record<string, DeploymentInfo>;
      Object.entries(data).forEach(([chainId, info]) => {
        this.deployments.set(Number(chainId), info);
      });
      this.saveDeployments();
    } catch (error) {
      throw new Error(`Failed to import config: ${error}`);
    }
  }

  clearAll(): void {
    this.deployments.clear();
    this.saveDeployments();
  }
}