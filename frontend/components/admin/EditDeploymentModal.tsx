'use client';

import { useState } from 'react';
import { DeploymentInfo, ContractAddresses, CollateralToken } from '@/lib/deployments/registry';
import { DeploymentValidator } from '@/lib/deployments/validator';
import { X, Save, AlertCircle, Plus, Trash2, Coins } from 'lucide-react';
import { isAddress } from 'viem';
import { toast } from 'react-hot-toast';

interface EditDeploymentModalProps {
  deployment: DeploymentInfo;
  onUpdate: (updates: Partial<DeploymentInfo>) => void;
  onClose: () => void;
}

export function EditDeploymentModal({ deployment, onUpdate, onClose }: EditDeploymentModalProps) {
  const [contracts, setContracts] = useState<ContractAddresses>(deployment.contracts);
  const [collaterals, setCollaterals] = useState<Record<string, CollateralToken>>(deployment.collaterals);
  const [status, setStatus] = useState<DeploymentInfo['status']>(deployment.status);
  const [verified, setVerified] = useState(deployment.deployment.verified);
  
  const [newCollateral, setNewCollateral] = useState<CollateralToken>({
    address: '',
    decimals: 8,
    name: '',
    symbol: '',
  });
  
  const [errors, setErrors] = useState<string[]>([]);

  const handleAddCollateral = () => {
    if (!newCollateral.symbol || !newCollateral.address) {
      toast.error('Symbol and address are required');
      return;
    }

    if (!isAddress(newCollateral.address)) {
      toast.error('Invalid collateral address');
      return;
    }

    setCollaterals({
      ...collaterals,
      [newCollateral.symbol]: { ...newCollateral },
    });

    setNewCollateral({
      address: '',
      decimals: 8,
      name: '',
      symbol: '',
    });

    toast.success('Collateral added');
  };

  const handleRemoveCollateral = (symbol: string) => {
    const updated = { ...collaterals };
    delete updated[symbol];
    setCollaterals(updated);
  };

  const handleValidate = () => {
    const updatedDeployment: DeploymentInfo = {
      ...deployment,
      contracts,
      collaterals,
      status,
      deployment: {
        ...deployment.deployment,
        verified,
      },
    };

    const validation = DeploymentValidator.validateDeployment(updatedDeployment);
    setErrors(validation.errors);
    
    if (validation.warnings.length > 0) {
      validation.warnings.forEach(w => toast(w, { icon: '⚠️' }));
    }

    return validation.valid;
  };

  const handleSubmit = () => {
    if (!handleValidate()) {
      toast.error('Please fix validation errors');
      return;
    }

    onUpdate({
      contracts,
      collaterals,
      status,
      deployment: {
        ...deployment.deployment,
        verified,
      },
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      
      {/* Modal */}
      <div className="relative glass-card rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="p-6 border-b border-white/10">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold text-white">
                Edit {deployment.network.name} Deployment
              </h2>
              <p className="text-white/60 text-sm mt-1">
                Chain ID: {deployment.network.chainId}
              </p>
            </div>
            <button
              onClick={onClose}
              className="p-2 hover:bg-white/10 rounded-lg transition-colors"
            >
              <X className="w-5 h-5 text-white/60" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto max-h-[calc(90vh-200px)]">
          {/* Contract Addresses */}
          <div className="space-y-4 mb-6">
            <h3 className="text-white/87 font-medium">Contract Addresses</h3>
            
            <div className="space-y-3">
              <div>
                <label className="block text-white/60 text-sm mb-1">
                  BTC Vault Strategy
                </label>
                <input
                  type="text"
                  value={contracts.btcVaultStrategy}
                  onChange={(e) => setContracts({ ...contracts, btcVaultStrategy: e.target.value })}
                  className="w-full glass-input rounded-lg px-3 py-2 font-mono text-sm"
                  placeholder="0x..."
                />
              </div>
              <div>
                <label className="block text-white/60 text-sm mb-1">
                  BTC Vault Token
                </label>
                <input
                  type="text"
                  value={contracts.btcVaultToken}
                  onChange={(e) => setContracts({ ...contracts, btcVaultToken: e.target.value })}
                  className="w-full glass-input rounded-lg px-3 py-2 font-mono text-sm"
                  placeholder="0x..."
                />
              </div>
              <div>
                <label className="block text-white/60 text-sm mb-1">
                  Price Oracle
                </label>
                <input
                  type="text"
                  value={contracts.priceOracle || ''}
                  onChange={(e) => setContracts({ ...contracts, priceOracle: e.target.value })}
                  className="w-full glass-input rounded-lg px-3 py-2 font-mono text-sm"
                  placeholder="0x..."
                />
              </div>
            </div>
          </div>

          {/* Collateral Tokens */}
          <div className="space-y-4 mb-6">
            <h3 className="text-white/87 font-medium flex items-center space-x-2">
              <Coins className="w-4 h-4" />
              <span>Collateral Tokens</span>
            </h3>
            
            {/* Existing Collaterals */}
            {Object.entries(collaterals).length > 0 && (
              <div className="space-y-2 mb-4">
                {Object.entries(collaterals).map(([symbol, collateral]) => (
                  <div key={symbol} className="glass-card rounded-lg p-3 flex items-center justify-between">
                    <div className="flex-1">
                      <div className="flex items-center space-x-2">
                        <span className="text-white font-medium">{symbol}</span>
                        <span className="text-white/60 text-sm">
                          {collateral.decimals} decimals
                        </span>
                      </div>
                      <div className="text-white/40 text-xs font-mono mt-1">
                        {collateral.address}
                      </div>
                    </div>
                    <button
                      onClick={() => handleRemoveCollateral(symbol)}
                      className="p-1 hover:bg-white/10 rounded transition-colors ml-2"
                    >
                      <Trash2 className="w-4 h-4 text-white/60" />
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* Add New Collateral */}
            <div className="glass-card rounded-lg p-4">
              <div className="grid grid-cols-2 gap-3 mb-3">
                <div>
                  <label className="block text-white/60 text-xs mb-1">Symbol</label>
                  <input
                    type="text"
                    value={newCollateral.symbol}
                    onChange={(e) => setNewCollateral({ ...newCollateral, symbol: e.target.value })}
                    className="w-full glass-input rounded px-2 py-1 text-sm"
                    placeholder="WBTC"
                  />
                </div>
                <div>
                  <label className="block text-white/60 text-xs mb-1">Name</label>
                  <input
                    type="text"
                    value={newCollateral.name}
                    onChange={(e) => setNewCollateral({ ...newCollateral, name: e.target.value })}
                    className="w-full glass-input rounded px-2 py-1 text-sm"
                    placeholder="Wrapped Bitcoin"
                  />
                </div>
                <div>
                  <label className="block text-white/60 text-xs mb-1">Address</label>
                  <input
                    type="text"
                    value={newCollateral.address}
                    onChange={(e) => setNewCollateral({ ...newCollateral, address: e.target.value })}
                    className="w-full glass-input rounded px-2 py-1 text-sm font-mono"
                    placeholder="0x..."
                  />
                </div>
                <div>
                  <label className="block text-white/60 text-xs mb-1">Decimals</label>
                  <input
                    type="number"
                    value={newCollateral.decimals}
                    onChange={(e) => setNewCollateral({ ...newCollateral, decimals: parseInt(e.target.value) })}
                    className="w-full glass-input rounded px-2 py-1 text-sm"
                    placeholder="8"
                  />
                </div>
              </div>
              <button
                onClick={handleAddCollateral}
                className="glass-button rounded px-3 py-1 text-sm flex items-center space-x-1"
              >
                <Plus className="w-3 h-3" />
                <span>Add Collateral</span>
              </button>
            </div>
          </div>

          {/* Deployment Settings */}
          <div className="space-y-4 mb-6">
            <h3 className="text-white/87 font-medium">Deployment Settings</h3>
            
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-white/60 text-sm mb-1">Status</label>
                <select
                  value={status}
                  onChange={(e) => setStatus(e.target.value as DeploymentInfo['status'])}
                  className="w-full glass-input rounded-lg px-3 py-2"
                >
                  <option value="not-deployed">Not Deployed</option>
                  <option value="pending">Pending</option>
                  <option value="active">Active</option>
                  <option value="deprecated">Deprecated</option>
                </select>
              </div>
              
              <div>
                <label className="block text-white/60 text-sm mb-1">Verification</label>
                <div className="flex items-center space-x-3 mt-2">
                  <label className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      checked={verified}
                      onChange={(e) => setVerified(e.target.checked)}
                      className="rounded border-white/20 bg-white/10"
                    />
                    <span className="text-white/87">Contracts Verified</span>
                  </label>
                </div>
              </div>
            </div>
          </div>

          {/* Validation Errors */}
          {errors.length > 0 && (
            <div className="glass-card rounded-lg p-4 border-rose-400/30 bg-rose-400/5">
              <div className="flex items-center space-x-2 text-rose-400 mb-2">
                <AlertCircle className="w-4 h-4" />
                <span className="font-medium">Validation Errors</span>
              </div>
              <ul className="space-y-1">
                {errors.map((error, i) => (
                  <li key={i} className="text-white/60 text-sm">• {error}</li>
                ))}
              </ul>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-white/10 flex items-center justify-end space-x-3">
          <button
            onClick={onClose}
            className="glass-button rounded-lg px-4 py-2"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            className="bg-gradient-primary text-white rounded-lg px-4 py-2 font-medium flex items-center space-x-2"
          >
            <Save className="w-4 h-4" />
            <span>Save Changes</span>
          </button>
        </div>
      </div>
    </div>
  );
}