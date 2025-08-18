'use client';

import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useChainId } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';
import { ArrowDown, Wallet, TrendingUp, Lock, ChevronDown, Check, X } from 'lucide-react';
import toast, { Toaster } from 'react-hot-toast';
import { GlassCard, GlassCardHeader, GlassCardContent, GlassCardFooter } from '../../components/GlassCard';
import { VaultRedemption } from '../../components/VaultRedemptionSimple';
import { useDeploymentId } from '../../hooks/useDeploymentId';
import { CONTRACTS } from '../../lib/contracts';
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI, ERC20_ABI } from '../../lib/abis';
import { formatAddress, formatAmount } from '../../lib/utils';

const BTC_VAULT_TOKEN_ADDRESS = CONTRACTS.btcVaultToken;
const BTC_VAULT_STRATEGY_ADDRESS = CONTRACTS.btcVaultStrategy;

// Supported collateral types
const COLLATERAL_TYPES = [
  {
    symbol: 'WBTC',
    name: 'Wrapped BTC',
    address: CONTRACTS.wbtc,
    decimals: 8,
    icon: '🟠'
  },
  {
    symbol: 'TBTC',
    name: 'tBTC',
    address: CONTRACTS.tbtc,
    decimals: 18, // Note: Non-standard decimals!
    icon: '🟢'
  },
  {
    symbol: 'sovaBTC',
    name: 'Sova BTC',
    address: CONTRACTS.sovaBTC,
    decimals: 8,
    icon: '🔵'
  }
];

// ERC20_ABI is already imported above from lib/abis

