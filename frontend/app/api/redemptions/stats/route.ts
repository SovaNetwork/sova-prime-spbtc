import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { RedemptionStatus } from '@/lib/redemption-api'
import { serializeBigInt } from '@/lib/utils'

// GET /api/redemptions/stats - Get queue statistics
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const deploymentId = searchParams.get('deploymentId')

    // Build where clause
    const where: any = {}
    if (deploymentId) {
      where.deploymentId = deploymentId
    }

    // Get counts by status
    const statusCounts = await prisma.redemptionRequest.groupBy({
      by: ['status'],
      where,
      _count: {
        id: true,
      },
    })

    // Convert to object for easier access
    const counts = statusCounts.reduce((acc, item) => {
      acc[item.status] = item._count.id
      return acc
    }, {} as Record<string, number>)

    // Get queue length (approved requests)
    const queueLength = counts[RedemptionStatus.APPROVED] || 0

    // Calculate average processing time for completed requests
    const completedRequests = await prisma.redemptionRequest.findMany({
      where: {
        ...where,
        status: RedemptionStatus.COMPLETED,
        processedAt: { not: null },
      },
      select: {
        createdAt: true,
        processedAt: true,
      },
    })

    let averageProcessingTime: number | null = null
    if (completedRequests.length > 0) {
      const totalProcessingTime = completedRequests.reduce((sum, request) => {
        if (request.processedAt) {
          const processingTime = request.processedAt.getTime() - request.createdAt.getTime()
          return sum + processingTime
        }
        return sum
      }, 0)
      
      averageProcessingTime = Math.floor(totalProcessingTime / completedRequests.length / 1000) // Convert to seconds
    }

    // Get total requests count
    const totalRequests = await prisma.redemptionRequest.count({ where })

    const stats = {
      totalRequests,
      pendingRequests: counts[RedemptionStatus.PENDING] || 0,
      approvedRequests: counts[RedemptionStatus.APPROVED] || 0,
      processingRequests: counts[RedemptionStatus.PROCESSING] || 0,
      completedRequests: counts[RedemptionStatus.COMPLETED] || 0,
      failedRequests: counts[RedemptionStatus.FAILED] || 0,
      cancelledRequests: counts[RedemptionStatus.CANCELLED] || 0,
      rejectedRequests: counts[RedemptionStatus.REJECTED] || 0,
      expiredRequests: counts[RedemptionStatus.EXPIRED] || 0,
      averageProcessingTime,
      queueLength,
    }

    return NextResponse.json(serializeBigInt(stats))
  } catch (error) {
    console.error('Error fetching redemption stats:', error)
    return NextResponse.json(
      { error: 'Failed to fetch redemption stats' },
      { status: 500 }
    )
  }
}