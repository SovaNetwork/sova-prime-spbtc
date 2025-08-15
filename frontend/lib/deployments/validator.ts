import { DeploymentInfo, NetworkConfig, ContractAddresses, CollateralToken } from './registry';
import { isAddress } from 'viem';

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

export class DeploymentValidator {
  static validateNetwork(network: NetworkConfig): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Required fields
    if (!network.chainId || network.chainId <= 0) {
      errors.push('Invalid chain ID');
    }

    if (!network.name || network.name.trim() === '') {
      errors.push('Network name is required');
    }

    if (!network.rpcUrl || !this.isValidUrl(network.rpcUrl)) {
      errors.push('Invalid RPC URL');
    }

    if (!network.blockExplorer || !this.isValidUrl(network.blockExplorer)) {
      warnings.push('Invalid or missing block explorer URL');
    }

    // Native currency validation
    if (!network.nativeCurrency) {
      errors.push('Native currency configuration is required');
    } else {
      if (!network.nativeCurrency.symbol) {
        errors.push('Native currency symbol is required');
      }
      if (!network.nativeCurrency.name) {
        errors.push('Native currency name is required');
      }
      if (network.nativeCurrency.decimals !== 18 && network.nativeCurrency.decimals !== 9) {
        warnings.push('Unusual native currency decimals (expected 18 or 9)');
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }

  static validateContracts(contracts: ContractAddresses): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Required contracts
    if (!contracts.btcVaultStrategy || !isAddress(contracts.btcVaultStrategy)) {
      errors.push('Invalid or missing BTC Vault Strategy address');
    }

    if (!contracts.btcVaultToken || !isAddress(contracts.btcVaultToken)) {
      errors.push('Invalid or missing BTC Vault Token address');
    }

    // Optional but recommended
    if (contracts.priceOracle && !isAddress(contracts.priceOracle)) {
      warnings.push('Invalid price oracle address');
    } else if (!contracts.priceOracle) {
      warnings.push('Price oracle not configured');
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }

  static validateCollateral(collateral: CollateralToken): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    if (!collateral.address || !isAddress(collateral.address)) {
      errors.push(`Invalid collateral address: ${collateral.address}`);
    }

    if (!collateral.symbol || collateral.symbol.trim() === '') {
      errors.push('Collateral symbol is required');
    }

    if (!collateral.name || collateral.name.trim() === '') {
      errors.push('Collateral name is required');
    }

    if (collateral.decimals < 0 || collateral.decimals > 18) {
      errors.push(`Invalid decimals: ${collateral.decimals}`);
    }

    if (!collateral.oracleId) {
      warnings.push(`No oracle ID configured for ${collateral.symbol}`);
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }

  static validateDeployment(deployment: DeploymentInfo): ValidationResult {
    const allErrors: string[] = [];
    const allWarnings: string[] = [];

    // Validate network
    const networkValidation = this.validateNetwork(deployment.network);
    allErrors.push(...networkValidation.errors.map(e => `Network: ${e}`));
    allWarnings.push(...networkValidation.warnings.map(w => `Network: ${w}`));

    // Validate contracts
    const contractsValidation = this.validateContracts(deployment.contracts);
    allErrors.push(...contractsValidation.errors.map(e => `Contracts: ${e}`));
    allWarnings.push(...contractsValidation.warnings.map(w => `Contracts: ${w}`));

    // Validate collaterals
    if (!deployment.collaterals || Object.keys(deployment.collaterals).length === 0) {
      allErrors.push('At least one collateral token must be configured');
    } else {
      Object.entries(deployment.collaterals).forEach(([symbol, collateral]) => {
        const collateralValidation = this.validateCollateral(collateral);
        allErrors.push(...collateralValidation.errors.map(e => `Collateral ${symbol}: ${e}`));
        allWarnings.push(...collateralValidation.warnings.map(w => `Collateral ${symbol}: ${w}`));
      });
    }

    // Validate deployment metadata
    if (!deployment.deployment) {
      allErrors.push('Deployment metadata is required');
    } else {
      if (!deployment.deployment.timestamp) {
        allWarnings.push('Deployment timestamp is missing');
      }
      if (!deployment.deployment.deployer || !isAddress(deployment.deployment.deployer)) {
        allWarnings.push('Invalid or missing deployer address');
      }
    }

    // Validate status
    const validStatuses = ['active', 'pending', 'deprecated', 'not-deployed'];
    if (!validStatuses.includes(deployment.status)) {
      allErrors.push(`Invalid deployment status: ${deployment.status}`);
    }

    return {
      valid: allErrors.length === 0,
      errors: allErrors,
      warnings: allWarnings,
    };
  }

  static async validateOnChain(deployment: DeploymentInfo, provider: any): Promise<ValidationResult> {
    const errors: string[] = [];
    const warnings: string[] = [];

    try {
      // Check if contracts exist on chain
      const strategyCode = await provider.getBytecode({ address: deployment.contracts.btcVaultStrategy });
      if (!strategyCode || strategyCode === '0x') {
        errors.push('BTC Vault Strategy contract not found on chain');
      }

      const tokenCode = await provider.getBytecode({ address: deployment.contracts.btcVaultToken });
      if (!tokenCode || tokenCode === '0x') {
        errors.push('BTC Vault Token contract not found on chain');
      }

      // Check collateral tokens
      for (const [symbol, collateral] of Object.entries(deployment.collaterals)) {
        const collateralCode = await provider.getBytecode({ address: collateral.address });
        if (!collateralCode || collateralCode === '0x') {
          warnings.push(`Collateral ${symbol} not found on chain`);
        }
      }
    } catch (error) {
      errors.push(`On-chain validation failed: ${error}`);
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }

  private static isValidUrl(url: string): boolean {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }

  static validateImportData(data: any): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    if (!data || typeof data !== 'object') {
      errors.push('Invalid import data format');
      return { valid: false, errors, warnings };
    }

    // Check if it's a deployment record
    const deployments = Object.values(data);
    if (deployments.length === 0) {
      errors.push('No deployments found in import data');
    }

    deployments.forEach((deployment: any, index) => {
      if (!deployment.network || !deployment.contracts) {
        errors.push(`Deployment ${index + 1}: Missing required fields`);
      }
    });

    return {
      valid: errors.length === 0,
      errors,
      warnings,
    };
  }
}