export default function VaultPage() {
  const [activeTab, setActiveTab] = useState<'deposit' | 'redeem'>('deposit');
  const [amount, setAmount] = useState('');
  const [selectedCollateral, setSelectedCollateral] = useState(COLLATERAL_TYPES[0]);
  const [showCollateralDropdown, setShowCollateralDropdown] = useState(false);
  const [hasApprovedInSession, setHasApprovedInSession] = useState(false);
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { deploymentId, isLoading: isLoadingDeployment } = useDeploymentId();

  // Contract reads - Vault metrics
  const { data: totalAssets } = useReadContract({
    address: BTC_VAULT_TOKEN_ADDRESS,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalAssets',
  });

  const { data: totalSupply } = useReadContract({
    address: BTC_VAULT_TOKEN_ADDRESS,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'totalSupply',
  });

  const { data: userShares, refetch: refetchShares } = useReadContract({
    address: BTC_VAULT_TOKEN_ADDRESS,
    abi: BTC_VAULT_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // Check available liquidity in strategy for withdrawals
  const { data: availableLiquidity } = useReadContract({
    address: BTC_VAULT_STRATEGY_ADDRESS,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'availableLiquidity',
  });

  // Check if collateral is supported
  const { data: isSupported } = useReadContract({
    address: BTC_VAULT_STRATEGY_ADDRESS,
    abi: BTC_VAULT_STRATEGY_ABI,
    functionName: 'isSupportedAsset',
    args: [selectedCollateral.address],
  });

  // Get collateral balance
  const { data: collateralBalance, refetch: refetchBalance } = useReadContract({
    address: selectedCollateral.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // Get allowance
  const { data: allowance, error: allowanceError, refetch: refetchAllowance } = useReadContract({
    address: selectedCollateral.address,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, BTC_VAULT_TOKEN_ADDRESS] : undefined, // Changed to TOKEN address
  });

  // Refetch allowance when selected collateral changes
  useEffect(() => {
    if (selectedCollateral && address) {
      refetchAllowance();
      refetchBalance();
      // Reset approval session flag when changing collateral
      setHasApprovedInSession(false);
    }
  }, [selectedCollateral, address, refetchAllowance, refetchBalance]);

  // Preview deposit
  const { data: previewShares } = useReadContract({
    address: BTC_VAULT_TOKEN_ADDRESS, // Changed to TOKEN
    abi: BTC_VAULT_TOKEN_ABI, // Changed ABI
    functionName: 'previewDepositCollateral',
    args: amount && selectedCollateral ? 
      [selectedCollateral.address, parseUnits(amount || '0', selectedCollateral.decimals)] : 
      undefined,
  });

  // Contract writes with error handling
  const { writeContract: approve, data: approveHash, error: approveError } = useWriteContract();
  const { writeContract: deposit, data: depositHash, error: depositError } = useWriteContract();

  // Transaction receipts
  const { isLoading: isApproving, isSuccess: approveSuccess } = useWaitForTransactionReceipt({
    hash: approveHash,
  });

  const { isLoading: isDepositing, isSuccess: depositSuccess } = useWaitForTransactionReceipt({
    hash: depositHash,
  });

  // Show success/error messages for approval
  useEffect(() => {
    if (approveSuccess && !hasApprovedInSession) {
      toast.success('Approval successful! You can now deposit.');
      setHasApprovedInSession(true);
      // Refetch allowance after approval
      refetchAllowance();
      // DO NOT auto-trigger deposit - user must click deposit button
    }
  }, [approveSuccess, hasApprovedInSession, refetchAllowance]);

  useEffect(() => {
    if (approveError) {
      console.error('Approval error:', approveError);
      const errorMessage = approveError.message?.includes('User rejected')
        ? 'Transaction rejected by user'
        : 'Approval failed. Please try again.';
      toast.error(errorMessage);
    }
  }, [approveError]);

  useEffect(() => {
    if (depositSuccess) {
      toast.success('Deposit successful!');
      setAmount('');
      setHasApprovedInSession(false);
      // Refetch balances after successful deposit
      refetchBalance();
      refetchShares();
      refetchAllowance();
    }
  }, [depositSuccess, refetchBalance, refetchShares, refetchAllowance]);

  useEffect(() => {
    if (depositError) {
      console.error('Deposit error:', depositError);
      const errorMessage = depositError.message?.includes('User rejected')
        ? 'Transaction rejected by user'
        : depositError.message?.includes('insufficient')
        ? 'Insufficient balance or allowance'
        : 'Deposit failed. Please try again.';
      toast.error(errorMessage);
    }
  }, [depositError]);


  const handleDeposit = async () => {
    try {
      if (!amount || parseFloat(amount) <= 0) {
        toast.error('Please enter a valid amount');
        return;
      }

      if (!isSupported) {
        toast.error(`${selectedCollateral.symbol} is not supported`);
        return;
      }

      const amountWei = parseUnits(amount, selectedCollateral.decimals);
      
      // Check balance
      if (!collateralBalance || collateralBalance < amountWei) {
        toast.error('Insufficient balance');
        return;
      }

      // Check if approval is needed
      const needsApproval = allowance !== undefined && allowance < amountWei;
      
      if (needsApproval && !isApproving) {
        toast.loading('Please approve the transaction...', { duration: 2000 });
        // Use max approval for better UX
        const maxApproval = BigInt(2) ** BigInt(256) - BigInt(1);
        await approve({
          address: selectedCollateral.address,
          abi: ERC20_ABI,
          functionName: 'approve',
          args: [BTC_VAULT_TOKEN_ADDRESS, maxApproval], // Use max approval
        });
      } else if (!needsApproval && !isDepositing) {
        toast.loading('Processing deposit...', { duration: 2000 });
        await deposit({
          address: BTC_VAULT_TOKEN_ADDRESS, // Changed from STRATEGY to TOKEN
          abi: BTC_VAULT_TOKEN_ABI, // Changed ABI
          functionName: 'depositCollateral',
          args: [selectedCollateral.address, amountWei, address!],
        });
      }
    } catch (error) {
      console.error('Deposit handler error:', error);
      // Error will be handled by useEffect watching depositError
    }
  };

  const handleWithdraw = async () => {
    // Withdrawals are managed by strategy - users cannot directly withdraw
    toast.error('Withdrawals are processed by the vault manager. Please contact support to request a withdrawal.');
  };

  const handleMaxDeposit = () => {
    if (collateralBalance) {
      setAmount(formatUnits(collateralBalance, selectedCollateral.decimals));
    }
  };

  const handleMaxWithdraw = () => {
    if (userShares) {
      setAmount(formatUnits(userShares, 18));
    }
  };

  // Calculate values (totalAssets is in 8 decimals, totalSupply is in 18 decimals)
  const sharePrice = totalSupply && totalAssets && totalSupply > 0n
    ? (Number(formatUnits(totalAssets, 8)) / Number(formatUnits(totalSupply, 18)))
    : 1;

  const userBTCValue = userShares && totalAssets && totalSupply && totalSupply > 0n
    ? (Number(formatUnits(userShares, 18)) * Number(formatUnits(totalAssets, 8))) / Number(formatUnits(totalSupply, 18))
    : 0;

  return (
    <div className="min-h-screen">
      <Toaster 
        position="bottom-right"
        toastOptions={{
          duration: 4000,
          style: {
            background: 'rgba(15, 23, 42, 0.9)',
            color: '#fff',
            border: '1px solid rgba(255, 255, 255, 0.1)',
            borderRadius: '12px',
            backdropFilter: 'blur(10px)',
            boxShadow: '0 8px 32px 0 rgba(31, 38, 135, 0.37)',
          },
          success: {
            iconTheme: {
              primary: '#10b981',
              secondary: '#fff',
            },
          },
          error: {
            iconTheme: {
              primary: '#ef4444',
              secondary: '#fff',
            },
          },
        }}
      />

      {/* Main Content */}
      <main className="relative z-10 container mx-auto px-4 sm:px-6 py-6 sm:py-8">
        <div className="max-w-4xl mx-auto space-y-8">

          {/* Vault Overview Card */}
          <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10">
            <div className="p-6 sm:p-8">
              <h1 className="text-3xl font-bold text-white mb-2">stSOVABTC Vault</h1>
              <p className="text-white/60 mb-8">Deposit BTC variants to earn sustainable yield from DeFi strategies</p>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white/5 backdrop-blur-md rounded-xl p-6 border border-white/10">
                  <p className="text-white/60 text-sm mb-1">Total Value Locked</p>
                  <p className="text-2xl font-bold text-white">
                    {totalAssets ? formatUnits(totalAssets, 8) : '0'} BTC
                  </p>
                  <p className="text-white/60 text-sm">Across all collateral types</p>
                </div>
                <div className="bg-white/5 backdrop-blur-md rounded-xl p-6 border border-white/10">
                  <p className="text-white/60 text-sm mb-1">Share Price</p>
                  <p className="text-2xl font-bold text-green-400">{sharePrice.toFixed(4)}</p>
                  <p className="text-white/60 text-sm">BTC per share</p>
                </div>
                <div className="bg-white/5 backdrop-blur-md rounded-xl p-6 border border-white/10">
                  <p className="text-white/60 text-sm mb-1">Your Position</p>
                  <p className="text-2xl font-bold text-white">{userBTCValue.toFixed(6)} BTC</p>
                  <p className="text-white/60 text-sm">{userShares ? formatUnits(userShares, 18) : '0'} stSOVABTC</p>
                </div>
              </div>
            </div>
          </div>

          {/* Main Vault Interface */}
          <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10">
            {/* Tab Navigation */}
            <div className="flex border-b border-white/10">
              <button
                onClick={() => setActiveTab('deposit')}
                className={`flex-1 px-6 py-4 text-center font-semibold transition-all ${
                  activeTab === 'deposit'
                    ? 'tab-active text-white'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`}
              >
                Deposit
              </button>
              <button
                onClick={() => setActiveTab('redeem')}
                className={`flex-1 px-6 py-4 text-center font-semibold transition-all ${
                  activeTab === 'redeem'
                    ? 'tab-active text-white'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
                }`}
              >
                Withdraw
              </button>
            </div>

            {/* Form Content */}
            <div className="p-6 sm:p-8">
              {!isConnected ? (
                <div className="text-center py-12">
                  <Wallet className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                  <h3 className="text-xl font-semibold text-white mb-2">
                    Connect Wallet
                  </h3>
                  <p className="text-gray-400">
                    Please connect your wallet to access the vault
                  </p>
                </div>
              ) : activeTab === 'deposit' ? (
                <div className="space-y-6">
                  {/* Collateral Selector */}
                  <div>
                    <label className="form-label">Select Collateral</label>
                    <div className="relative">
                      <button
                        onClick={() => setShowCollateralDropdown(!showCollateralDropdown)}
                        className="w-full glass-input rounded-lg px-4 py-3 flex items-center justify-between hover:bg-white/10 transition-all"
                      >
                        <div className="flex items-center gap-3">
                          <span className="text-2xl">{selectedCollateral.icon}</span>
                          <div className="text-left">
                            <p className="text-white font-medium">{selectedCollateral.symbol}</p>
                            <p className="text-xs text-gray-400">{selectedCollateral.name}</p>
                          </div>
                        </div>
                        <ChevronDown className={`w-5 h-5 text-gray-400 transition-transform ${
                          showCollateralDropdown ? 'rotate-180' : ''
                        }`} />
                      </button>

                      {/* Dropdown */}
                      {showCollateralDropdown && (
                        <div className="absolute top-full left-0 right-0 mt-2 bg-slate-900 backdrop-blur-xl border border-white/10 rounded-lg shadow-xl overflow-hidden z-20">
                          {COLLATERAL_TYPES.map((collateral) => (
                            <button
                              key={collateral.address}
                              onClick={() => {
                                setSelectedCollateral(collateral);
                                setShowCollateralDropdown(false);
                                setAmount('');
                                setHasApprovedInSession(false);
                              }}
                              className="w-full px-4 py-3 flex items-center justify-between hover:bg-white/10 transition-all"
                            >
                              <div className="flex items-center gap-3">
                                <span className="text-2xl">{collateral.icon}</span>
                                <div className="text-left">
                                  <p className="text-white font-medium">{collateral.symbol}</p>
                                  <p className="text-xs text-gray-400">{collateral.name}</p>
                                </div>
                              </div>
                              {selectedCollateral.address === collateral.address && (
                                <Check className="w-5 h-5 text-green-400" />
                              )}
                            </button>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Amount Input */}
                  <div>
                    <div className="flex justify-between items-center mb-2">
                      <label className="form-label">Amount</label>
                      <div className="text-sm text-gray-400">
                        Balance: {collateralBalance ? formatUnits(collateralBalance, selectedCollateral.decimals) : '0'} {selectedCollateral.symbol}
                      </div>
                    </div>
                    <div className="relative">
                      <input
                        type="number"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        placeholder="0.00"
                        className="form-input pr-20"
                        disabled={isApproving || isDepositing}
                      />
                      <button
                        onClick={handleMaxDeposit}
                        disabled={isApproving || isDepositing}
                        className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-1 text-xs font-medium text-blue-400 hover:text-blue-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        MAX
                      </button>
                    </div>
                  </div>

                  {/* Preview */}
                  {amount && parseFloat(amount) > 0 && (
                    <div className="bg-white/5 backdrop-blur-xl rounded-lg border border-white/10 p-4 space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-gray-400">You will receive</span>
                        <span className="text-white font-medium">
                          {previewShares ? formatUnits(previewShares, 18) : '...'} stSOVABTC
                        </span>
                      </div>
                      {allowance !== undefined && (
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-gray-400">Current Allowance</span>
                          <span className="text-white">
                            {formatUnits(allowance, selectedCollateral.decimals)} {selectedCollateral.symbol}
                          </span>
                        </div>
                      )}
                    </div>
                  )}

                  {/* Deposit Button */}
                  {(() => {
                    const amountWei = amount ? parseUnits(amount || '0', selectedCollateral.decimals) : 0n;
                    const needsApproval = allowance !== undefined && amountWei > allowance;
                    const hasBalance = collateralBalance && amountWei <= collateralBalance;
                    
                    return (
                      <button
                        onClick={handleDeposit}
                        disabled={!amount || parseFloat(amount) <= 0 || isApproving || isDepositing || !isSupported || !hasBalance}
                        className="btn-primary w-full disabled:opacity-50 disabled:cursor-not-allowed"
                      >
                        {isApproving ? 'Approving...' : 
                         isDepositing ? 'Depositing...' : 
                         !isSupported ? 'Collateral Not Supported' :
                         !hasBalance ? 'Insufficient Balance' :
                         needsApproval ? 'Approve & Deposit' : 
                         'Deposit'}
                      </button>
                    );
                  })()}

                  {/* Warning for unsupported collateral */}
                  {selectedCollateral && isSupported === false && (
                    <div className="p-4 rounded-lg bg-red-500/20 border border-red-500/50">
                      <p className="text-red-400 text-sm">
                        {selectedCollateral.symbol} is not currently supported. Please select another collateral type.
                      </p>
                    </div>
                  )}
                </div>
              ) : (
                <div className="space-y-6">
                  {/* Notice about new redemption system */}
                  <div className="p-4 rounded-lg bg-mint-500/20 border border-mint-500/50">
                    <p className="text-mint-400 text-sm font-medium mb-2">
                      EIP-712 Signature-Based Withdrawal System
                    </p>
                    <p className="text-mint-300 text-xs">
                      Submit withdrawal requests using cryptographic signatures. Your requests will be queued and processed by vault administrators.
                    </p>
                  </div>
                  
                  {/* Embedded withdrawal interface */}
                  <div className="space-y-4">
                    <div>
                      <div className="flex justify-between items-center mb-2">
                        <label className="form-label">Withdrawal Amount</label>
                        <div className="text-sm text-gray-400">
                          Available: {userShares ? formatUnits(userShares, 18) : '0'} stSOVABTC
                        </div>
                      </div>
                      <div className="relative">
                        <input
                          type="number"
                          value={amount}
                          onChange={(e) => setAmount(e.target.value)}
                          placeholder="0.00"
                          className="form-input pr-20"
                        />
                        <button
                          onClick={handleMaxWithdraw}
                          className="absolute right-2 top-1/2 -translate-y-1/2 px-3 py-1 text-xs font-medium text-mint-400 hover:text-mint-300 transition-colors"
                        >
                          MAX
                        </button>
                      </div>
                    </div>
                    
                    {/* Preview */}
                    {amount && parseFloat(amount) > 0 && (
                      <div className="bg-white/5 backdrop-blur-xl rounded-lg border border-white/10 p-4 space-y-2">
                        <div className="flex items-center justify-between">
                          <span className="text-gray-400">You will receive (approx.)</span>
                          <span className="text-white font-medium">
                            {(parseFloat(amount) * sharePrice).toFixed(6)} BTC
                          </span>
                        </div>
                        <div className="flex items-center justify-between text-sm">
                          <span className="text-gray-400">Processing time</span>
                          <span className="text-yellow-400">1-3 business days</span>
                        </div>
                      </div>
                    )}
                    
                    {/* Withdrawal button */}
                    <button
                      onClick={() => setActiveTab('redeem')} // This will be updated to handle withdrawal
                      disabled={!amount || parseFloat(amount) <= 0}
                      className="btn-primary w-full bg-mint-600 hover:bg-mint-700 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Request Withdrawal
                    </button>
                    
                    <div className="text-center">
                      <p className="text-gray-400 text-sm">
                        For large withdrawals or immediate processing, please contact support
                      </p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* EIP-712 Signature-Based Redemption System - Advanced Interface */}
          <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10">
            <div className="p-6 sm:p-8">
              <h3 className="text-xl font-semibold text-white mb-4">Advanced Withdrawal Interface</h3>
              <p className="text-white/60 mb-6">Use the full EIP-712 signature-based withdrawal system for advanced features and tracking.</p>
              
              {deploymentId && !isLoadingDeployment ? (
                <VaultRedemption
                  vaultAddress={BTC_VAULT_TOKEN_ADDRESS as `0x${string}`}
                  deploymentId={deploymentId}
                  chainId={chainId}
                />
              ) : (
                <div className="text-center py-8 text-gray-400">
                  {isLoadingDeployment ? 'Loading deployment configuration...' : 'No deployment found for this network'}
                </div>
              )}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}