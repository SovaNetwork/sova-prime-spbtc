import { DeploymentStatus as PrismaDeploymentStatus } from '@prisma/client';

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

// Convert between Prisma and frontend status types
function convertStatus(prismaStatus: PrismaDeploymentStatus): DeploymentStatus {
  switch (prismaStatus) {
    case 'ACTIVE':
      return 'active';
    case 'PENDING':
      return 'pending';
    case 'DEPRECATED':
      return 'deprecated';
    case 'NOT_DEPLOYED':
    default:
      return 'not-deployed';
  }
}

function convertToPrismaStatus(status: DeploymentStatus): PrismaDeploymentStatus {
  switch (status) {
    case 'active':
      return 'ACTIVE';
    case 'pending':
      return 'PENDING';
    case 'deprecated':
      return 'DEPRECATED';
    case 'not-deployed':
    default:
      return 'NOT_DEPLOYED';
  }
}

export class DeploymentRegistryAPI {
  private cache: Map<number, DeploymentInfo>;
  private cacheTimestamp: number = 0;
  private readonly cacheTimeout = 60000; // 1 minute cache

  constructor() {
    this.cache = new Map();
  }

  private async fetchFromAPI(): Promise<void> {
    try {
      const response = await fetch('/api/deployments');
      if (!response.ok) throw new Error('Failed to fetch deployments');
      
      const deployments = await response.json();
      
      // Clear and rebuild cache
      this.cache.clear();
      
      for (const deployment of deployments) {
        const info = this.convertFromPrisma(deployment);
        this.cache.set(deployment.chainId, info);
      }
      
      this.cacheTimestamp = Date.now();
    } catch (error) {
      console.error('Failed to fetch deployments from API:', error);
      // Fall back to localStorage if API fails
      this.loadFromLocalStorage();
    }
  }

  private convertFromPrisma(deployment: any): DeploymentInfo {
    const latestMetrics = deployment.metrics?.[0];
    
    return {
      network: {
        chainId: deployment.chainId,
        name: deployment.network.name,
        rpcUrl: deployment.network.rpcUrl,
        blockExplorer: deployment.network.blockExplorer,
        nativeCurrency: deployment.network.nativeCurrency as any,
      },
      contracts: {
        btcVaultStrategy: deployment.vaultStrategy,
        btcVaultToken: deployment.vaultToken,
        priceOracle: deployment.priceOracle || undefined,
      },
      collaterals: deployment.collaterals.reduce((acc: any, col: any) => {
        acc[col.symbol] = {
          address: col.address,
          decimals: col.decimals,
          name: col.name,
          symbol: col.symbol,
          oracleId: col.oracleId || undefined,
        };
        return acc;
      }, {}),
      deployment: {
        timestamp: deployment.createdAt,
        blockNumber: deployment.blockNumber || 0,
        deployer: deployment.deployer || '0x0000000000000000000000000000000000000000',
        verified: deployment.verified,
        transactionHash: deployment.transactionHash || undefined,
      },
      status: convertStatus(deployment.status),
      metrics: latestMetrics ? {
        tvl: latestMetrics.tvl.toString(),
        users: latestMetrics.users,
        transactions: latestMetrics.transactions,
        apy: latestMetrics.apy?.toString(),
        lastUpdated: latestMetrics.timestamp,
      } : undefined,
    };
  }

  private loadFromLocalStorage(): void {
    if (typeof window === 'undefined') return;
    
    try {
      const stored = localStorage.getItem('sova-btc-deployments');
      if (stored) {
        const data = JSON.parse(stored) as Record<string, DeploymentInfo>;
        Object.entries(data).forEach(([chainId, info]) => {
          this.cache.set(Number(chainId), info);
        });
      }
    } catch (error) {
      console.error('Failed to load from localStorage:', error);
    }
  }

  private async ensureCacheValid(): Promise<void> {
    if (Date.now() - this.cacheTimestamp > this.cacheTimeout || this.cache.size === 0) {
      await this.fetchFromAPI();
    }
  }

  async loadDeployments(): Promise<void> {
    await this.fetchFromAPI();
  }

