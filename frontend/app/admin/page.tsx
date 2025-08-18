'use client';

import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { useNetworkContracts } from '@/hooks/useNetworkContracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI, ERC20_ABI } from '@/lib/abis';
import { GlassCard } from '@/components/GlassCard';
import { 
  Shield, 
  Coins, 
  Droplets, 
  Settings, 
  BarChart3,
  Plus,
  Minus,
  AlertCircle,
  CheckCircle,
  TrendingUp,
  Users,
  Lock,
  Unlock
} from 'lucide-react';
import { cn } from '@/lib/utils';

// Role Manager ABI for admin check
const ROLE_MANAGER_ABI = [
  {
    inputs: [],
    name: 'PROTOCOL_ADMIN',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function'
  },
  {
    inputs: [
      { internalType: 'address', name: 'user', type: 'address' },
      { internalType: 'uint256', name: 'roles', type: 'uint256' }
    ],
    name: 'hasAllRoles',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function'
  }
] as const;

import { RedemptionManager } from '@/components/admin/RedemptionManager';

export default function AdminPage() {
  const { address } = useAccount();
  const { btcVaultStrategy, btcVaultToken, collateralTokens, isSupported } = useNetworkContracts();
  const [activeTab, setActiveTab] = useState<'overview' | 'collateral' | 'liquidity' | 'redemptions' | 'settings'>('overview');
  
  // Collateral management state
  const [newCollateralAddress, setNewCollateralAddress] = useState('');
  const [newCollateralDecimals, setNewCollateralDecimals] = useState('8');
  const [removeCollateralAddress, setRemoveCollateralAddress] = useState('');
  
  // Liquidity management state
  const [liquidityAmount, setLiquidityAmount] = useState('');
  const [isAddingLiquidity, setIsAddingLiquidity] = useState(true);
  
  // Settings state
  const [withdrawalsEnabled, setWithdrawalsEnabled] = useState(true);

  // Check if user is admin (using hardcoded role manager for now)
  const roleManagerAddress = '0x15502fC5e872c8B22BA6dD5e01A7A5bd4f9A3d72';
  
  const { data: protocolAdminRole } = useReadContract({
    address: roleManagerAddress as `0x${string}`,
    abi: ROLE_MANAGER_ABI,
    functionName: 'PROTOCOL_ADMIN',
  });

  const { data: isAdmin } = useReadContract({
    address: roleManagerAddress as `0x${string}`,
    abi: ROLE_MANAGER_ABI,
    functionName: 'hasAllRoles',
    args: address && protocolAdminRole ? [address, protocolAdminRole] : undefined,
  });

  // Read strategy data
  const { data: availableLiquidity } = useReadContract({
    address: btcVaultStrategy as `0x${string}`,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'availableLiquidity',
    query: { enabled: isSupported },
  });

  const { data: totalAssets } = useReadContract({
    address: btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalAssets',
    query: { enabled: isSupported },
  });

  const { data: totalSupply } = useReadContract({
    address: btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalSupply',
    query: { enabled: isSupported },
  });

  // Write functions
  const { writeContract, data: txHash } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash: txHash });

  // Handle functions
  const handleAddCollateral = async () => {
    if (!newCollateralAddress) return;
    
    try {
      await writeContract({
        address: btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'addCollateral',
        args: [newCollateralAddress as `0x${string}`, Number(newCollateralDecimals)],
      });
      setNewCollateralAddress('');
    } catch (error) {
      console.error('Error adding collateral:', error);
    }
  };

  const handleRemoveCollateral = async () => {
    if (!removeCollateralAddress) return;
    
    try {
      await writeContract({
        address: btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'removeCollateral',
        args: [removeCollateralAddress as `0x${string}`],
      });
      setRemoveCollateralAddress('');
    } catch (error) {
      console.error('Error removing collateral:', error);
    }
  };

  const handleAddLiquidity = async () => {
    if (!liquidityAmount) return;
    
    const amount = parseUnits(liquidityAmount, 8);
    
    try {
      await writeContract({
        address: btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'addLiquidity',
        args: [amount],
      });
      setLiquidityAmount('');
    } catch (error) {
      console.error('Error adding liquidity:', error);
    }
  };

  const handleRemoveLiquidity = async () => {
    if (!liquidityAmount) return;
    
    const amount = parseUnits(liquidityAmount, 8);
    
    try {
      await writeContract({
        address: btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'removeLiquidity',
        args: [amount, address as `0x${string}`],
      });
      setLiquidityAmount('');
    } catch (error) {
      console.error('Error removing liquidity:', error);
    }
  };

  if (!isSupported) {
    return (
      <main className="container mx-auto px-6 py-12">
        <GlassCard>
          <div className="flex items-center gap-3">
            <AlertCircle className="w-6 h-6 text-orange-500" />
            <div>
              <h2 className="text-xl font-bold text-white">Network Not Supported</h2>
              <p className="text-white/60">Please switch to a supported network to access the admin panel.</p>
            </div>
          </div>
        </GlassCard>
      </main>
    );
  }

  if (!isAdmin) {
    return (
      <main className="container mx-auto px-6 py-12">
        <GlassCard>
          <div className="flex items-center gap-3">
            <Shield className="w-6 h-6 text-red-500" />
            <div>
              <h2 className="text-xl font-bold text-white">Access Denied</h2>
              <p className="text-white/60">You must have admin privileges to access this panel.</p>
            </div>
          </div>
        </GlassCard>
      </main>
    );
  }

  const liquidity = availableLiquidity ? Number(formatUnits(availableLiquidity, 8)) : 0;
  const tvl = totalAssets ? Number(formatUnits(totalAssets, 8)) : 0;
  const shares = totalSupply ? Number(formatUnits(totalSupply, 18)) : 0;
  const sharePrice = shares > 0 ? tvl / shares : 1;
  const utilization = tvl > 0 ? ((tvl - liquidity) / tvl) * 100 : 0;

  const tabs = [
    { id: 'overview', label: 'Overview', icon: BarChart3 },
    { id: 'collateral', label: 'Collateral', icon: Coins },
    { id: 'liquidity', label: 'Liquidity', icon: Droplets },
    { id: 'redemptions', label: 'Redemptions', icon: TrendingUp },
    { id: 'settings', label: 'Settings', icon: Settings },
  ] as const;

  return (
    <main className="container mx-auto px-6 py-12">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-4xl font-bold text-white mb-2">Admin Panel</h1>
            <p className="text-white/60">Manage vault operations and monitor system health</p>
          </div>
          <div className="flex items-center gap-2">
            <Shield className="w-5 h-5 text-green-400" />
            <span className="text-white/80">Admin Connected</span>
          </div>
        </div>
      </div>

      {/* Tab Navigation */}
      <div className="mb-6">
        <div className="flex space-x-2 bg-white/5 backdrop-blur-md rounded-2xl p-2 border border-white/10">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={cn(
                  'flex items-center space-x-2 px-4 py-2 rounded-xl transition-all duration-300',
                  isActive 
                    ? 'bg-white/20 text-white shadow-[0_4px_15px_0_rgba(31,38,135,0.4)] backdrop-blur-lg border border-white/20' 
                    : 'text-white/70 hover:bg-white/10 hover:text-white'
                )}
              >
                <Icon className="w-4 h-4" />
                <span className="font-medium">{tab.label}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Content */}
      <div className="space-y-6">
        {activeTab === 'overview' && (
          <>
            {/* Key Metrics */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
              <GlassCard>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white/60 text-sm">Total Value Locked</p>
                    <p className="text-2xl font-bold text-white">{tvl.toFixed(4)}</p>
                    <p className="text-white/40 text-xs">BTC</p>
                  </div>
                  <TrendingUp className="w-8 h-8 text-green-400" />
                </div>
              </GlassCard>

              <GlassCard>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white/60 text-sm">Total Shares</p>
                    <p className="text-2xl font-bold text-white">{shares.toFixed(2)}</p>
                    <p className="text-white/40 text-xs">btcVault</p>
                  </div>
                  <Users className="w-8 h-8 text-blue-400" />
                </div>
              </GlassCard>

              <GlassCard>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white/60 text-sm">Share Price</p>
                    <p className="text-2xl font-bold text-white">{sharePrice.toFixed(6)}</p>
                    <p className="text-white/40 text-xs">BTC/Share</p>
                  </div>
                  <Coins className="w-8 h-8 text-yellow-400" />
                </div>
              </GlassCard>

              <GlassCard>
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white/60 text-sm">Utilization</p>
                    <p className="text-2xl font-bold text-white">{utilization.toFixed(1)}%</p>
                    <p className="text-white/40 text-xs">of liquidity</p>
                  </div>
                  <BarChart3 className="w-8 h-8 text-mint-400" />
                </div>
              </GlassCard>
            </div>

            {/* Liquidity Status */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">Liquidity Status</h3>
              <div className="space-y-4">
                <div>
                  <div className="flex justify-between text-sm mb-2">
                    <span className="text-white/60">Available Liquidity</span>
                    <span className="text-white">{liquidity.toFixed(4)} sovaBTC</span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-2">
                    <div 
                      className="bg-gradient-to-r from-blue-500 to-mint-500 h-2 rounded-full"
                      style={{ width: `${100 - utilization}%` }}
                    />
                  </div>
                </div>
                
                <div className="grid grid-cols-2 gap-4 pt-4 border-t border-white/10">
                  <div>
                    <p className="text-white/60 text-sm">Total Deposits</p>
                    <p className="text-white font-semibold">{tvl.toFixed(4)} BTC</p>
                  </div>
                  <div>
                    <p className="text-white/60 text-sm">Available for Withdrawal</p>
                    <p className="text-white font-semibold">{liquidity.toFixed(4)} BTC</p>
                  </div>
                </div>
              </div>
            </GlassCard>

            {/* System Status */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">System Status</h3>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="flex items-center gap-2">
                  <CheckCircle className="w-5 h-5 text-green-400" />
                  <span className="text-white/80 text-sm">Contracts Active</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle className="w-5 h-5 text-green-400" />
                  <span className="text-white/80 text-sm">Oracle Connected</span>
                </div>
                <div className="flex items-center gap-2">
                  {withdrawalsEnabled ? (
                    <CheckCircle className="w-5 h-5 text-green-400" />
                  ) : (
                    <AlertCircle className="w-5 h-5 text-yellow-400" />
                  )}
                  <span className="text-white/80 text-sm">
                    Withdrawals {withdrawalsEnabled ? 'Enabled' : 'Disabled'}
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle className="w-5 h-5 text-green-400" />
                  <span className="text-white/80 text-sm">Admin Connected</span>
                </div>
              </div>
            </GlassCard>
          </>
        )}

        {activeTab === 'collateral' && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Add Collateral */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <Plus className="w-5 h-5" />
                Add New Collateral
              </h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-white/60 text-sm mb-2">Token Address</label>
                  <input
                    type="text"
                    placeholder="0x..."
                    className="w-full px-4 py-3 bg-white/10 backdrop-blur-sm border border-white/20 rounded-xl text-white placeholder-white/40 focus:outline-none focus:border-white/40"
                    value={newCollateralAddress}
                    onChange={(e) => setNewCollateralAddress(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-white/60 text-sm mb-2">Decimals</label>
                  <input
                    type="number"
                    placeholder="8"
                    className="w-full px-4 py-3 bg-white/10 backdrop-blur-sm border border-white/20 rounded-xl text-white placeholder-white/40 focus:outline-none focus:border-white/40"
                    value={newCollateralDecimals}
                    onChange={(e) => setNewCollateralDecimals(e.target.value)}
                  />
                </div>
                <button
                  onClick={handleAddCollateral}
                  disabled={!newCollateralAddress || isConfirming}
                  className="w-full bg-gradient-to-r from-green-500 to-emerald-500 text-white py-3 px-6 rounded-xl hover:shadow-[0_8px_25px_0_rgba(34,197,94,0.4)] transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isConfirming ? 'Adding...' : 'Add Collateral'}
                </button>
              </div>
            </GlassCard>

            {/* Remove Collateral */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4 flex items-center gap-2">
                <Minus className="w-5 h-5" />
                Remove Collateral
              </h3>
              <div className="space-y-4">
                <div>
                  <label className="block text-white/60 text-sm mb-2">Select Collateral</label>
                  <select
                    className="w-full px-4 py-3 bg-white/10 backdrop-blur-sm border border-white/20 rounded-xl text-white focus:outline-none focus:border-white/40"
                    value={removeCollateralAddress}
                    onChange={(e) => setRemoveCollateralAddress(e.target.value)}
                  >
                    <option value="">Select a token</option>
                    {collateralTokens.map((token) => (
                      <option key={token.address} value={token.address}>
                        {token.symbol} - {token.address.slice(0, 6)}...{token.address.slice(-4)}
                      </option>
                    ))}
                  </select>
                </div>
                <button
                  onClick={handleRemoveCollateral}
                  disabled={!removeCollateralAddress || isConfirming}
                  className="w-full bg-gradient-to-r from-red-500 to-rose-500 text-white py-3 px-6 rounded-xl hover:shadow-[0_8px_25px_0_rgba(239,68,68,0.4)] transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isConfirming ? 'Removing...' : 'Remove Collateral'}
                </button>
              </div>
            </GlassCard>

            {/* Current Collaterals */}
            <GlassCard className="lg:col-span-2">
              <h3 className="text-lg font-semibold text-white mb-4">Supported Collaterals</h3>
              <div className="space-y-2">
                {collateralTokens.map((token) => (
                  <div key={token.address} className="flex items-center justify-between p-3 bg-white/5 rounded-lg">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 bg-gradient-to-r from-orange-500 to-yellow-500 rounded-full flex items-center justify-center">
                        <span className="text-white text-xs font-bold">₿</span>
                      </div>
                      <div>
                        <p className="text-white font-medium">{token.symbol}</p>
                        <p className="text-white/40 text-xs">{token.name}</p>
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-white/60 text-sm">{token.address.slice(0, 6)}...{token.address.slice(-4)}</p>
                      <p className="text-white/40 text-xs">Decimals: {token.decimals}</p>
                    </div>
                  </div>
                ))}
              </div>
            </GlassCard>
          </div>
        )}

        {activeTab === 'liquidity' && (
          <div className="space-y-6">
            {/* Liquidity Overview */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">Liquidity Overview</h3>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 bg-white/5 rounded-xl">
                  <p className="text-white/60 text-sm">Available</p>
                  <p className="text-2xl font-bold text-white">{liquidity.toFixed(4)}</p>
                  <p className="text-white/40 text-xs">sovaBTC</p>
                </div>
                <div className="p-4 bg-white/5 rounded-xl">
                  <p className="text-white/60 text-sm">Utilized</p>
                  <p className="text-2xl font-bold text-white">{(tvl - liquidity).toFixed(4)}</p>
                  <p className="text-white/40 text-xs">sovaBTC</p>
                </div>
                <div className="p-4 bg-white/5 rounded-xl">
                  <p className="text-white/60 text-sm">Utilization Rate</p>
                  <p className="text-2xl font-bold text-white">{utilization.toFixed(1)}%</p>
                  <p className="text-white/40 text-xs">of total</p>
                </div>
              </div>
            </GlassCard>

            {/* Manage Liquidity */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">Manage Liquidity</h3>
              
              <div className="flex gap-2 mb-4">
                <button
                  onClick={() => setIsAddingLiquidity(true)}
                  className={cn(
                    'flex-1 py-2 px-4 rounded-xl transition-all duration-300',
                    isAddingLiquidity 
                      ? 'bg-white/20 text-white border border-white/20' 
                      : 'bg-white/5 text-white/60 hover:bg-white/10'
                  )}
                >
                  Add Liquidity
                </button>
                <button
                  onClick={() => setIsAddingLiquidity(false)}
                  className={cn(
                    'flex-1 py-2 px-4 rounded-xl transition-all duration-300',
                    !isAddingLiquidity 
                      ? 'bg-white/20 text-white border border-white/20' 
                      : 'bg-white/5 text-white/60 hover:bg-white/10'
                  )}
                >
                  Remove Liquidity
                </button>
              </div>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-white/60 text-sm mb-2">Amount (sovaBTC)</label>
                  <input
                    type="number"
                    step="0.01"
                    placeholder="0.00"
                    className="w-full px-4 py-3 bg-white/10 backdrop-blur-sm border border-white/20 rounded-xl text-white placeholder-white/40 focus:outline-none focus:border-white/40"
                    value={liquidityAmount}
                    onChange={(e) => setLiquidityAmount(e.target.value)}
                  />
                </div>
                <button
                  onClick={isAddingLiquidity ? handleAddLiquidity : handleRemoveLiquidity}
                  disabled={!liquidityAmount || isConfirming}
                  className={cn(
                    'w-full py-3 px-6 rounded-xl transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed',
                    isAddingLiquidity 
                      ? 'bg-gradient-to-r from-green-500 to-emerald-500 hover:shadow-[0_8px_25px_0_rgba(34,197,94,0.4)]' 
                      : 'bg-gradient-to-r from-red-500 to-rose-500 hover:shadow-[0_8px_25px_0_rgba(239,68,68,0.4)]',
                    'text-white'
                  )}
                >
                  {isConfirming ? 'Processing...' : isAddingLiquidity ? 'Add Liquidity' : 'Remove Liquidity'}
                </button>
              </div>
            </GlassCard>
          </div>
        )}

        {activeTab === 'redemptions' && (
          <RedemptionManager />
        )}

        {activeTab === 'settings' && (
          <div className="space-y-6">
            {/* Withdrawal Settings */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">Withdrawal Settings</h3>
              <div className="space-y-4">
                <div className="flex items-center justify-between p-4 bg-white/5 rounded-xl">
                  <div>
                    <p className="text-white font-medium">Enable Withdrawals</p>
                    <p className="text-white/60 text-sm">Allow users to withdraw their funds</p>
                  </div>
                  <button
                    onClick={() => setWithdrawalsEnabled(!withdrawalsEnabled)}
                    className={cn(
                      'relative w-12 h-6 rounded-full transition-colors duration-300',
                      withdrawalsEnabled ? 'bg-green-500' : 'bg-red-500'
                    )}
                  >
                    <div
                      className={cn(
                        'absolute top-0.5 w-5 h-5 bg-white rounded-full transition-transform duration-300',
                        withdrawalsEnabled ? 'translate-x-6' : 'translate-x-0.5'
                      )}
                    />
                  </button>
                </div>
              </div>
            </GlassCard>

            {/* Security Settings */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">Security Settings</h3>
              <div className="space-y-4">
                <div className="p-4 bg-white/5 rounded-xl">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-white font-medium">Multi-sig Status</p>
                    <Lock className="w-5 h-5 text-green-400" />
                  </div>
                  <p className="text-white/60 text-sm">2 of 3 signatures required</p>
                </div>
                
                <div className="p-4 bg-white/5 rounded-xl">
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-white font-medium">Timelock</p>
                    <CheckCircle className="w-5 h-5 text-green-400" />
                  </div>
                  <p className="text-white/60 text-sm">24 hour delay on critical functions</p>
                </div>
              </div>
            </GlassCard>

            {/* Contract Addresses */}
            <GlassCard>
              <h3 className="text-lg font-semibold text-white mb-4">Contract Addresses</h3>
              <div className="space-y-3">
                <div className="p-3 bg-white/5 rounded-lg">
                  <p className="text-white/60 text-xs mb-1">BTC Vault Strategy</p>
                  <p className="text-white text-sm font-mono">{btcVaultStrategy}</p>
                </div>
                <div className="p-3 bg-white/5 rounded-lg">
                  <p className="text-white/60 text-xs mb-1">BTC Vault Token</p>
                  <p className="text-white text-sm font-mono">{btcVaultToken}</p>
                </div>
              </div>
            </GlassCard>
          </div>
        )}
      </div>
    </main>
  );
}