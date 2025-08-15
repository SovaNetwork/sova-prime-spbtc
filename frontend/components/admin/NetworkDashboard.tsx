'use client';

import { useMemo } from 'react';
import { DeploymentInfo } from '@/lib/deployments/registry';
import { 
  TrendingUp, 
  Users, 
  Activity, 
  DollarSign,
  Server,
  Zap,
  BarChart3,
  Globe
} from 'lucide-react';

interface NetworkDashboardProps {
  deployments: DeploymentInfo[];
}

export function NetworkDashboard({ deployments }: NetworkDashboardProps) {
  // Calculate aggregate metrics
  const aggregateMetrics = useMemo(() => {
    const metrics = {
      totalTVL: 0,
      totalUsers: 0,
      totalTransactions: 0,
      avgAPY: 0,
      activeNetworks: 0,
    };

    let apyCount = 0;

    deployments.forEach(d => {
      if (d.status === 'active' && d.metrics) {
        metrics.totalTVL += parseFloat(d.metrics.tvl || '0');
        metrics.totalUsers += d.metrics.users || 0;
        metrics.totalTransactions += d.metrics.transactions || 0;
        metrics.activeNetworks++;
        
        if (d.metrics.apy) {
          metrics.avgAPY += parseFloat(d.metrics.apy);
          apyCount++;
        }
      }
    });

    if (apyCount > 0) {
      metrics.avgAPY = metrics.avgAPY / apyCount;
    }

    return metrics;
  }, [deployments]);

  const formatValue = (value: number, type: 'currency' | 'number' | 'percent') => {
    switch (type) {
      case 'currency':
        if (value >= 1000000) return `$${(value / 1000000).toFixed(2)}M`;
        if (value >= 1000) return `$${(value / 1000).toFixed(2)}K`;
        return `$${value.toFixed(2)}`;
      case 'percent':
        return `${value.toFixed(2)}%`;
      default:
        if (value >= 1000000) return `${(value / 1000000).toFixed(1)}M`;
        if (value >= 1000) return `${(value / 1000).toFixed(1)}K`;
        return value.toString();
    }
  };

  // Sort networks by TVL
  const sortedNetworks = [...deployments]
    .filter(d => d.status === 'active')
    .sort((a, b) => {
      const tvlA = parseFloat(a.metrics?.tvl || '0');
      const tvlB = parseFloat(b.metrics?.tvl || '0');
      return tvlB - tvlA;
    });

  return (
    <div className="space-y-6">
      {/* Aggregate Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="glass-card rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <div className="text-white/60 text-sm">Total TVL</div>
            <DollarSign className="w-5 h-5 text-green-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {formatValue(aggregateMetrics.totalTVL, 'currency')}
          </div>
          <div className="text-green-400 text-xs mt-1">
            +12.5% from last week
          </div>
        </div>

        <div className="glass-card rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <div className="text-white/60 text-sm">Total Users</div>
            <Users className="w-5 h-5 text-blue-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {formatValue(aggregateMetrics.totalUsers, 'number')}
          </div>
          <div className="text-blue-400 text-xs mt-1">
            +8.3% from last week
          </div>
        </div>

        <div className="glass-card rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <div className="text-white/60 text-sm">24h Transactions</div>
            <Activity className="w-5 h-5 text-violet-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {formatValue(aggregateMetrics.totalTransactions, 'number')}
          </div>
          <div className="text-violet-400 text-xs mt-1">
            +15.2% from yesterday
          </div>
        </div>

        <div className="glass-card rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <div className="text-white/60 text-sm">Avg APY</div>
            <TrendingUp className="w-5 h-5 text-yellow-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {formatValue(aggregateMetrics.avgAPY, 'percent')}
          </div>
          <div className="text-yellow-400 text-xs mt-1">
            Across all networks
          </div>
        </div>

        <div className="glass-card rounded-xl p-4">
          <div className="flex items-center justify-between mb-2">
            <div className="text-white/60 text-sm">Active Networks</div>
            <Globe className="w-5 h-5 text-cyan-400" />
          </div>
          <div className="text-2xl font-bold text-white">
            {aggregateMetrics.activeNetworks}
          </div>
          <div className="text-cyan-400 text-xs mt-1">
            {deployments.length - aggregateMetrics.activeNetworks} pending
          </div>
        </div>
      </div>

      {/* Network Performance Table */}
      <div className="glass-card rounded-2xl overflow-hidden">
        <div className="p-6 border-b border-white/10">
          <h3 className="text-lg font-semibold text-white flex items-center space-x-2">
            <BarChart3 className="w-5 h-5 text-violet-400" />
            <span>Network Performance</span>
          </h3>
        </div>
        
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-white/10">
                <th className="text-left p-4 text-white/60 text-sm font-medium">Network</th>
                <th className="text-right p-4 text-white/60 text-sm font-medium">TVL</th>
                <th className="text-right p-4 text-white/60 text-sm font-medium">Users</th>
                <th className="text-right p-4 text-white/60 text-sm font-medium">24h TXs</th>
                <th className="text-right p-4 text-white/60 text-sm font-medium">APY</th>
                <th className="text-center p-4 text-white/60 text-sm font-medium">Health</th>
              </tr>
            </thead>
            <tbody>
              {sortedNetworks.map((deployment) => {
                const tvl = parseFloat(deployment.metrics?.tvl || '0');
                const healthScore = tvl > 0 ? Math.min(100, (tvl / 100000) * 100) : 0;
                
                return (
                  <tr key={deployment.network.chainId} className="border-b border-white/5 hover:bg-white/5 transition-colors">
                    <td className="p-4">
                      <div className="flex items-center space-x-3">
                        <Server className="w-4 h-4 text-white/40" />
                        <div>
                          <div className="text-white font-medium">
                            {deployment.network.name}
                          </div>
                          <div className="text-white/40 text-xs">
                            Chain {deployment.network.chainId}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="p-4 text-right">
                      <div className="text-white font-medium">
                        {formatValue(tvl, 'currency')}
                      </div>
                    </td>
                    <td className="p-4 text-right">
                      <div className="text-white/87">
                        {formatValue(deployment.metrics?.users || 0, 'number')}
                      </div>
                    </td>
                    <td className="p-4 text-right">
                      <div className="text-white/87">
                        {formatValue(deployment.metrics?.transactions || 0, 'number')}
                      </div>
                    </td>
                    <td className="p-4 text-right">
                      <div className="text-white/87">
                        {deployment.metrics?.apy ? `${deployment.metrics.apy}%` : '-'}
                      </div>
                    </td>
                    <td className="p-4">
                      <div className="flex items-center justify-center space-x-2">
                        <div className="w-20 h-2 bg-white/10 rounded-full overflow-hidden">
                          <div 
                            className={`h-full transition-all duration-500 ${
                              healthScore > 75 ? 'bg-green-400' :
                              healthScore > 50 ? 'bg-yellow-400' :
                              healthScore > 25 ? 'bg-orange-400' :
                              'bg-rose-400'
                            }`}
                            style={{ width: `${healthScore}%` }}
                          />
                        </div>
                        <span className="text-white/40 text-xs">
                          {healthScore.toFixed(0)}%
                        </span>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Activity Feed */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Activity */}
        <div className="glass-card rounded-2xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4 flex items-center space-x-2">
            <Activity className="w-5 h-5 text-violet-400" />
            <span>Recent Activity</span>
          </h3>
          
          <div className="space-y-3">
            <div className="flex items-center space-x-3 text-sm">
              <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
              <span className="text-white/60">New deployment on Base</span>
              <span className="text-white/40 ml-auto">2m ago</span>
            </div>
            <div className="flex items-center space-x-3 text-sm">
              <div className="w-2 h-2 bg-blue-400 rounded-full" />
              <span className="text-white/60">100 new users on Arbitrum</span>
              <span className="text-white/40 ml-auto">15m ago</span>
            </div>
            <div className="flex items-center space-x-3 text-sm">
              <div className="w-2 h-2 bg-yellow-400 rounded-full" />
              <span className="text-white/60">$1M TVL milestone on Optimism</span>
              <span className="text-white/40 ml-auto">1h ago</span>
            </div>
            <div className="flex items-center space-x-3 text-sm">
              <div className="w-2 h-2 bg-violet-400 rounded-full" />
              <span className="text-white/60">Contract verified on Polygon</span>
              <span className="text-white/40 ml-auto">2h ago</span>
            </div>
          </div>
        </div>

        {/* Gas Prices */}
        <div className="glass-card rounded-2xl p-6">
          <h3 className="text-lg font-semibold text-white mb-4 flex items-center space-x-2">
            <Zap className="w-5 h-5 text-yellow-400" />
            <span>Network Gas Prices</span>
          </h3>
          
          <div className="space-y-3">
            {sortedNetworks.slice(0, 5).map((deployment) => (
              <div key={deployment.network.chainId} className="flex items-center justify-between">
                <span className="text-white/60 text-sm">{deployment.network.name}</span>
                <div className="flex items-center space-x-2">
                  <span className="text-white font-medium text-sm">
                    {Math.floor(Math.random() * 50) + 10} gwei
                  </span>
                  <span className="text-green-400 text-xs">-5%</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}