import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { serializeBigInt } from '@/lib/utils'

// POST /api/admin/redemptions/approve - Approve multiple redemption requests
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { requestIds, adminNotes } = body

    if (!requestIds || !Array.isArray(requestIds) || requestIds.length === 0) {
      return NextResponse.json(
        { error: 'requestIds array is required' },
        { status: 400 }
      )
    }

    // Update all requests to APPROVED status
    const updatePromises = requestIds.map(async (id: string) => {
      // First get the current max queue position for approved requests
      const maxQueuePosition = await prisma.redemptionRequest.aggregate({
        where: {
          status: 'APPROVED'
        },
        _max: {
          queuePosition: true
        }
      })

      const nextPosition = (maxQueuePosition._max.queuePosition || 0) + 1

      return prisma.redemptionRequest.update({
        where: { id },
        data: {
          status: 'APPROVED',
          queuePosition: nextPosition,
          adminNotes: adminNotes || undefined,
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
          type: 'REDEMPTION_APPROVED',
          description: `Redemption request ${request.id} approved`,
          metadata: serializeBigInt({
            requestId: request.id,
            userAddress: request.userAddress,
            shareAmount: request.shareAmount,
            adminNotes
          })
        }
      })
    )

    await Promise.all(activityPromises)

    return NextResponse.json(serializeBigInt({
      success: true,
      approvedCount: updatedRequests.length,
      requests: updatedRequests
    }))
  } catch (error) {
    console.error('Error approving redemptions:', error)
    return NextResponse.json(
      { error: 'Failed to approve redemptions' },
      { status: 500 }
    )
  }
}