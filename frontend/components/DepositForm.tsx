'use client';

import { useState, useEffect, useMemo } from 'react';
import { useAccount, useWriteContract, useReadContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI, ERC20_ABI } from '@/lib/abis';
import { useActiveCollaterals } from '@/hooks/useCollaterals';

// Fallback collaterals for when database is unavailable
const FALLBACK_COLLATERALS = [
  { symbol: 'WBTC', address: CONTRACTS.wbtc, decimals: 8, name: 'Wrapped BTC' },
  { symbol: 'TBTC', address: CONTRACTS.tbtc, decimals: 18, name: 'tBTC' }, // Note: 18 decimals!
  { symbol: 'sovaBTC', address: CONTRACTS.sovaBTC, decimals: 8, name: 'Sova BTC' },
];

export function DepositForm() {
  const { address, chain } = useAccount();
  const { data: collaterals, isLoading: collateralsLoading } = useActiveCollaterals();
  
  // Use dynamic collaterals from database, fallback to hardcoded if unavailable
  const availableCollaterals = collaterals && collaterals.length > 0 
    ? collaterals.map(c => ({
        symbol: c.symbol,
        address: c.address,
        decimals: c.decimals,
        name: c.name,
        logoUri: c.logoUri,
      }))
    : FALLBACK_COLLATERALS;

  const [selectedToken, setSelectedToken] = useState(availableCollaterals[0]);
  const [amount, setAmount] = useState('');
  const [isApproving, setIsApproving] = useState(false);
  
  // Update selected token when collaterals load or chain changes
  useEffect(() => {
    if (availableCollaterals.length > 0 && !availableCollaterals.find(t => t.address === selectedToken?.address)) {
      setSelectedToken(availableCollaterals[0]);
    }
  }, [availableCollaterals, selectedToken?.address]);

  const { writeContract: approve, data: approveHash } = useWriteContract();
  const { writeContract: deposit, data: depositHash } = useWriteContract();

  const { isLoading: isApprovalPending, isSuccess: isApprovalSuccess } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  const { isLoading: isDepositPending, isSuccess: isDepositSuccess } = useWaitForTransactionReceipt({
    hash: depositHash,
  });

  const { data: tokenBalance } = useReadContract({
    address: selectedToken.address as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: allowance } = useReadContract({
    address: selectedToken.address as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.btcVaultToken as `0x${string}`] : undefined,
  });

  const { data: previewShares } = useReadContract({
    address: CONTRACTS.btcVaultToken as `0x${string}`,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'previewDepositCollateral',
    args: amount && selectedToken ? [selectedToken.address as `0x${string}`, parseUnits(amount, selectedToken.decimals)] : undefined,
  });

  const { data: isCollateralSupported, error: supportError } = useReadContract({
    address: CONTRACTS.btcVaultStrategy as `0x${string}`,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'isSupportedAsset',
    args: selectedToken ? [selectedToken.address as `0x${string}`] : undefined,
  });

  // Alternative check using getSupportedCollaterals
  const { data: supportedCollaterals } = useReadContract({
    address: CONTRACTS.btcVaultStrategy as `0x${string}`,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'getSupportedCollaterals',
  });

  // Use alternative check if the main check fails
  const isSupported = useMemo(() => {
    if (isCollateralSupported !== undefined) {
      return isCollateralSupported;
    }
    // Fallback to checking the array
    if (supportedCollaterals && selectedToken) {
      return supportedCollaterals.some((addr: string) => 
        addr.toLowerCase() === selectedToken.address.toLowerCase()
      );
    }
    return false;
  }, [isCollateralSupported, supportedCollaterals, selectedToken]);

  // Debug logging
  useEffect(() => {
    if (selectedToken) {
      console.log('Selected token:', selectedToken);
      console.log('Strategy address:', CONTRACTS.btcVaultStrategy);
      console.log('Is supported result:', isCollateralSupported);
      console.log('Supported collaterals array:', supportedCollaterals);
      console.log('Final isSupported:', isSupported);
      console.log('Support check error:', supportError);
    }
  }, [selectedToken, isCollateralSupported, supportedCollaterals, isSupported, supportError]);

  // Reset approval state when approval succeeds
  useEffect(() => {
    if (isApprovalSuccess) {
      setIsApproving(false);
    }
  }, [isApprovalSuccess]);

  // Reset amount after successful deposit
  useEffect(() => {
    if (isDepositSuccess) {
      setAmount('');
    }
  }, [isDepositSuccess]);

  const handleMint = async () => {
    if (!address) return;
    
    const mintAmount = parseUnits('1', selectedToken.decimals);
    await approve({
      address: selectedToken.address as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'mint',
      args: [mintAmount],
    });
  };

  const handleApprove = async () => {
    if (!amount || !address) return;
    
    setIsApproving(true);
    // Approve max uint256 for better UX (don't need to approve every time)
    const maxApproval = BigInt(2) ** BigInt(256) - BigInt(1);
    
    console.log('Approving token:', selectedToken.address);
    console.log('Spender (vault):', CONTRACTS.btcVaultToken);
    console.log('Amount:', maxApproval.toString());
    
    await approve({
      address: selectedToken.address as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [CONTRACTS.btcVaultToken as `0x${string}`, maxApproval],
    });
  };

  const handleDeposit = async () => {
    if (!amount || !address) return;
    
    try {
      const amountInWei = parseUnits(amount, selectedToken.decimals);
      
      console.log('=== Initiating Deposit ===');
      console.log('Token address:', selectedToken.address);
      console.log('Amount:', amount, selectedToken.symbol);
      console.log('Amount in wei:', amountInWei.toString());
      console.log('Vault address:', CONTRACTS.btcVaultToken);
      console.log('Receiver:', address);
      
      const result = await deposit({
        address: CONTRACTS.btcVaultToken as `0x${string}`,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'depositCollateral',
        args: [selectedToken.address as `0x${string}`, amountInWei, address],
      });
      
      console.log('Deposit transaction initiated:', result);
    } catch (error) {
      console.error('Deposit error:', error);
    }
  };

  const balance = tokenBalance ? Number(formatUnits(tokenBalance, selectedToken.decimals)) : 0;
  const approved = allowance ? Number(formatUnits(allowance, selectedToken.decimals)) : 0;
  const needsApproval = amount ? Number(amount) > approved : false;
  const expectedShares = previewShares ? Number(formatUnits(previewShares, 18)) : 0;

  // Debug allowance
  useEffect(() => {
    if (amount && selectedToken) {
      console.log('Current allowance:', approved, selectedToken.symbol);
      console.log('Amount to deposit:', Number(amount));
      console.log('Needs approval?', needsApproval);
    }
  }, [amount, approved, needsApproval, selectedToken]);

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="text-xl font-bold mb-4">Deposit Collateral</h2>
      
      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Select Collateral Token
          </label>
          <select
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={selectedToken?.address || ''}
            onChange={(e) => {
              const token = availableCollaterals.find(t => t.address === e.target.value);
              if (token) setSelectedToken(token);
            }}
            disabled={collateralsLoading}
          >
            {collateralsLoading && (
              <option value="">Loading collaterals...</option>
            )}
            {!collateralsLoading && availableCollaterals.map((token) => (
              <option key={token.address} value={token.address}>
                {token.symbol} - {token.name}
              </option>
            ))}
          </select>
          <p className="text-sm text-gray-500 mt-1">
            Balance: {balance.toFixed(6)} {selectedToken?.symbol || ''}
          </p>
          {chain && !collateralsLoading && availableCollaterals.length === 0 && (
            <p className="text-sm text-yellow-600 mt-1">
              No collaterals available for {chain.name}. Using fallback list.
            </p>
          )}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Amount (min 0.001 BTC)
          </label>
          <input
            type="number"
            step="0.0001"
            min="0.001"
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.001"
          />
          {amount && expectedShares > 0 && (
            <p className="text-sm text-gray-500 mt-1">
              Expected shares: {expectedShares.toFixed(6)} btcVault
            </p>
          )}
          {selectedToken && !isSupported && (
            <p className="text-sm text-red-500 mt-1">
              This collateral is not currently supported
            </p>
          )}
        </div>

        <div className="space-y-2">
          {balance === 0 && (
            <button
              onClick={handleMint}
              className="w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 transition-colors"
            >
              Mint Test Tokens
            </button>
          )}
          
          {needsApproval && amount && !isApprovalPending && !isApprovalSuccess && (
            <button
              onClick={handleApprove}
              disabled={isApproving}
              className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 disabled:bg-gray-400 transition-colors"
            >
              {isApproving ? 'Approving...' : 'Approve Tokens'}
            </button>
          )}

          {isApprovalPending && (
            <div className="w-full bg-yellow-100 text-yellow-800 py-2 px-4 rounded-md text-center">
              Waiting for approval confirmation...
            </div>
          )}
          
          {(!needsApproval || isApprovalSuccess) && amount && (
            <button
              onClick={handleDeposit}
              disabled={!amount || isDepositPending || Number(amount) < 0.001 || !isSupported || balance < Number(amount)}
              className="w-full bg-indigo-600 text-white py-2 px-4 rounded-md hover:bg-indigo-700 disabled:bg-gray-400 transition-colors"
            >
              {isDepositPending ? 'Depositing...' : 
               balance < Number(amount) ? 'Insufficient Balance' : 'Deposit'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}