  async addDeployment(chainId: number, info: DeploymentInfo): Promise<void> {
    try {
      const response = await fetch('/api/deployments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chainId,
          vaultStrategy: info.contracts.btcVaultStrategy,
          vaultToken: info.contracts.btcVaultToken,
          priceOracle: info.contracts.priceOracle,
          status: convertToPrismaStatus(info.status),
          deployer: info.deployment.deployer,
          blockNumber: info.deployment.blockNumber,
          transactionHash: info.deployment.transactionHash,
          verified: info.deployment.verified,
          network: info.network,
          collaterals: Object.values(info.collaterals),
        }),
      });

      if (!response.ok) throw new Error('Failed to add deployment');
      
      // Update cache
      this.cache.set(chainId, info);
      
      // Also save to localStorage as backup
      this.saveToLocalStorage();
    } catch (error) {
      console.error('Failed to add deployment:', error);
      throw error;
    }
  }

  async updateDeployment(chainId: number, updates: Partial<DeploymentInfo>): Promise<void> {
    try {
      const existing = await this.getDeployment(chainId);
      if (!existing) throw new Error('Deployment not found');

      const updated = {
        ...existing,
        ...updates,
        network: { ...existing.network, ...(updates.network || {}) },
        contracts: { ...existing.contracts, ...(updates.contracts || {}) },
        collaterals: { ...existing.collaterals, ...(updates.collaterals || {}) },
        deployment: { ...existing.deployment, ...(updates.deployment || {}) },
        metrics: updates.metrics ? { ...existing.metrics, ...updates.metrics } : existing.metrics,
      };

      const response = await fetch(`/api/deployments/${chainId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          vaultStrategy: updated.contracts.btcVaultStrategy,
          vaultToken: updated.contracts.btcVaultToken,
          priceOracle: updated.contracts.priceOracle,
          status: convertToPrismaStatus(updated.status),
          deployer: updated.deployment.deployer,
          blockNumber: updated.deployment.blockNumber,
          transactionHash: updated.deployment.transactionHash,
          verified: updated.deployment.verified,
          collaterals: Object.values(updated.collaterals),
        }),
      });

      if (!response.ok) throw new Error('Failed to update deployment');
      
      // Update cache
      this.cache.set(chainId, updated);
      
      // Also save to localStorage as backup
      this.saveToLocalStorage();
    } catch (error) {
      console.error('Failed to update deployment:', error);
      throw error;
    }
  }

  async removeDeployment(chainId: number): Promise<void> {
    try {
      const response = await fetch(`/api/deployments/${chainId}`, {
        method: 'DELETE',
      });

      if (!response.ok) throw new Error('Failed to remove deployment');
      
      // Update cache
      this.cache.delete(chainId);
      
      // Also save to localStorage as backup
      this.saveToLocalStorage();
    } catch (error) {
      console.error('Failed to remove deployment:', error);
      throw error;
    }
  }

  async getDeployment(chainId: number): Promise<DeploymentInfo | null> {
    await this.ensureCacheValid();
    return this.cache.get(chainId) || null;
  }

  async getAllDeployments(): Promise<DeploymentInfo[]> {
    await this.ensureCacheValid();
    return Array.from(this.cache.values());
  }

  async getActiveDeployments(): Promise<DeploymentInfo[]> {
    const all = await this.getAllDeployments();
    return all.filter(d => d.status === 'active');
  }

  async hasDeployment(chainId: number): Promise<boolean> {
    await this.ensureCacheValid();
    return this.cache.has(chainId);
  }

  async collectMetrics(chainId: number): Promise<void> {
    try {
      const response = await fetch('/api/metrics/collect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ chainId }),
      });

      if (!response.ok) throw new Error('Failed to collect metrics');
      
      // Refresh cache to get updated metrics
      await this.fetchFromAPI();
    } catch (error) {
      console.error('Failed to collect metrics:', error);
      throw error;
    }
  }

  private saveToLocalStorage(): void {
    if (typeof window === 'undefined') return;
    
    try {
      const data: Record<string, DeploymentInfo> = {};
      this.cache.forEach((info, chainId) => {
        data[chainId.toString()] = info;
      });
      localStorage.setItem('sova-btc-deployments', JSON.stringify(data));
    } catch (error) {
      console.error('Failed to save to localStorage:', error);
    }
  }

  exportConfig(): string {
    const data: Record<string, DeploymentInfo> = {};
    this.cache.forEach((info, chainId) => {
      data[chainId.toString()] = info;
    });
    return JSON.stringify(data, null, 2);
  }

  async importConfig(json: string): Promise<void> {
    try {
      const data = JSON.parse(json) as Record<string, DeploymentInfo>;
      
      // Add each deployment via API
      for (const [chainId, info] of Object.entries(data)) {
        await this.addDeployment(Number(chainId), info);
      }
      
      // Refresh cache
      await this.fetchFromAPI();
    } catch (error) {
      throw new Error(`Failed to import config: ${error}`);
    }
  }

  async clearAll(): Promise<void> {
    const deployments = await this.getAllDeployments();
    
    // Delete each deployment via API
    for (const deployment of deployments) {
      await this.removeDeployment(deployment.network.chainId);
    }
    
    // Clear cache and localStorage
    this.cache.clear();
    if (typeof window !== 'undefined') {
      localStorage.removeItem('sova-btc-deployments');
    }
  }
}

// Export singleton instance
export const deploymentRegistry = new DeploymentRegistryAPI();