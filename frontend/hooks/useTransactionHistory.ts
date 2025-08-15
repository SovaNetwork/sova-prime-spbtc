import { useQuery } from '@apollo/client';
import { GET_RECENT_DEPOSITS, GET_RECENT_WITHDRAWALS, GET_TRANSACTION_HISTORY } from '@/lib/queries';
import { useMemo } from 'react';
import { formatUnits } from 'viem';

interface Transaction {
  id: string;
  type: 'deposit' | 'withdrawal';
  user: string;
  token: string;
  amount: string;
  shares: string;
  timestamp: number;
  blockNumber: number;
  transactionHash: string;
}

export function useTransactionHistory(userAddress?: string, limit: number = 20) {
  const { data, loading, error, refetch } = useQuery(GET_TRANSACTION_HISTORY, {
    pollInterval: 60000, // Refresh every minute
    skip: false,
  });

  const transactions = useMemo(() => {
    if (!data) return [];

    const deposits = (data.btcDepositss?.items || []).map((item: any) => ({
      id: item.id,
      type: 'deposit' as const,
      user: item.owner, // Changed from depositor to owner
      amount: item.assets, // Changed from amount to assets
      shares: item.shares,
      timestamp: item.blockTimestamp,
      blockNumber: item.blockNumber,
      transactionHash: item.transactionHash,
    }));

    const withdrawals = (data.btcWithdrawalss?.items || []).map((item: any) => ({
      id: item.id,
      type: 'withdrawal' as const,
      user: item.owner, // Changed from withdrawer to owner
      amount: item.assets, // Changed from amount to assets
      shares: item.shares,
      timestamp: item.blockTimestamp,
      blockNumber: item.blockNumber,
      transactionHash: item.transactionHash,
    }));

    // Filter by user if specified
    let allTransactions = [...deposits, ...withdrawals];
    if (userAddress) {
      allTransactions = allTransactions.filter(tx => 
        tx.user.toLowerCase() === userAddress.toLowerCase()
      );
    }

    // Sort by timestamp (most recent first)
    return allTransactions.sort((a, b) => b.timestamp - a.timestamp).slice(0, limit);
  }, [data, userAddress, limit]);

  return {
    transactions,
    loading,
    error,
    refetch,
  };
}

export function useRecentDeposits(limit: number = 10) {
  const { data, loading, error } = useQuery(GET_RECENT_DEPOSITS, {
    pollInterval: 30000, // Refresh every 30 seconds
  });

  const deposits = useMemo(() => {
    if (!data?.btcDepositss?.items) return [];
    
    return data.btcDepositss.items.slice(0, limit).map((item: any) => ({
      id: item.id,
      depositor: item.owner, // Changed to owner
      amount: item.assets, // Changed to assets
      shares: item.shares,
      timestamp: item.blockTimestamp,
      blockNumber: item.blockNumber,
      transactionHash: item.transactionHash,
    }));
  }, [data, limit]);

  return {
    deposits,
    loading,
    error,
  };
}

export function useRecentWithdrawals(limit: number = 10) {
  const { data, loading, error } = useQuery(GET_RECENT_WITHDRAWALS, {
    pollInterval: 30000, // Refresh every 30 seconds
  });

  const withdrawals = useMemo(() => {
    if (!data?.btcWithdrawalss?.items) return [];
    
    return data.btcWithdrawalss.items.slice(0, limit).map((item: any) => ({
      id: item.id,
      withdrawer: item.owner, // Changed to owner
      amount: item.assets, // Changed to assets
      shares: item.shares,
      timestamp: item.blockTimestamp,
      blockNumber: item.blockNumber,
      transactionHash: item.transactionHash,
    }));
  }, [data, limit]);

  return {
    withdrawals,
    loading,
    error,
  };
}

// Helper function to format transaction for display
export function formatTransaction(tx: Transaction) {
  const formattedAmount = formatUnits(BigInt(tx.amount), 8); // Assuming 8 decimals for BTC
  const formattedShares = formatUnits(BigInt(tx.shares), 18); // 18 decimals for shares
  
  return {
    ...tx,
    formattedAmount,
    formattedShares,
    shortUser: `${tx.user.slice(0, 6)}...${tx.user.slice(-4)}`,
    shortTxHash: `${tx.transactionHash.slice(0, 6)}...${tx.transactionHash.slice(-4)}`,
    formattedTime: new Date(tx.timestamp * 1000).toLocaleString(),
  };
}