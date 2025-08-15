import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { serializeBigInt } from '@/lib/utils'
import { parseUnits } from 'viem'

// POST /api/admin/redemptions/process - Mark redemptions as processed after blockchain transaction
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { requestIds, txHash, sharePrice } = body

    if (!requestIds || !Array.isArray(requestIds) || requestIds.length === 0) {
      return NextResponse.json(
        { error: 'requestIds array is required' },
        { status: 400 }
      )
    }

    if (!txHash) {
      return NextResponse.json(
        { error: 'txHash is required' },
        { status: 400 }
      )
    }

    // Get the share price (in 8 decimals for BTC)
    const sharePriceWei = sharePrice ? BigInt(sharePrice) : parseUnits('1', 8)

    // Update all requests to COMPLETED status
    const updatePromises = requestIds.map(async (id: string) => {
      // Get the request to calculate actual assets
      const request = await prisma.redemptionRequest.findUnique({
        where: { id }
      })

      if (!request) {
        throw new Error(`Request ${id} not found`)
      }

      // Calculate actual assets delivered (convert from 18 dec shares to 8 dec BTC)
      const actualAssets = (request.shareAmount * sharePriceWei) / parseUnits('1', 18)

      return prisma.redemptionRequest.update({
        where: { id },
        data: {
          status: 'COMPLETED',
          processedAt: new Date(),
          txHash,
          actualAssets: actualAssets,
          gasCost: BigInt(0), // Can be calculated from transaction receipt if needed
          updatedAt: new Date()
        }
      })
    })

    const updatedRequests = await Promise.all(updatePromises)

    // Log the activity
    const activityPromises = updatedRequests.map(request => 
      prisma.sovaBtcActivity.create({
        data: {
          deploymentId: request.deploymentId,
          type: 'REDEMPTION_PROCESSED',
          description: `Redemption request ${request.id} processed`,
          metadata: serializeBigInt({
            requestId: request.id,
            userAddress: request.userAddress,
            shareAmount: request.shareAmount,
            actualAssets: request.actualAssets,
            txHash
          }),
          txHash
        }
      })
    )

    await Promise.all(activityPromises)

    // Update metrics
    const deployment = await prisma.sovaBtcDeployment.findFirst({
      where: { id: updatedRequests[0].deploymentId }
    })

    if (deployment) {
      const totalRedeemed = updatedRequests.reduce((sum, req) => 
        sum + BigInt(req.actualAssets || '0'), 0n
      )

      await prisma.sovaBtcDeploymentMetrics.create({
        data: {
          deploymentId: deployment.id,
          tvl: '0', // Will be updated by scheduler
          totalSupply: '0',
          totalAssets: '0',
          sharePrice: '1',
          apy: '0',
          users: 0,
          transactions: updatedRequests.length
        }
      })
    }

    return NextResponse.json(serializeBigInt({
      success: true,
      processedCount: updatedRequests.length,
      txHash,
      requests: updatedRequests
    }))
  } catch (error) {
    console.error('Error processing redemptions:', error)
    return NextResponse.json(
      { error: 'Failed to process redemptions' },
      { status: 500 }
    )
  }
}