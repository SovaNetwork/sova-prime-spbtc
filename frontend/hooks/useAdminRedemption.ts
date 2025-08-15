'use client'

import { useState, useCallback } from 'react'
import { 
  useAccount, 
  useWriteContract, 
  useWaitForTransactionReceipt,
  useReadContract,
  usePublicClient
} from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { BTC_VAULT_TOKEN_ABI, BTC_VAULT_STRATEGY_ABI } from '@/lib/abis'
import { redemptionAPI, RedemptionRequestResponse, RedemptionStatus } from '@/lib/redemption-api'
import { useToast } from '@/hooks/use-toast'

interface BatchRedemptionParams {
  requests: RedemptionRequestResponse[]
  strategyAddress: string
  tokenAddress: string
}

export function useAdminRedemption() {
  const { address } = useAccount()
  const { toast } = useToast()
  const publicClient = usePublicClient()
  
  const [isProcessing, setIsProcessing] = useState(false)
  const [currentStep, setCurrentStep] = useState<'idle' | 'approving' | 'redeeming' | 'updating'>('idle')
  
  const { 
    writeContract: approveWithdrawal,
    data: approvalHash,
    isPending: isApproving,
    error: approvalError
  } = useWriteContract()
  
  const { 
    writeContract: batchRedeem,
    data: redeemHash,
    isPending: isRedeeming,
    error: redeemError
  } = useWriteContract()
  
  const { isLoading: isApprovalConfirming, isSuccess: isApprovalConfirmed } = useWaitForTransactionReceipt({
    hash: approvalHash,
  })
  
  const { isLoading: isRedeemConfirming, isSuccess: isRedeemConfirmed } = useWaitForTransactionReceipt({
    hash: redeemHash,
  })

  // For now, assume all connected wallets are admin (since we removed role-based auth)
  const isAdmin = !!address

  // Get available liquidity from strategy
  const checkLiquidity = useCallback(async (strategyAddress: string): Promise<bigint> => {
    if (!publicClient) return 0n
    
    try {
      // availableLiquidity is a public variable, so we need to read it directly
      const liquidity = await publicClient.readContract({
        address: strategyAddress as `0x${string}`,
        abi: [
          {
            inputs: [],
            name: 'availableLiquidity',
            outputs: [{ type: 'uint256' }],
            stateMutability: 'view',
            type: 'function'
          }
        ] as const,
        functionName: 'availableLiquidity',
      }) as bigint
      
      return liquidity
    } catch (error) {
      console.error('Error checking liquidity:', error)
      // Try alternative: check the sovaBTC balance directly
      try {
        const sovaBTCAddress = '0x05aB19d77516414f7333a8fd52cC1F49FF8eAFA9' // sovaBTC on Base Sepolia
        const balance = await publicClient.readContract({
          address: sovaBTCAddress as `0x${string}`,
          abi: [{
            inputs: [{ type: 'address' }],
            name: 'balanceOf',
            outputs: [{ type: 'uint256' }],
            stateMutability: 'view',
            type: 'function'
          }] as const,
          functionName: 'balanceOf',
          args: [strategyAddress as `0x${string}`]
        }) as bigint
        console.log('Using sovaBTC balance as liquidity:', balance)
        return balance
      } catch (balanceError) {
        console.error('Error checking balance:', balanceError)
        return 0n
      }
    }
  }, [publicClient])

  // Get share price for conversion
  const getSharePrice = useCallback(async (tokenAddress: string): Promise<bigint> => {
    if (!publicClient) return parseUnits('1', 8) // Default 1:1
    
    try {
      const [totalAssets, totalSupply] = await Promise.all([
        publicClient.readContract({
          address: tokenAddress as `0x${string}`,
          abi: BTC_VAULT_TOKEN_ABI,
          functionName: 'totalAssets',
        }) as Promise<bigint>,
        publicClient.readContract({
          address: tokenAddress as `0x${string}`,
          abi: BTC_VAULT_TOKEN_ABI,
          functionName: 'totalSupply',
        }) as Promise<bigint>
      ])
      
      if (totalSupply === 0n) return parseUnits('1', 8)
      
      // Calculate price with 8 decimals precision (BTC decimals)
      return (totalAssets * parseUnits('1', 8)) / totalSupply
    } catch (error) {
      console.error('Error getting share price:', error)
      return parseUnits('1', 8)
    }
  }, [publicClient])

  const processBatchRedemption = useCallback(async ({
    requests,
    strategyAddress,
    tokenAddress
  }: BatchRedemptionParams) => {
    if (!address) {
      toast({
        title: 'Wallet not connected',
        description: 'Please connect your wallet to process redemptions',
        variant: 'destructive'
      })
      return
    }

    if (requests.length === 0) {
      toast({
        title: 'No requests selected',
        description: 'Please select redemption requests to process',
        variant: 'destructive'
      })
      return
    }

    setIsProcessing(true)
    setCurrentStep('approving')

    try {
      // Step 1: Check available liquidity
      const availableLiquidity = await checkLiquidity(strategyAddress)
      const sharePrice = await getSharePrice(tokenAddress)
      
      // Calculate total assets needed
      const totalSharesWei = requests.reduce((sum, req) => {
        return sum + BigInt(req.shareAmount)
      }, 0n)
      
      const totalAssetsNeeded = (totalSharesWei * sharePrice) / parseUnits('1', 18) // Convert from shares (18 dec) to assets (8 dec)
      
      if (totalAssetsNeeded > availableLiquidity) {
        const needed = formatUnits(totalAssetsNeeded, 8)
        const available = formatUnits(availableLiquidity, 8)
        
        toast({
          title: 'Insufficient liquidity',
          description: `Need ${needed} BTC but only ${available} BTC available`,
          variant: 'destructive'
        })
        setIsProcessing(false)
        setCurrentStep('idle')
        return
      }

      // Step 2: Approve token withdrawal from strategy
      toast({
        title: 'Step 1/2: Approving withdrawal',
        description: 'Approving the vault token to withdraw liquidity from strategy...'
      })
      
      await approveWithdrawal({
        address: strategyAddress as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'approveTokenWithdrawal',
      })

      // Wait for approval confirmation
      while (!isApprovalConfirmed && !approvalError) {
        await new Promise(resolve => setTimeout(resolve, 1000))
      }

      if (approvalError) {
        throw new Error(`Approval failed: ${approvalError.message}`)
      }

      toast({
        title: 'Approval successful',
        description: 'Token withdrawal approved, processing redemptions...',
        variant: 'success'
      })

      setCurrentStep('redeeming')

      // Step 3: Batch redeem shares
      const shares = requests.map(req => BigInt(req.shareAmount))
      const recipients = requests.map(req => req.userAddress as `0x${string}`)
      const owners = requests.map(req => req.userAddress as `0x${string}`)
      const minAssets = requests.map(req => BigInt(req.minAssetsOut))

      toast({
        title: 'Step 2/2: Processing redemptions',
        description: `Processing ${requests.length} redemption requests...`
      })

      await batchRedeem({
        address: tokenAddress as `0x${string}`,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'batchRedeemShares',
        args: [shares, recipients, owners, minAssets],
      })

      // Wait for redemption confirmation
      while (!isRedeemConfirmed && !redeemError) {
        await new Promise(resolve => setTimeout(resolve, 1000))
      }

      if (redeemError) {
        throw new Error(`Redemption failed: ${redeemError.message}`)
      }

      toast({
        title: 'Redemptions processed',
        description: `Successfully processed ${requests.length} redemption requests`,
        variant: 'success'
      })

      setCurrentStep('updating')

      // Step 4: Update database status
      const updatePromises = requests.map(async (request) => {
        try {
          // Calculate actual assets delivered
          const shareAmount = BigInt(request.shareAmount)
          const actualAssets = (shareAmount * sharePrice) / parseUnits('1', 18)
          
          await redemptionAPI.markRedemptionProcessed({
            id: request.id,
            txHash: redeemHash || '',
            actualAssets: formatUnits(actualAssets, 8),
            gasCost: '0', // Can be calculated from receipt if needed
          })
        } catch (error) {
          console.error(`Failed to update request ${request.id}:`, error)
        }
      })

      await Promise.all(updatePromises)

      toast({
        title: 'Complete',
        description: 'All redemptions have been processed and database updated',
        variant: 'success'
      })

    } catch (error) {
      console.error('Batch redemption error:', error)
      toast({
        title: 'Processing failed',
        description: error instanceof Error ? error.message : 'Failed to process redemptions',
        variant: 'destructive'
      })
    } finally {
      setIsProcessing(false)
      setCurrentStep('idle')
    }
  }, [
    address,
    approveWithdrawal,
    batchRedeem,
    checkLiquidity,
    getSharePrice,
    isApprovalConfirmed,
    isRedeemConfirmed,
    approvalError,
    redeemError,
    redeemHash,
    toast
  ])

  return {
    processBatchRedemption,
    isProcessing,
    currentStep,
    isAdmin,
    checkLiquidity,
    getSharePrice,
    // Transaction states
    isApproving,
    isRedeeming,
    isApprovalConfirming,
    isRedeemConfirming,
    approvalHash,
    redeemHash,
    approvalError,
    redeemError,
  }
}