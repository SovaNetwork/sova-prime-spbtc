import { useState, useCallback } from 'react'
import { useAccount, useSignTypedData, useChainId } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import {
  RedemptionRequestData,
  SignedRedemptionRequest,
  REDEMPTION_TYPES,
  createRedemptionDomain,
  generateNonce,
  createDeadline,
  validateRedemptionRequest,
} from '../lib/eip712'

interface UseEIP712RedemptionOptions {
  vaultAddress: `0x${string}`
  shareDecimals?: number
  assetDecimals?: number
}

interface UseEIP712RedemptionReturn {
  // State
  isSigningRedemption: boolean
  redemptionError: string | null
  
  // Actions
  signRedemptionRequest: (params: {
    shareAmount: string
    minAssetsOut: string
    deadlineMinutes?: number
  }) => Promise<SignedRedemptionRequest | null>
  
  clearError: () => void
}

export function useEIP712Redemption({
  vaultAddress,
  shareDecimals = 18,
  assetDecimals = 8,
}: UseEIP712RedemptionOptions): UseEIP712RedemptionReturn {
  const { address } = useAccount()
  const chainId = useChainId()
  const { signTypedDataAsync, isPending: isSigningTypedData } = useSignTypedData()

  const [isSigningRedemption, setIsSigningRedemption] = useState(false)
  const [redemptionError, setRedemptionError] = useState<string | null>(null)

  const signRedemptionRequest = useCallback(async (params: {
    shareAmount: string
    minAssetsOut: string
    deadlineMinutes?: number
  }): Promise<SignedRedemptionRequest | null> => {
    if (!address) {
      setRedemptionError('Wallet not connected')
      return null
    }

    setIsSigningRedemption(true)
    setRedemptionError(null)

    try {
      // Parse amounts with proper decimals
      const shareAmount = parseUnits(params.shareAmount, shareDecimals)
      const minAssetsOut = parseUnits(params.minAssetsOut, assetDecimals)
      const nonce = generateNonce()
      const deadline = createDeadline(params.deadlineMinutes || 20160) // Default to 14 days if not provided

      // Create the redemption request data
      const requestData: RedemptionRequestData = {
        user: address,
        shareAmount,
        minAssetsOut,
        nonce,
        deadline,
      }

      // Validate the request
      const validationErrors = validateRedemptionRequest(requestData)
      if (validationErrors.length > 0) {
        setRedemptionError(`Validation failed: ${validationErrors.join(', ')}`)
        return null
      }

      // Create domain for the current network and vault
      const domain = createRedemptionDomain(chainId, vaultAddress)

      // Sign the typed data
      const signature = await signTypedDataAsync({
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData as unknown as Record<string, unknown>,
      })

      // Return the signed request with BigInt values as strings for JSON serialization
      return {
        user: requestData.user,
        shareAmount: requestData.shareAmount.toString(),
        minAssetsOut: requestData.minAssetsOut.toString(),
        nonce: requestData.nonce.toString(),
        deadline: requestData.deadline.toString(),
        signature,
      } as any
    } catch (error) {
      console.error('Error signing redemption request:', error)
      
      if (error instanceof Error) {
        if (error.message.includes('User rejected')) {
          setRedemptionError('Transaction rejected by user')
        } else {
          setRedemptionError(`Failed to sign redemption request: ${error.message}`)
        }
      } else {
        setRedemptionError('Unknown error occurred while signing')
      }
      
      return null
    } finally {
      setIsSigningRedemption(false)
    }
  }, [address, chainId, vaultAddress, shareDecimals, assetDecimals, signTypedDataAsync])

  const clearError = useCallback(() => {
    setRedemptionError(null)
  }, [])

  return {
    isSigningRedemption: isSigningRedemption || isSigningTypedData,
    redemptionError,
    signRedemptionRequest,
    clearError,
  }
}

// Helper hook for formatting redemption request data for display
export function useRedemptionRequestFormatter(shareDecimals = 18, assetDecimals = 8) {
  const formatShareAmount = useCallback((amount: bigint): string => {
    return formatUnits(amount, shareDecimals)
  }, [shareDecimals])

  const formatAssetAmount = useCallback((amount: bigint): string => {
    return formatUnits(amount, assetDecimals)
  }, [assetDecimals])

  const formatDeadline = useCallback((deadline: bigint): string => {
    const deadlineDate = new Date(Number(deadline) * 1000)
    return deadlineDate.toLocaleString()
  }, [])

  const formatNonce = useCallback((nonce: bigint): string => {
    return nonce.toString()
  }, [])

  return {
    formatShareAmount,
    formatAssetAmount,
    formatDeadline,
    formatNonce,
  }
}