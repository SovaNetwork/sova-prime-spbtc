'use client';

import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatUnits, parseUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI, ERC20_ABI } from '@/lib/abis';
import { CollateralManager } from './admin/CollateralManager';
import { RedemptionManager } from './admin/RedemptionManager';

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

interface AdminPanelProps {
  className?: string;
}

export function AdminPanel({ className = '' }: AdminPanelProps) {
  const { address } = useAccount();
  const [activeTab, setActiveTab] = useState<'collateral' | 'liquidity' | 'withdrawals' | 'analytics'>('collateral');
  
  // Collateral management state
  const [newCollateralAddress, setNewCollateralAddress] = useState('');
  const [newCollateralDecimals, setNewCollateralDecimals] = useState('8');
  const [removeCollateralAddress, setRemoveCollateralAddress] = useState('');
  
  // Liquidity management state
  const [liquidityAmount, setLiquidityAmount] = useState('');
  const [isAddingLiquidity, setIsAddingLiquidity] = useState(true);
  

  // Check if user is admin
  const { data: protocolAdminRole } = useReadContract({
    address: CONTRACTS.roleManager as `0x${string}`,
    abi: ROLE_MANAGER_ABI,
    functionName: 'PROTOCOL_ADMIN',
  });

  const { data: isAdmin } = useReadContract({
    address: CONTRACTS.roleManager as `0x${string}`,
    abi: ROLE_MANAGER_ABI,
    functionName: 'hasAllRoles',
    args: address && protocolAdminRole ? [address, protocolAdminRole] : undefined,
  });

  // Read strategy data
  const { data: availableLiquidity } = useReadContract({
    address: CONTRACTS.btcVaultStrategy as `0x${string}`,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'availableLiquidity',
  });

  const { data: totalAssets } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalAssets',
  });

  const { data: totalSupply } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalSupply',
  });

  // Write functions
  const { writeContract, data: txHash } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash: txHash });

  // Add collateral
  const handleAddCollateral = async () => {
    if (!newCollateralAddress) return;
    
    try {
      await writeContract({
        address: CONTRACTS.btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'addCollateral',
        args: [newCollateralAddress as `0x${string}`, Number(newCollateralDecimals)],
      });
      setNewCollateralAddress('');
    } catch (error) {
      console.error('Error adding collateral:', error);
    }
  };

  // Remove collateral
  const handleRemoveCollateral = async () => {
    if (!removeCollateralAddress) return;
    
    try {
      await writeContract({
        address: CONTRACTS.btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'removeCollateral',
        args: [removeCollateralAddress as `0x${string}`],
      });
      setRemoveCollateralAddress('');
    } catch (error) {
      console.error('Error removing collateral:', error);
    }
  };

  // Add liquidity
  const handleAddLiquidity = async () => {
    if (!liquidityAmount) return;
    
    const amount = parseUnits(liquidityAmount, 8);
    
    try {
      await writeContract({
        address: CONTRACTS.btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'addLiquidity',
        args: [amount],
      });
      setLiquidityAmount('');
    } catch (error) {
      console.error('Error adding liquidity:', error);
    }
  };

  // Remove liquidity
  const handleRemoveLiquidity = async () => {
    if (!liquidityAmount) return;
    
    const amount = parseUnits(liquidityAmount, 8);
    
    try {
      await writeContract({
        address: CONTRACTS.btcVaultStrategy as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'removeLiquidity',
        args: [amount, address as `0x${string}`],
      });
      setLiquidityAmount('');
    } catch (error) {
      console.error('Error removing liquidity:', error);
    }
  };


  if (!isAdmin) {
    return (
      <div className={`glass-card rounded-xl p-6 ${className}`}>
        <h2 className="text-xl font-bold mb-4 text-white">Admin Panel</h2>
        <p className="text-gray-400">You must be an admin to access this panel.</p>
      </div>
    );
  }

  const liquidity = availableLiquidity ? Number(formatUnits(availableLiquidity, 8)) : 0;
  const tvl = totalAssets ? Number(formatUnits(totalAssets, 8)) : 0;
  const shares = totalSupply ? Number(formatUnits(totalSupply, 18)) : 0;

  return (
    <div className={`glass-card rounded-xl p-6 ${className}`}>
      <h2 className="text-xl font-bold mb-4 text-white">Admin Panel</h2>
      
      <div className="mb-4">
        <div className="border-b border-white/10">
          <nav className="-mb-px flex space-x-8">
            <button
              onClick={() => setActiveTab('collateral')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'collateral' 
                  ? 'border-blue-500 text-blue-400' 
                  : 'border-transparent text-gray-400 hover:text-white hover:border-gray-500'
              }`}
            >
              Collateral
            </button>
            <button
              onClick={() => setActiveTab('liquidity')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'liquidity' 
                  ? 'border-blue-500 text-blue-400' 
                  : 'border-transparent text-gray-400 hover:text-white hover:border-gray-500'
              }`}
            >
              Liquidity
            </button>
            <button
              onClick={() => setActiveTab('withdrawals')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'withdrawals' 
                  ? 'border-blue-500 text-blue-400' 
                  : 'border-transparent text-gray-400 hover:text-white hover:border-gray-500'
              }`}
            >
              Redemptions
            </button>
            <button
              onClick={() => setActiveTab('analytics')}
              className={`py-2 px-1 border-b-2 font-medium text-sm ${
                activeTab === 'analytics' 
                  ? 'border-blue-500 text-blue-400' 
                  : 'border-transparent text-gray-400 hover:text-white hover:border-gray-500'
              }`}
            >
              Analytics
            </button>
          </nav>
        </div>
      </div>

      <div className="mt-6">
        {activeTab === 'collateral' && (
          <CollateralManager />
        )}

        {activeTab === 'liquidity' && (
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-white">Liquidity Management</h3>
            
            <div className="glass-card-light rounded-lg p-4">
              <p className="text-sm text-gray-400">Current Available Liquidity</p>
              <p className="text-2xl font-bold text-white">{liquidity.toFixed(4)} sovaBTC</p>
            </div>

            <div className="glass-card-light border border-white/10 rounded-lg p-4">
              <div className="flex space-x-2 mb-3">
                <button
                  onClick={() => setIsAddingLiquidity(true)}
                  className={`flex-1 py-2 px-4 rounded-md ${
                    isAddingLiquidity 
                      ? 'bg-blue-600 text-white' 
                      : 'bg-white/10 text-gray-300 hover:bg-white/20'
                  }`}
                >
                  Add Liquidity
                </button>
                <button
                  onClick={() => setIsAddingLiquidity(false)}
                  className={`flex-1 py-2 px-4 rounded-md ${
                    !isAddingLiquidity 
                      ? 'bg-blue-600 text-white' 
                      : 'bg-white/10 text-gray-300 hover:bg-white/20'
                  }`}
                >
                  Remove Liquidity
                </button>
              </div>
              
              <div className="space-y-2">
                <input
                  type="number"
                  step="0.01"
                  placeholder="Amount of sovaBTC"
                  className="form-input"
                  value={liquidityAmount}
                  onChange={(e) => setLiquidityAmount(e.target.value)}
                />
                <button
                  onClick={isAddingLiquidity ? handleAddLiquidity : handleRemoveLiquidity}
                  disabled={!liquidityAmount || isConfirming}
                  className={`w-full ${
                    isAddingLiquidity ? 'btn-primary' : 'bg-red-600 hover:bg-red-700 text-white py-2 px-4 rounded-md'
                  } disabled:opacity-50 disabled:cursor-not-allowed`}
                >
                  {isConfirming ? 'Processing...' : isAddingLiquidity ? 'Add Liquidity' : 'Remove Liquidity'}
                </button>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'withdrawals' && (
          <RedemptionManager />
        )}

        {activeTab === 'analytics' && (
          <div className="space-y-4">
            <h3 className="text-lg font-semibold text-white">System Analytics</h3>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="glass-card-light rounded-lg p-4">
                <p className="text-sm text-gray-400">Total Value Locked</p>
                <p className="text-xl font-bold text-white">{tvl.toFixed(4)} BTC</p>
              </div>
              
              <div className="glass-card-light rounded-lg p-4">
                <p className="text-sm text-gray-400">Total Shares</p>
                <p className="text-xl font-bold text-white">{shares.toFixed(2)} stSOVABTC</p>
              </div>
              
              <div className="glass-card-light rounded-lg p-4">
                <p className="text-sm text-gray-400">Share Price</p>
                <p className="text-xl font-bold text-green-400">{shares > 0 ? (tvl / shares).toFixed(6) : '1.000000'} BTC</p>
              </div>
            </div>
            
            <div className="glass-card-light rounded-lg p-4">
              <h4 className="font-medium mb-2 text-white">Liquidity Status</h4>
              <div className="space-y-1">
                <p className="text-sm text-gray-300">Available: {liquidity.toFixed(4)} sovaBTC</p>
                <p className="text-sm text-gray-300">Utilization: {tvl > 0 ? ((1 - liquidity / tvl) * 100).toFixed(2) : '0.00'}%</p>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}