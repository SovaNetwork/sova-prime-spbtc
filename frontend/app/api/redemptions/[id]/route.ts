import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { RedemptionStatus } from '@/lib/redemption-api'
import { serializeBigInt } from '@/lib/utils'

// GET /api/redemptions/[id] - Get a specific redemption request
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params

    const redemptionRequest = await prisma.redemptionRequest.findUnique({
      where: { id },
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    })

    if (!redemptionRequest) {
      return NextResponse.json(
        { error: 'Redemption request not found' },
        { status: 404 }
      )
    }

    // Format response
    const response = {
      id: redemptionRequest.id,
      deploymentId: redemptionRequest.deploymentId,
      userAddress: redemptionRequest.userAddress,
      shareAmount: redemptionRequest.shareAmount.toString(),
      expectedAssets: redemptionRequest.expectedAssets.toString(),
      minAssetsOut: redemptionRequest.minAssetsOut.toString(),
      signature: redemptionRequest.signature,
      nonce: redemptionRequest.nonce.toString(),
      deadline: redemptionRequest.deadline.toISOString(),
      status: redemptionRequest.status,
      priority: redemptionRequest.priority,
      queuePosition: redemptionRequest.queuePosition,
      processedAt: redemptionRequest.processedAt?.toISOString() || null,
      txHash: redemptionRequest.txHash,
      actualAssets: redemptionRequest.actualAssets?.toString() || null,
      gasCost: redemptionRequest.gasCost?.toString() || null,
      adminNotes: redemptionRequest.adminNotes,
      rejectionReason: redemptionRequest.rejectionReason,
      createdAt: redemptionRequest.createdAt.toISOString(),
      updatedAt: redemptionRequest.updatedAt.toISOString(),
      deployment: {
        chainId: redemptionRequest.deployment.chainId,
        vaultToken: redemptionRequest.deployment.vaultToken,
        network: redemptionRequest.deployment.network,
      },
    }

    return NextResponse.json(serializeBigInt(response))
  } catch (error) {
    console.error('Error fetching redemption request:', error)
    return NextResponse.json(
      { error: 'Failed to fetch redemption request' },
      { status: 500 }
    )
  }
}

// PATCH /api/redemptions/[id] - Update redemption request status (admin only)
export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { status, adminNotes, rejectionReason, priority } = body

    // Validate status
    if (status && !Object.values(RedemptionStatus).includes(status)) {
      return NextResponse.json(
        { error: 'Invalid status value' },
        { status: 400 }
      )
    }

    // Check if redemption request exists
    const existingRequest = await prisma.redemptionRequest.findUnique({
      where: { id },
    })

    if (!existingRequest) {
      return NextResponse.json(
        { error: 'Redemption request not found' },
        { status: 404 }
      )
    }

    // Validate status transitions
    const validTransitions: Record<string, string[]> = {
      [RedemptionStatus.PENDING]: [
        RedemptionStatus.APPROVED,
        RedemptionStatus.REJECTED,
        RedemptionStatus.CANCELLED,
        RedemptionStatus.EXPIRED,
      ],
      [RedemptionStatus.APPROVED]: [
        RedemptionStatus.PROCESSING,
        RedemptionStatus.CANCELLED,
        RedemptionStatus.EXPIRED,
      ],
      [RedemptionStatus.PROCESSING]: [
        RedemptionStatus.COMPLETED,
        RedemptionStatus.FAILED,
      ],
      [RedemptionStatus.FAILED]: [
        RedemptionStatus.PROCESSING,
        RedemptionStatus.CANCELLED,
      ],
    }

    if (status && status !== existingRequest.status) {
      const allowedTransitions = validTransitions[existingRequest.status] || []
      if (!allowedTransitions.includes(status)) {
        return NextResponse.json(
          { error: `Cannot transition from ${existingRequest.status} to ${status}` },
          { status: 400 }
        )
      }
    }

    // Prepare update data
    const updateData: any = {}
    
    if (status !== undefined) updateData.status = status
    if (adminNotes !== undefined) updateData.adminNotes = adminNotes
    if (rejectionReason !== undefined) updateData.rejectionReason = rejectionReason
    if (priority !== undefined) updateData.priority = priority

    // Update queue position if status is changing to APPROVED
    if (status === RedemptionStatus.APPROVED && existingRequest.status !== RedemptionStatus.APPROVED) {
      const maxQueuePosition = await prisma.redemptionRequest.aggregate({
        where: {
          deploymentId: existingRequest.deploymentId,
          status: RedemptionStatus.APPROVED,
        },
        _max: {
          queuePosition: true,
        },
      })
      
      updateData.queuePosition = (maxQueuePosition._max.queuePosition || 0) + 1
    }

    // Clear queue position if moving away from APPROVED status
    if (status && status !== RedemptionStatus.APPROVED && existingRequest.status === RedemptionStatus.APPROVED) {
      updateData.queuePosition = null
    }

    // Update the request
    const updatedRequest = await prisma.redemptionRequest.update({
      where: { id },
      data: updateData,
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    })

    // Create activity record if status changed
    if (status && status !== existingRequest.status) {
      await prisma.sovaBtcActivity.create({
        data: {
          deploymentId: updatedRequest.deploymentId,
          type: 'REDEMPTION_PROCESSED',
          description: `Redemption request status updated to ${status}`,
          metadata: {
            requestId: updatedRequest.id,
            previousStatus: existingRequest.status,
            newStatus: status,
            adminNotes,
            rejectionReason,
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
    console.error('Error updating redemption request:', error)
    return NextResponse.json(
      { error: 'Failed to update redemption request' },
      { status: 500 }
    )
  }
}