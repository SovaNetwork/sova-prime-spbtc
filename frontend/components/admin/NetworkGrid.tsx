'use client';

import { DeploymentInfo } from '@/lib/deployments/registry';
import { getNetworkName, isTestnet } from '@/lib/deployments/networks';
import { 
  Server, 
  CheckCircle, 
  AlertCircle, 
  Clock, 
  XCircle,
  Edit2,
  Trash2,
  ExternalLink,
  Coins,
  Users,
  Activity
} from 'lucide-react';

interface NetworkGridProps {
  deployments: DeploymentInfo[];
  onEdit: (deployment: DeploymentInfo) => void;
  onRemove: (chainId: number) => void;
}

export function NetworkGrid({ deployments, onEdit, onRemove }: NetworkGridProps) {
  const getStatusIcon = (status: DeploymentInfo['status']) => {
    switch (status) {
      case 'active':
        return <CheckCircle className="w-5 h-5 text-green-400" />;
      case 'pending':
        return <Clock className="w-5 h-5 text-yellow-400" />;
      case 'deprecated':
        return <AlertCircle className="w-5 h-5 text-orange-400" />;
      case 'not-deployed':
        return <XCircle className="w-5 h-5 text-white/40" />;
    }
  };

  const getStatusColor = (status: DeploymentInfo['status']) => {
    switch (status) {
      case 'active':
        return 'border-green-400/30 bg-green-400/5';
      case 'pending':
        return 'border-yellow-400/30 bg-yellow-400/5';
      case 'deprecated':
        return 'border-orange-400/30 bg-orange-400/5';
      case 'not-deployed':
        return 'border-white/10 bg-white/5';
    }
  };

  const formatTVL = (tvl: string | undefined) => {
    if (!tvl) return '$0';
    const value = parseFloat(tvl);
    if (value >= 1000000) {
      return `$${(value / 1000000).toFixed(2)}M`;
    }
    if (value >= 1000) {
      return `$${(value / 1000).toFixed(2)}K`;
    }
    return `$${value.toFixed(2)}`;
  };

  const sortedDeployments = [...deployments].sort((a, b) => {
    // Sort by status priority: active > pending > deprecated > not-deployed
    const statusOrder = { 'active': 0, 'pending': 1, 'deprecated': 2, 'not-deployed': 3 };
    return statusOrder[a.status] - statusOrder[b.status];
  });

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {sortedDeployments.map((deployment) => (
        <div
          key={deployment.network.chainId}
          className={`glass-card rounded-2xl overflow-hidden transition-all duration-300 hover:scale-[1.02] ${getStatusColor(deployment.status)}`}
        >
          {/* Header */}
          <div className="p-6 border-b border-white/10">
            <div className="flex items-start justify-between mb-4">
              <div className="flex items-center space-x-3">
                {getStatusIcon(deployment.status)}
                <div>
                  <h3 className="text-lg font-semibold text-white">
                    {deployment.network.name}
                  </h3>
                  <div className="flex items-center space-x-2 mt-1">
                    <span className="text-white/60 text-sm">
                      Chain ID: {deployment.network.chainId}
                    </span>
                    {isTestnet(deployment.network.chainId) && (
                      <span className="px-2 py-0.5 bg-yellow-400/20 text-yellow-400 text-xs rounded-full">
                        Testnet
                      </span>
                    )}
                  </div>
                </div>
              </div>
              <div className="flex items-center space-x-1">
                <button
                  onClick={() => onEdit(deployment)}
                  className="p-1.5 hover:bg-white/10 rounded-lg transition-colors"
                  title="Edit"
                >
                  <Edit2 className="w-4 h-4 text-white/60" />
                </button>
                <button
                  onClick={() => onRemove(deployment.network.chainId)}
                  className="p-1.5 hover:bg-white/10 rounded-lg transition-colors"
                  title="Remove"
                >
                  <Trash2 className="w-4 h-4 text-white/60" />
                </button>
              </div>
            </div>

            {/* Status Badge */}
            <div className="flex items-center justify-between">
              <span className={`px-3 py-1 rounded-full text-sm font-medium capitalize ${
                deployment.status === 'active' ? 'bg-green-400/20 text-green-400' :
                deployment.status === 'pending' ? 'bg-yellow-400/20 text-yellow-400' :
                deployment.status === 'deprecated' ? 'bg-orange-400/20 text-orange-400' :
                'bg-white/10 text-white/40'
              }`}>
                {deployment.status}
              </span>
              {deployment.deployment.verified && (
                <span className="px-2 py-0.5 bg-blue-400/20 text-blue-400 text-xs rounded-full">
                  Verified
                </span>
              )}
            </div>
          </div>

          {/* Metrics */}
          {deployment.status === 'active' && deployment.metrics && (
            <div className="p-6 border-b border-white/10 grid grid-cols-3 gap-4">
              <div>
                <div className="flex items-center space-x-1 text-white/60 text-xs mb-1">
                  <Coins className="w-3 h-3" />
                  <span>TVL</span>
                </div>
                <div className="text-white font-medium">
                  {formatTVL(deployment.metrics.tvl)}
                </div>
              </div>
              <div>
                <div className="flex items-center space-x-1 text-white/60 text-xs mb-1">
                  <Users className="w-3 h-3" />
                  <span>Users</span>
                </div>
                <div className="text-white font-medium">
                  {deployment.metrics.users || 0}
                </div>
              </div>
              <div>
                <div className="flex items-center space-x-1 text-white/60 text-xs mb-1">
                  <Activity className="w-3 h-3" />
                  <span>24h TXs</span>
                </div>
                <div className="text-white font-medium">
                  {deployment.metrics.transactions || 0}
                </div>
              </div>
            </div>
          )}

          {/* Contracts */}
          <div className="p-6 space-y-3">
            <div>
              <div className="text-white/60 text-xs mb-1">Strategy Contract</div>
              <div className="flex items-center space-x-2">
                <code className="text-white/87 text-sm font-mono">
                  {deployment.contracts.btcVaultStrategy.slice(0, 10)}...
                  {deployment.contracts.btcVaultStrategy.slice(-8)}
                </code>
                <a
                  href={`${deployment.network.blockExplorer}/address/${deployment.contracts.btcVaultStrategy}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-white/60 hover:text-white/87 transition-colors"
                >
                  <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            </div>

            <div>
              <div className="text-white/60 text-xs mb-1">Token Contract</div>
              <div className="flex items-center space-x-2">
                <code className="text-white/87 text-sm font-mono">
                  {deployment.contracts.btcVaultToken.slice(0, 10)}...
                  {deployment.contracts.btcVaultToken.slice(-8)}
                </code>
                <a
                  href={`${deployment.network.blockExplorer}/address/${deployment.contracts.btcVaultToken}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-white/60 hover:text-white/87 transition-colors"
                >
                  <ExternalLink className="w-3 h-3" />
                </a>
              </div>
            </div>

            {/* Collaterals Count */}
            <div className="pt-3 border-t border-white/10">
              <div className="text-white/60 text-xs">
                {Object.keys(deployment.collaterals).length} Collateral{Object.keys(deployment.collaterals).length !== 1 ? 's' : ''} Configured
              </div>
              <div className="flex flex-wrap gap-1 mt-2">
                {Object.keys(deployment.collaterals).slice(0, 3).map(symbol => (
                  <span
                    key={symbol}
                    className="px-2 py-0.5 bg-white/10 text-white/87 text-xs rounded"
                  >
                    {symbol}
                  </span>
                ))}
                {Object.keys(deployment.collaterals).length > 3 && (
                  <span className="px-2 py-0.5 bg-white/10 text-white/60 text-xs rounded">
                    +{Object.keys(deployment.collaterals).length - 3} more
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      ))}

      {/* Add Network Card */}
      <button
        onClick={() => document.querySelector<HTMLButtonElement>('[title="Add Network"]')?.click()}
        className="glass-card rounded-2xl p-6 min-h-[300px] flex flex-col items-center justify-center space-y-4 hover:bg-white/5 transition-all duration-300 hover:scale-[1.02] border-dashed"
      >
        <div className="w-16 h-16 rounded-full bg-violet-400/10 flex items-center justify-center">
          <Server className="w-8 h-8 text-violet-400" />
        </div>
        <div className="text-center">
          <div className="text-white font-medium mb-1">Add Network</div>
          <div className="text-white/60 text-sm">Deploy to a new network</div>
        </div>
      </button>
    </div>
  );
}