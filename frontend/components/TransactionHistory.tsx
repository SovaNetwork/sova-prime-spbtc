'use client';

import { useTransactionHistory, formatTransaction } from '@/hooks/useTransactionHistory';
import { ArrowDownIcon, ArrowUpIcon, ExternalLinkIcon, RefreshCwIcon } from 'lucide-react';
import { useState } from 'react';
import toast from 'react-hot-toast';

interface TransactionHistoryProps {
  userAddress?: string;
  limit?: number;
  showUserFilter?: boolean;
}

export default function TransactionHistory({
  userAddress,
  limit = 20,
  showUserFilter = false,
}: TransactionHistoryProps) {
  const [filterAddress, setFilterAddress] = useState(userAddress || '');
  const { transactions, loading, error, refetch } = useTransactionHistory(
    showUserFilter ? filterAddress : userAddress,
    limit
  );

  const handleRefresh = async () => {
    try {
      await refetch();
      toast.success('Transactions refreshed');
    } catch (err) {
      toast.error('Failed to refresh transactions');
    }
  };

  if (error) {
    return (
      <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
        <div className="text-red-400">
          Error loading transactions: {error.message}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-white/5 backdrop-blur-xl rounded-2xl border border-white/10 p-6">
      <div className="flex items-center justify-between mb-6">
        <h3 className="text-xl font-semibold text-white">Transaction History</h3>
        <button
          onClick={handleRefresh}
          disabled={loading}
          className="p-2 rounded-lg bg-white/5 hover:bg-white/10 transition-colors disabled:opacity-50"
        >
          <RefreshCwIcon className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {showUserFilter && (
        <div className="mb-4">
          <input
            type="text"
            placeholder="Filter by address (0x...)"
            value={filterAddress}
            onChange={(e) => setFilterAddress(e.target.value)}
            className="w-full px-4 py-2 bg-white/5 border border-white/10 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:border-violet-500"
          />
        </div>
      )}

      {loading && transactions.length === 0 ? (
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="animate-pulse">
              <div className="h-16 bg-white/5 rounded-lg"></div>
            </div>
          ))}
        </div>
      ) : transactions.length === 0 ? (
        <div className="text-center py-8 text-gray-400">
          No transactions found
        </div>
      ) : (
        <div className="space-y-3">
          {transactions.map((tx) => {
            const formatted = formatTransaction(tx);
            return (
              <div
                key={tx.id}
                className="p-4 bg-white/5 rounded-lg hover:bg-white/10 transition-colors"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className={`p-2 rounded-lg ${
                      tx.type === 'deposit' 
                        ? 'bg-green-500/20 text-green-400' 
                        : 'bg-red-500/20 text-red-400'
                    }`}>
                      {tx.type === 'deposit' ? (
                        <ArrowDownIcon className="w-4 h-4" />
                      ) : (
                        <ArrowUpIcon className="w-4 h-4" />
                      )}
                    </div>
                    <div>
                      <div className="text-white font-medium">
                        {tx.type === 'deposit' ? 'Deposit' : 'Withdrawal'}
                      </div>
                      <div className="text-sm text-gray-400">
                        {formatted.shortUser}
                      </div>
                    </div>
                  </div>

                  <div className="text-right">
                    <div className="text-white font-medium">
                      {formatted.formattedAmount} BTC
                    </div>
                    <div className="text-sm text-gray-400">
                      {formatted.formattedShares} shares
                    </div>
                  </div>
                </div>

                <div className="mt-3 flex items-center justify-between text-sm">
                  <div className="text-gray-400">
                    {formatted.formattedTime}
                  </div>
                  <a
                    href={`https://sepolia.basescan.org/tx/${tx.transactionHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-1 text-violet-400 hover:text-violet-300"
                  >
                    {formatted.shortTxHash}
                    <ExternalLinkIcon className="w-3 h-3" />
                  </a>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {transactions.length > 0 && transactions.length >= limit && (
        <div className="mt-4 text-center">
          <button className="text-violet-400 hover:text-violet-300 text-sm">
            Load more transactions
          </button>
        </div>
      )}
    </div>
  );
}