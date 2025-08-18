'use client'

import { useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import { GlassCard } from '@/components/GlassCard'
import { RedemptionRequestForm } from './RedemptionRequestForm'
import { UserRedemptionRequests } from './UserRedemptionRequestsSimple'
import { ERC20_ABI } from '@/lib/abis'
import { AlertTriangle, Info } from 'lucide-react'

interface VaultRedemptionProps {
  vaultAddress: `0x${string}`
  deploymentId: string
  chainId: number
}

export function VaultRedemption({
  vaultAddress,
  deploymentId,
  chainId,
}: VaultRedemptionProps) {
  const { address } = useAccount()
  const [refreshTrigger, setRefreshTrigger] = useState(0)
  const [activeTab, setActiveTab] = useState<'request' | 'history'>('request')

  // Read user's share balance
  const { data: shareBalance = 0n } = useReadContract({
    address: vaultAddress,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: [address!],
    query: {
      enabled: !!address,
    },
  })

  // Read current share price
  const { data: currentSharePrice = 0n } = useReadContract({
    address: vaultAddress,
    abi: [
      {
        inputs: [{ name: 'shares', type: 'uint256' }],
        name: 'convertToAssets',
        outputs: [{ type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'convertToAssets',
    args: [10n ** 18n], // 1 share
  })

  const handleRedemptionSuccess = (requestId: string) => {
    setRefreshTrigger(prev => prev + 1)
  }

  if (!address) {
    return (
      <GlassCard>
        <div className="p-6">
          <div className="flex items-start space-x-3 p-4 bg-blue-500/20 border border-blue-500/30 rounded-lg">
            <Info className="h-5 w-5 text-blue-400 mt-0.5" />
            <p className="text-sm text-blue-300">
              Please connect your wallet to request redemptions from the vault.
            </p>
          </div>
        </div>
      </GlassCard>
    )
  }

  const hasShares = shareBalance > 0n

  return (
    <div className="space-y-6">
      {/* Vault Info */}
      <GlassCard>
        <div className="p-6">
          <h2 className="text-2xl font-bold mb-2">Vault Redemption</h2>
          <p className="text-gray-400 mb-6">
            Request redemption of your vault shares through an EIP-712 signed request
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <div className="text-sm font-medium text-gray-400">Your Share Balance</div>
              <div className="text-lg font-bold">
                {formatUnits(shareBalance, 18)} shares
              </div>
            </div>
            <div>
              <div className="text-sm font-medium text-gray-400">Current Share Price</div>
              <div className="text-lg font-bold">
                {formatUnits(currentSharePrice, 8)} BTC/share
              </div>
            </div>
          </div>
          {!hasShares && (
            <div className="mt-4 flex items-start space-x-3 p-4 bg-yellow-500/20 border border-yellow-500/30 rounded-lg">
              <AlertTriangle className="h-5 w-5 text-yellow-400 mt-0.5" />
              <p className="text-sm text-yellow-300">
                You don't have any vault shares to redeem. Deposit into the vault first to receive shares.
              </p>
            </div>
          )}
        </div>
      </GlassCard>

      {/* Important Notice */}
      <div className="flex items-start space-x-3 p-4 bg-blue-500/20 border border-blue-500/30 rounded-lg">
        <Info className="h-5 w-5 text-blue-400 mt-0.5" />
        <div>
          <p className="text-sm text-blue-300 font-semibold">Important:</p>
          <p className="text-sm text-blue-300">
            Redemption requests are processed manually by vault administrators. 
            Your request will be queued and processed based on vault liquidity and administrative availability. 
            Processing times may vary.
          </p>
        </div>
      </div>

      {/* Tabs */}
      <GlassCard>
        <div className="p-6">
          <div className="flex space-x-4 mb-6">
            <button
              onClick={() => setActiveTab('request')}
              className={`px-4 py-2 rounded-lg font-semibold transition-all ${
                activeTab === 'request'
                  ? 'bg-mint-500 text-white'
                  : 'bg-white/10 text-gray-400 hover:bg-white/20'
              }`}
            >
              Submit Request
            </button>
            <button
              onClick={() => setActiveTab('history')}
              className={`px-4 py-2 rounded-lg font-semibold transition-all ${
                activeTab === 'history'
                  ? 'bg-mint-500 text-white'
                  : 'bg-white/10 text-gray-400 hover:bg-white/20'
              }`}
            >
              Your Requests
            </button>
          </div>

          {activeTab === 'request' ? (
            hasShares ? (
              <RedemptionRequestForm
                vaultAddress={vaultAddress}
                deploymentId={deploymentId}
                shareBalance={shareBalance}
                currentSharePrice={currentSharePrice}
                onSuccess={handleRedemptionSuccess}
              />
            ) : (
              <div className="text-center py-8">
                <AlertTriangle className="h-12 w-12 text-gray-500 mx-auto mb-4" />
                <h3 className="text-lg font-semibold mb-2">No Shares to Redeem</h3>
                <p className="text-gray-400">
                  You need to have vault shares before you can request redemptions.
                </p>
              </div>
            )
          ) : (
            <UserRedemptionRequests
              deploymentId={deploymentId}
              refreshTrigger={refreshTrigger}
            />
          )}
        </div>
      </GlassCard>
    </div>
  )
}