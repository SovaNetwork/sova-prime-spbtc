import { NextRequest, NextResponse } from 'next/server'
import { createPublicClient, http } from 'viem'
import { baseSepolia } from 'viem/chains'
import { BTC_VAULT_STRATEGY_ABI, BTC_VAULT_TOKEN_ABI } from '@/lib/abis'
import { serializeBigInt } from '@/lib/utils'

// GET /api/admin/redemptions/liquidity - Check available liquidity and share price
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const strategyAddress = searchParams.get('strategyAddress')
    const tokenAddress = searchParams.get('tokenAddress')
    
    if (!strategyAddress || !tokenAddress) {
      return NextResponse.json(
        { error: 'strategyAddress and tokenAddress are required' },
        { status: 400 }
      )
    }

    // Create a public client for Base Sepolia
    const publicClient = createPublicClient({
      chain: baseSepolia,
      transport: http(process.env.NEXT_PUBLIC_BASE_SEPOLIA_RPC || 'https://sepolia.base.org')
    })

    // Fetch liquidity and share price in parallel
    const [availableLiquidity, totalAssets, totalSupply] = await Promise.all([
      // Get available liquidity from strategy
      publicClient.readContract({
        address: strategyAddress as `0x${string}`,
        abi: BTC_VAULT_STRATEGY_ABI,
        functionName: 'availableLiquidity',
      }) as Promise<bigint>,
      
      // Get total assets from token
      publicClient.readContract({
        address: tokenAddress as `0x${string}`,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'totalAssets',
      }) as Promise<bigint>,
      
      // Get total supply from token
      publicClient.readContract({
        address: tokenAddress as `0x${string}`,
        abi: BTC_VAULT_TOKEN_ABI,
        functionName: 'totalSupply',
      }) as Promise<bigint>
    ])

    // Calculate share price (with 8 decimals for BTC)
    const sharePrice = totalSupply > 0n 
      ? (totalAssets * 100000000n) / totalSupply 
      : 100000000n // Default 1:1 if no supply

    // Calculate utilization rate
    const utilization = totalAssets > 0n
      ? ((totalAssets - availableLiquidity) * 10000n) / totalAssets
      : 0n

    return NextResponse.json(serializeBigInt({
      availableLiquidity: availableLiquidity.toString(),
      totalAssets: totalAssets.toString(),
      totalSupply: totalSupply.toString(),
      sharePrice: sharePrice.toString(),
      utilizationBps: utilization.toString(), // Basis points (100 = 1%)
      canProcessRedemptions: availableLiquidity > 0n,
      timestamp: new Date().toISOString()
    }))
  } catch (error) {
    console.error('Error checking liquidity:', error)
    return NextResponse.json(
      { error: 'Failed to check liquidity' },
      { status: 500 }
    )
  }
}