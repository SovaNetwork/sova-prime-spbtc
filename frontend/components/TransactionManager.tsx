'use client';

import { useState, useEffect } from 'react';
import { useWaitForTransactionReceipt, usePublicClient, useChainId } from 'wagmi';
import { formatEther, formatUnits } from 'viem';
import { useExplorerUrl } from '@/hooks/useNetworkContracts';
import { getErrorMessage } from '@/lib/errors';
import { 
  Loader2, 
  CheckCircle, 
  XCircle, 
  ExternalLink, 
  AlertCircle,
  Clock,
  Fuel
} from 'lucide-react';
import { cn } from '@/lib/utils';

export interface Transaction {
  hash: string;
  description: string;
  status: 'pending' | 'success' | 'error';
  error?: string;
  timestamp: number;
  gasUsed?: bigint;
  effectiveGasPrice?: bigint;
}

interface TransactionManagerProps {
  transaction?: {
    hash?: `0x${string}`;
    description: string;
  };
  onSuccess?: () => void;
  onError?: (error: any) => void;
  showGasEstimate?: boolean;
}

export function TransactionManager({ 
  transaction, 
  onSuccess, 
  onError,
  showGasEstimate = true 
}: TransactionManagerProps) {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [gasPrice, setGasPrice] = useState<bigint | null>(null);
  const publicClient = usePublicClient();
  const chainId = useChainId();
  const explorer = useExplorerUrl();

  // Get current gas price
  useEffect(() => {
    const fetchGasPrice = async () => {
      if (!publicClient) return;
      try {
        const price = await publicClient.getGasPrice();
        setGasPrice(price);
      } catch (error) {
        console.error('Error fetching gas price:', error);
      }
    };

    fetchGasPrice();
    const interval = setInterval(fetchGasPrice, 15000); // Update every 15 seconds
    return () => clearInterval(interval);
  }, [publicClient]);

  // Monitor transaction
  const { isLoading, isSuccess, isError, error, data } = useWaitForTransactionReceipt({
    hash: transaction?.hash,
  });

  useEffect(() => {
    if (!transaction?.hash) return;

    const newTx: Transaction = {
      hash: transaction.hash,
      description: transaction.description,
      status: 'pending',
      timestamp: Date.now(),
    };

    setTransactions((prev) => {
      const exists = prev.find((tx) => tx.hash === transaction.hash);
      if (exists) return prev;
      return [newTx, ...prev].slice(0, 10); // Keep last 10 transactions
    });
  }, [transaction]);

  useEffect(() => {
    if (!transaction?.hash) return;

    if (isSuccess && data) {
      setTransactions((prev) =>
        prev.map((tx) =>
          tx.hash === transaction.hash
            ? { 
                ...tx, 
                status: 'success', 
                gasUsed: data.gasUsed,
                effectiveGasPrice: data.effectiveGasPrice 
              }
            : tx
        )
      );
      onSuccess?.();
    }

    if (isError) {
      const errorMessage = getErrorMessage(error);
      setTransactions((prev) =>
        prev.map((tx) =>
          tx.hash === transaction.hash
            ? { ...tx, status: 'error', error: errorMessage }
            : tx
        )
      );
      onError?.(error);
    }
  }, [isSuccess, isError, transaction, data, error, onSuccess, onError]);

  const formatGasCost = (gasUsed: bigint, gasPrice: bigint) => {
    const cost = gasUsed * gasPrice;
    return formatEther(cost);
  };

  const estimateGasCost = (gasLimit: bigint = 200000n) => {
    if (!gasPrice) return '0';
    const estimated = gasLimit * gasPrice;
    return formatEther(estimated);
  };

  return (
    <div className="space-y-4">
      {/* Gas Estimate */}
      {showGasEstimate && gasPrice && (
        <div className="bg-white/5 backdrop-blur-sm border border-white/10 rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Fuel className="w-4 h-4 text-white/60" />
              <span className="text-sm text-white/60">Estimated Gas</span>
            </div>
            <div className="text-right">
              <p className="text-sm font-medium text-white">
                {formatUnits(gasPrice, 9)} Gwei
              </p>
              <p className="text-xs text-white/40">
                ~{estimateGasCost()} ETH
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Transaction List */}
      {transactions.length > 0 && (
        <div className="space-y-2">
          <h4 className="text-sm font-medium text-white/60">Recent Transactions</h4>
          {transactions.map((tx) => (
            <div
              key={tx.hash}
              className={cn(
                'bg-white/5 backdrop-blur-sm border rounded-xl p-4 transition-all duration-300',
                tx.status === 'pending' && 'border-blue-500/50 animate-pulse',
                tx.status === 'success' && 'border-green-500/50',
                tx.status === 'error' && 'border-red-500/50'
              )}
            >
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    {tx.status === 'pending' && (
                      <Loader2 className="w-4 h-4 text-blue-500 animate-spin" />
                    )}
                    {tx.status === 'success' && (
                      <CheckCircle className="w-4 h-4 text-green-500" />
                    )}
                    {tx.status === 'error' && (
                      <XCircle className="w-4 h-4 text-red-500" />
                    )}
                    <span className="text-sm font-medium text-white">
                      {tx.description}
                    </span>
                  </div>
                  
                  <div className="mt-2 space-y-1">
                    <div className="flex items-center gap-2">
                      <Clock className="w-3 h-3 text-white/40" />
                      <span className="text-xs text-white/40">
                        {new Date(tx.timestamp).toLocaleTimeString()}
                      </span>
                    </div>
                    
                    {tx.status === 'success' && tx.gasUsed && tx.effectiveGasPrice && (
                      <div className="flex items-center gap-2">
                        <Fuel className="w-3 h-3 text-white/40" />
                        <span className="text-xs text-white/40">
                          Gas: {formatGasCost(tx.gasUsed, tx.effectiveGasPrice)} ETH
                        </span>
                      </div>
                    )}
                    
                    {tx.error && (
                      <div className="flex items-start gap-2 mt-2">
                        <AlertCircle className="w-3 h-3 text-red-500 mt-0.5" />
                        <span className="text-xs text-red-400">{tx.error}</span>
                      </div>
                    )}
                  </div>
                </div>
                
                <a
                  href={explorer.tx(tx.hash)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="ml-4 p-2 hover:bg-white/10 rounded-lg transition-colors"
                >
                  <ExternalLink className="w-4 h-4 text-white/60" />
                </a>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

// Hook for managing transactions
export function useTransactionManager() {
  const [pendingTx, setPendingTx] = useState<string | null>(null);
  const [txDescription, setTxDescription] = useState<string>('');

  const startTransaction = (hash: string, description: string) => {
    setPendingTx(hash);
    setTxDescription(description);
  };

  const clearTransaction = () => {
    setPendingTx(null);
    setTxDescription('');
  };

  return {
    pendingTx,
    txDescription,
    startTransaction,
    clearTransaction,
  };
}