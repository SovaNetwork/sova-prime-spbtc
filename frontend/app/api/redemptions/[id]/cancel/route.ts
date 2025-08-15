import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { RedemptionStatus } from '@/lib/redemption-api'
import { serializeBigInt } from '@/lib/utils'

// POST /api/redemptions/[id]/cancel - Cancel a redemption request
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { reason } = body

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

    // Validate current status - can only cancel pending, approved, or failed requests
    const cancellableStatuses = [
      RedemptionStatus.PENDING,
      RedemptionStatus.APPROVED,
      RedemptionStatus.FAILED,
    ]

    if (!cancellableStatuses.includes(existingRequest.status as RedemptionStatus)) {
      return NextResponse.json(
        { error: `Cannot cancel request with status: ${existingRequest.status}` },
        { status: 400 }
      )
    }

    // Update the request
    const updatedRequest = await prisma.redemptionRequest.update({
      where: { id },
      data: {
        status: RedemptionStatus.CANCELLED,
        rejectionReason: reason || 'Cancelled by user/admin',
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
        type: 'REDEMPTION_CANCELLED',
        description: `Redemption request cancelled`,
        metadata: {
          requestId: updatedRequest.id,
          reason: reason || 'Cancelled by user/admin',
          previousStatus: existingRequest.status,
        },
      },
    })

    // If this was an approved request, we need to update queue positions for remaining requests
    if (existingRequest.status === RedemptionStatus.APPROVED && existingRequest.queuePosition) {
      await prisma.redemptionRequest.updateMany({
        where: {
          deploymentId: existingRequest.deploymentId,
          status: RedemptionStatus.APPROVED,
          queuePosition: {
            gt: existingRequest.queuePosition,
          },
        },
        data: {
          queuePosition: {
            decrement: 1,
          },
        },
      })
    }

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
    console.error('Error cancelling redemption request:', error)
    return NextResponse.json(
      { error: 'Failed to cancel redemption request' },
      { status: 500 }
    )
  }
}

// Route is exported directly as POST function