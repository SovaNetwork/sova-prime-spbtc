import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { RedemptionStatus } from '@/lib/redemption-api'
import { serializeBigInt } from '@/lib/utils'

// POST /api/redemptions/[id]/process - Mark redemption as processed
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { txHash, actualAssets, gasCost } = body

    // Validate required fields
    if (!txHash || !actualAssets) {
      return NextResponse.json(
        { error: 'Missing required fields: txHash, actualAssets' },
        { status: 400 }
      )
    }

    // Get the redemption request
    const existingRequest = await prisma.redemptionRequest.findUnique({
      where: { id },
    })

    if (!existingRequest) {
      return NextResponse.json(
        { error: 'Redemption request not found' },
        { status: 404 }
      )
    }

    // Validate current status
    if (existingRequest.status !== RedemptionStatus.PROCESSING) {
      return NextResponse.json(
        { error: 'Can only mark PROCESSING requests as completed' },
        { status: 400 }
      )
    }

    // Update the request
    const updatedRequest = await prisma.redemptionRequest.update({
      where: { id },
      data: {
        status: RedemptionStatus.COMPLETED,
        processedAt: new Date(),
        txHash,
        actualAssets: BigInt(actualAssets),
        gasCost: gasCost ? BigInt(gasCost) : null,
        queuePosition: null, // Remove from queue
      },
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    })

    // Create activity record
    await prisma.sovaBtcActivity.create({
      data: {
        deploymentId: updatedRequest.deploymentId,
        type: 'REDEMPTION_PROCESSED',
        description: `Redemption request completed successfully`,
        metadata: {
          requestId: updatedRequest.id,
          txHash,
          actualAssets: actualAssets,
          gasCost: gasCost || null,
        },
        txHash,
      },
    })

    // Format response
    const response = {
      id: updatedRequest.id,
      deploymentId: updatedRequest.deploymentId,
      userAddress: updatedRequest.userAddress,
      shareAmount: updatedRequest.shareAmount.toString(),
      expectedAssets: updatedRequest.expectedAssets.toString(),
      minAssetsOut: updatedRequest.minAssetsOut.toString(),
      signature: updatedRequest.signature,
      nonce: updatedRequest.nonce.toString(),
      deadline: updatedRequest.deadline.toISOString(),
      status: updatedRequest.status,
      priority: updatedRequest.priority,
      queuePosition: updatedRequest.queuePosition,
      processedAt: updatedRequest.processedAt?.toISOString() || null,
      txHash: updatedRequest.txHash,
      actualAssets: updatedRequest.actualAssets?.toString() || null,
      gasCost: updatedRequest.gasCost?.toString() || null,
      adminNotes: updatedRequest.adminNotes,
      rejectionReason: updatedRequest.rejectionReason,
      createdAt: updatedRequest.createdAt.toISOString(),
      updatedAt: updatedRequest.updatedAt.toISOString(),
    }

    return NextResponse.json(serializeBigInt(response))
  } catch (error) {
    console.error('Error processing redemption request:', error)
    return NextResponse.json(
      { error: 'Failed to process redemption request' },
      { status: 500 }
    )
  }
}

// Route is exported directly as POST function