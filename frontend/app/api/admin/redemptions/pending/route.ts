import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { serializeBigInt } from '@/lib/utils'
import { RedemptionStatus } from '@prisma/client'

// GET /api/admin/redemptions/pending - Get all pending/approved redemption requests
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const deploymentId = searchParams.get('deploymentId')
    const includeApproved = searchParams.get('includeApproved') === 'true'
    
    if (!deploymentId) {
      return NextResponse.json(
        { error: 'deploymentId is required' },
        { status: 400 }
      )
    }

    const statuses: RedemptionStatus[] = [RedemptionStatus.PENDING]
    if (includeApproved) {
      statuses.push(RedemptionStatus.APPROVED)
    }

    const requests = await prisma.redemptionRequest.findMany({
      where: {
        deploymentId,
        status: { in: statuses }
      },
      orderBy: [
        { priority: 'desc' },
        { queuePosition: 'asc' },
        { createdAt: 'asc' }
      ],
      take: 100
    })

    // Calculate totals
    const totals = {
      count: requests.length,
      totalShares: requests.reduce((sum, req) => sum + req.shareAmount, 0n),
      totalExpectedAssets: requests.reduce((sum, req) => sum + BigInt(req.expectedAssets), 0n),
      pendingCount: requests.filter(r => r.status === 'PENDING').length,
      approvedCount: requests.filter(r => r.status === 'APPROVED').length,
    }

    return NextResponse.json(serializeBigInt({
      requests,
      totals,
      timestamp: new Date().toISOString()
    }))
  } catch (error) {
    console.error('Error fetching pending redemptions:', error)
    return NextResponse.json(
      { error: 'Failed to fetch pending redemptions' },
      { status: 500 }
    )
  }
}