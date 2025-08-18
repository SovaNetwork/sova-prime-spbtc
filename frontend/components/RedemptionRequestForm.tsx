'use client'

import { useState, useCallback } from 'react'
import { useAccount, useBalance } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { useEIP712Redemption } from '@/hooks/useEIP712Redemption'
import { redemptionAPI } from '@/lib/redemption-api'
import toast from 'react-hot-toast'
import { GlassCard } from '@/components/GlassCard'

interface RedemptionRequestFormProps {
  vaultAddress: `0x${string}`
  deploymentId: string
  shareBalance: bigint
  currentSharePrice: bigint
  onSuccess?: (requestId: string) => void
}

export function RedemptionRequestForm({
  vaultAddress,
  deploymentId,
  shareBalance,
  currentSharePrice,
  onSuccess,
}: RedemptionRequestFormProps) {
  const { address } = useAccount()

  // Form state
  const [shareAmount, setShareAmount] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  // Use fixed defaults for simplified UI
  const slippageTolerance = '0.5' // 0.5% fixed default
  const deadlineMinutes = '20160' // 14 days in minutes (14 * 24 * 60)

  // EIP-712 signature hook
  const {
    isSigningRedemption,
    redemptionError,
    signRedemptionRequest,
    clearError,
  } = useEIP712Redemption({
    vaultAddress,
    shareDecimals: 18,
    assetDecimals: 8,
  })

  // Calculate expected assets based on current share price
  const expectedAssets = shareAmount
    ? (parseUnits(shareAmount, 18) * currentSharePrice) / parseUnits('1', 18)
    : 0n

  // Calculate minimum assets with fixed 0.5% slippage
  const minAssetsOut = shareAmount
    ? (() => {
        const expected = expectedAssets
        const slippage = parseFloat(slippageTolerance) / 100
        const minAssets = expected - (expected * BigInt(Math.floor(slippage * 10000)) / 10000n)
        return formatUnits(minAssets, 8)
      })()
    : ''

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!address) {
      toast.error('Please connect your wallet to submit a redemption request')
      return
    }

    if (!shareAmount) {
      toast.error('Please enter a valid share amount')
      return
    }

    setIsSubmitting(true)
    clearError()

    try {
      // Sign the redemption request
      const signedRequest = await signRedemptionRequest({
        shareAmount,
        minAssetsOut,
        deadlineMinutes: parseInt(deadlineMinutes),
      })

      if (!signedRequest) {
        return // Error is handled by the hook
      }

      // Submit to API
      const response = await redemptionAPI.submitRedemptionRequest({
        deploymentId,
        expectedAssets: expectedAssets.toString(), // Send raw BigInt as string, not formatted
        signedRequest,
      })

      toast.success(`Redemption request submitted! Request ID: ${response.id}`)

      // Reset form
      setShareAmount('')

      onSuccess?.(response.id)
    } catch (error) {
      console.error('Error submitting redemption request:', error)
      toast.error(error instanceof Error ? error.message : 'Failed to submit redemption request')
    } finally {
      setIsSubmitting(false)
    }
  }

  const isFormValid = shareAmount && parseFloat(shareAmount) > 0
  const isLoading = isSigningRedemption || isSubmitting
  
  // Check if user has sufficient balance
  const shareAmountBigInt = shareAmount ? parseUnits(shareAmount, 18) : 0n
  const hasSufficientBalance = shareAmountBigInt <= shareBalance

  return (
    <GlassCard>
      <div className="p-6">
        <h3 className="text-xl font-semibold mb-2">Request Redemption</h3>
        <p className="text-sm text-gray-400 mb-6">
          Submit a signed redemption request to be processed by vault administrators
        </p>
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Share Amount Input */}
          <div className="space-y-2">
            <label htmlFor="shareAmount" className="block text-sm font-medium text-gray-300">
              Vault Shares to Redeem
              <span className="ml-2 text-xs bg-gray-700 px-2 py-1 rounded">
                Balance: {formatUnits(shareBalance, 18)} shares
              </span>
            </label>
            <input
              id="shareAmount"
              type="number"
              step="0.000001"
              placeholder="0.0"
              value={shareAmount}
              onChange={(e) => setShareAmount(e.target.value)}
              disabled={isLoading}
              className="w-full px-4 py-2 bg-white/10 border border-white/20 rounded-lg text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-mint-500 focus:border-transparent"
            />
            {shareAmount && !hasSufficientBalance && (
              <div className="p-3 bg-red-500/20 border border-red-500/30 rounded-lg">
                <p className="text-sm text-red-400">
                  Insufficient balance. You have {formatUnits(shareBalance, 18)} shares available.
                </p>
              </div>
            )}
          </div>

          {/* Expected Assets and Details Display */}
          {shareAmount && (
            <div className="space-y-4">
              <div className="p-4 bg-white/5 border border-white/10 rounded-lg">
                <h4 className="text-sm font-medium text-gray-300 mb-3">Redemption Details</h4>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <div className="text-xs text-gray-400">Expected Assets</div>
                    <div className="text-sm font-semibold text-white">
                      {formatUnits(expectedAssets, 8)} BTC
                    </div>
                  </div>
                  <div>
                    <div className="text-xs text-gray-400">Minimum Assets (0.5% slippage)</div>
                    <div className="text-sm font-semibold text-white">
                      {minAssetsOut} BTC
                    </div>
                  </div>
                </div>
                <div className="mt-3 pt-3 border-t border-white/10">
                  <div className="flex justify-between text-xs">
                    <span className="text-gray-400">Share Price:</span>
                    <span className="text-white">{formatUnits(currentSharePrice, 8)} BTC/share</span>
                  </div>
                  <div className="flex justify-between text-xs mt-1">
                    <span className="text-gray-400">Signature Valid:</span>
                    <span className="text-white">14 days</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Error Display */}
          {redemptionError && (
            <div className="p-3 bg-red-500/20 border border-red-500/30 rounded-lg">
              <p className="text-sm text-red-400">{redemptionError}</p>
            </div>
          )}

          {/* Submit Button */}
          <button
            type="submit"
            className="w-full px-6 py-3 bg-gradient-to-r from-mint-500 to-pink-500 rounded-lg font-semibold text-white transition-all hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed"
            disabled={!isFormValid || !hasSufficientBalance || isLoading}
          >
            {isLoading
              ? 'Processing...'
              : 'Sign and Submit Redemption Request'
            }
          </button>

          {/* Info */}
          <div className="text-xs text-gray-400 space-y-1">
            <p>• Your redemption request will be queued for admin approval</p>
            <p>• You'll sign an EIP-712 message to authorize the redemption</p>
            <p>• 0.5% slippage tolerance and 14-day signature validity applied automatically</p>
            <p>• Processing time depends on vault liquidity and admin availability</p>
          </div>
        </form>
      </div>
    </GlassCard>
  )
}