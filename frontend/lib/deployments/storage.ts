import { DeploymentInfo } from './registry';

export interface StorageAdapter {
  save(deployments: DeploymentInfo[]): Promise<void>;
  load(): Promise<DeploymentInfo[]>;
  clear(): Promise<void>;
}

// Local Storage Adapter
export class LocalStorageAdapter implements StorageAdapter {
  private key: string;

  constructor(key = 'sova-btc-deployments') {
    this.key = key;
  }

  async save(deployments: DeploymentInfo[]): Promise<void> {
    if (typeof window === 'undefined') return;
    
    const data: Record<string, DeploymentInfo> = {};
    deployments.forEach(info => {
      data[info.network.chainId.toString()] = info;
    });
    
    localStorage.setItem(this.key, JSON.stringify(data));
  }

  async load(): Promise<DeploymentInfo[]> {
    if (typeof window === 'undefined') return [];
    
    try {
      const stored = localStorage.getItem(this.key);
      if (!stored) return [];
      
      const data = JSON.parse(stored) as Record<string, DeploymentInfo>;
      return Object.values(data);
    } catch (error) {
      console.error('Failed to load from localStorage:', error);
      return [];
    }
  }

  async clear(): Promise<void> {
    if (typeof window === 'undefined') return;
    localStorage.removeItem(this.key);
  }
}

// API Storage Adapter (for production)
export class ApiStorageAdapter implements StorageAdapter {
  private apiUrl: string;
  private apiKey?: string;

  constructor(apiUrl: string, apiKey?: string) {
    this.apiUrl = apiUrl;
    this.apiKey = apiKey;
  }

  async save(deployments: DeploymentInfo[]): Promise<void> {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };
    
    if (this.apiKey) {
      headers['Authorization'] = `Bearer ${this.apiKey}`;
    }

    const response = await fetch(`${this.apiUrl}/deployments`, {
      method: 'POST',
      headers,
      body: JSON.stringify(deployments),
    });

    if (!response.ok) {
      throw new Error(`Failed to save deployments: ${response.statusText}`);
    }
  }

  async load(): Promise<DeploymentInfo[]> {
    const headers: HeadersInit = {};
    
    if (this.apiKey) {
      headers['Authorization'] = `Bearer ${this.apiKey}`;
    }

    const response = await fetch(`${this.apiUrl}/deployments`, {
      method: 'GET',
      headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to load deployments: ${response.statusText}`);
    }

    return response.json();
  }

  async clear(): Promise<void> {
    const headers: HeadersInit = {};
    
    if (this.apiKey) {
      headers['Authorization'] = `Bearer ${this.apiKey}`;
    }

    const response = await fetch(`${this.apiUrl}/deployments`, {
      method: 'DELETE',
      headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to clear deployments: ${response.statusText}`);
    }
  }
}

// IPFS Storage Adapter (for decentralized storage)
export class IpfsStorageAdapter implements StorageAdapter {
  private gateway: string;
  private pinningService?: string;
  private pinningKey?: string;

  constructor(gateway: string, pinningService?: string, pinningKey?: string) {
    this.gateway = gateway;
    this.pinningService = pinningService;
    this.pinningKey = pinningKey;
  }

  async save(deployments: DeploymentInfo[]): Promise<void> {
    if (!this.pinningService || !this.pinningKey) {
      throw new Error('IPFS pinning service required for saving');
    }

    const data = JSON.stringify(deployments);
    const blob = new Blob([data], { type: 'application/json' });
    const formData = new FormData();
    formData.append('file', blob, 'deployments.json');

    const response = await fetch(`${this.pinningService}/pinning/pinFileToIPFS`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.pinningKey}`,
      },
      body: formData,
    });

    if (!response.ok) {
      throw new Error(`Failed to pin to IPFS: ${response.statusText}`);
    }

    const result = await response.json();
    // Store the IPFS hash in localStorage for reference
    if (typeof window !== 'undefined') {
      localStorage.setItem('sova-btc-ipfs-hash', result.IpfsHash);
    }
  }

  async load(): Promise<DeploymentInfo[]> {
    if (typeof window === 'undefined') return [];
    
    const ipfsHash = localStorage.getItem('sova-btc-ipfs-hash');
    if (!ipfsHash) return [];

    const response = await fetch(`${this.gateway}/ipfs/${ipfsHash}`);
    if (!response.ok) {
      throw new Error(`Failed to load from IPFS: ${response.statusText}`);
    }

    return response.json();
  }

  async clear(): Promise<void> {
    if (typeof window !== 'undefined') {
      localStorage.removeItem('sova-btc-ipfs-hash');
    }
  }
}

// Storage factory
export class StorageFactory {
  static create(type: 'local' | 'api' | 'ipfs', config?: any): StorageAdapter {
    switch (type) {
      case 'local':
        return new LocalStorageAdapter(config?.key);
      
      case 'api':
        if (!config?.apiUrl) {
          throw new Error('API URL required for API storage');
        }
        return new ApiStorageAdapter(config.apiUrl, config.apiKey);
      
      case 'ipfs':
        if (!config?.gateway) {
          throw new Error('IPFS gateway required');
        }
        return new IpfsStorageAdapter(
          config.gateway,
          config.pinningService,
          config.pinningKey
        );
      
      default:
        return new LocalStorageAdapter();
    }
  }
}