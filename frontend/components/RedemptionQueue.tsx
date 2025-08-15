'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI } from '@/lib/abis';

export function RedemptionQueue() {
  const { address } = useAccount();
  const [redeemAmount, setRedeemAmount] = useState('');

  const { writeContract: requestRedemption, data: requestHash } = useWriteContract();

  const { isLoading: isRequestPending } = useWaitForTransactionReceipt({
    hash: requestHash,
  });

  const { data: userBalance } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

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

  const handleRequestRedemption = async () => {
    if (!redeemAmount || !address) return;
    
    const amountInWei = parseUnits(redeemAmount, 18);
    
    // Direct redemption is disabled - users must use the signature-based redemption system
    // The redeem function requires 4 arguments and is admin-only
    console.log('Direct redemption not available. Please use the redemption request system.');
    
    setRedeemAmount('');
  };

  const balance = userBalance ? Number(formatUnits(userBalance, 18)) : 0;
  const liquidity = availableLiquidity ? Number(formatUnits(availableLiquidity, 8)) : 0;
  const tvl = totalAssets ? Number(formatUnits(totalAssets, 8)) : 0;
  const shares = totalSupply ? Number(formatUnits(totalSupply, 18)) : 0;
  const sharePrice = shares > 0 && totalAssets ? (tvl / shares) : 1;
  const redeemableValue = Number(redeemAmount) * sharePrice;

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-bold mb-4">Managed Withdrawals</h2>
      
      <div className="space-y-4">
        <div className="border-b pb-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <p className="text-sm text-gray-600">Available Liquidity</p>
              <p className="text-lg font-semibold">{liquidity.toFixed(4)} sovaBTC</p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Processing Time</p>
              <p className="text-lg font-semibold">Manager Approval</p>
            </div>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Request Withdrawal (btcVault shares)
          </label>
          <div className="flex space-x-2">
            <input
              type="number"
              step="0.01"
              className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              value={redeemAmount}
              onChange={(e) => setRedeemAmount(e.target.value)}
              placeholder="0.00"
              max={balance.toString()}
            />
            <button
              onClick={handleRequestRedemption}
              disabled={!redeemAmount || Number(redeemAmount) > balance || isRequestPending}
              className="bg-red-600 text-white py-2 px-4 rounded-md hover:bg-red-700 disabled:bg-gray-400 transition-colors"
            >
              {isRequestPending ? 'Requesting...' : 'Request Withdrawal'}
            </button>
          </div>
          <div className="mt-2 space-y-1">
            <p className="text-sm text-gray-500">
              Available: {balance.toFixed(4)} btcVault
            </p>
            {redeemAmount && (
              <p className="text-sm text-gray-500">
                Withdrawal Value: ~{redeemableValue.toFixed(6)} BTC
              </p>
            )}
          </div>
        </div>

        <div className="bg-yellow-50 border border-yellow-200 rounded-md p-4">
          <h3 className="font-semibold text-yellow-800 mb-2">Managed Withdrawal Process</h3>
          <ul className="text-sm text-yellow-700 space-y-1">
            <li>• Withdrawals require manager approval for processing</li>
            <li>• You will receive sovaBTC upon approval</li>
            <li>• Liquidity availability: {liquidity.toFixed(4)} sovaBTC</li>
            <li>• Contact support if your withdrawal is pending</li>
          </ul>
        </div>
      </div>
    </div>
  );
}