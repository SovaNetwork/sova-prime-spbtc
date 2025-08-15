import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { verifyTypedData } from 'viem'
import { RedemptionStatus } from '@/lib/redemption-api'
import { serializeBigInt } from '@/lib/utils'
import {
  validateRedemptionRequest,
  isSignatureExpired,
  createRedemptionDomain,
  REDEMPTION_TYPES,
} from '@/lib/eip712'

// GET /api/redemptions - Get redemption requests with filtering and pagination
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    
    // Parse query parameters
    const statusParams = searchParams.getAll('status')
    const userAddress = searchParams.get('userAddress')
    const deploymentId = searchParams.get('deploymentId')
    const page = parseInt(searchParams.get('page') || '1')
    const limit = Math.min(parseInt(searchParams.get('limit') || '20'), 100) // Cap at 100

    // Build where clause
    const where: any = {}
    
    if (statusParams.length > 0) {
      where.status = { in: statusParams }
    }
    
    if (userAddress) {
      where.userAddress = userAddress.toLowerCase()
    }
    
    if (deploymentId) {
      where.deploymentId = deploymentId
    }

    // Get total count
    const totalCount = await prisma.redemptionRequest.count({ where })

    // Get requests with pagination
    const requests = await prisma.redemptionRequest.findMany({
      where,
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
      orderBy: [
        { createdAt: 'desc' },
      ],
      skip: (page - 1) * limit,
      take: limit,
    })

    // Format response
    const formattedRequests = requests.map(request => ({
      id: request.id,
      deploymentId: request.deploymentId,
      userAddress: request.userAddress,
      shareAmount: request.shareAmount.toString(),
      expectedAssets: request.expectedAssets.toString(),
      minAssetsOut: request.minAssetsOut.toString(),
      signature: request.signature,
      nonce: request.nonce.toString(),
      deadline: request.deadline.toISOString(),
      status: request.status,
      priority: request.priority,
      queuePosition: request.queuePosition,
      processedAt: request.processedAt?.toISOString() || null,
      txHash: request.txHash,
      actualAssets: request.actualAssets?.toString() || null,
      gasCost: request.gasCost?.toString() || null,
      adminNotes: request.adminNotes,
      rejectionReason: request.rejectionReason,
      createdAt: request.createdAt.toISOString(),
      updatedAt: request.updatedAt.toISOString(),
      deployment: {
        chainId: request.deployment.chainId,
        vaultToken: request.deployment.vaultToken,
        network: request.deployment.network,
      },
    }))

    return NextResponse.json(serializeBigInt({
      requests: formattedRequests,
      totalCount,
      page,
      limit,
    }))
  } catch (error) {
    console.error('Error fetching redemption requests:', error)
    return NextResponse.json(
      { error: 'Failed to fetch redemption requests' },
      { status: 500 }
    )
  }
}

// POST /api/redemptions - Submit a new redemption request
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { deploymentId, expectedAssets, signedRequest } = body

    // Validate required fields
    if (!deploymentId || !expectedAssets || !signedRequest) {
      return NextResponse.json(
        { error: 'Missing required fields: deploymentId, expectedAssets, signedRequest' },
        { status: 400 }
      )
    }

    // Get deployment info
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { id: deploymentId },
      include: { network: true },
    })

    if (!deployment) {
      return NextResponse.json(
        { error: 'Deployment not found' },
        { status: 404 }
      )
    }

    // Validate the signed request
    const requestData = {
      user: signedRequest.user,
      shareAmount: signedRequest.shareAmount,
      minAssetsOut: signedRequest.minAssetsOut,
      nonce: signedRequest.nonce,
      deadline: signedRequest.deadline,
    }

    const validationErrors = validateRedemptionRequest(requestData)
    if (validationErrors.length > 0) {
      return NextResponse.json(
        { error: `Validation failed: ${validationErrors.join(', ')}` },
        { status: 400 }
      )
    }

    // Check if signature is expired
    if (isSignatureExpired(requestData.deadline)) {
      return NextResponse.json(
        { error: 'Signature has expired' },
        { status: 400 }
      )
    }

    // Check for duplicate nonce
    const existingRequest = await prisma.redemptionRequest.findUnique({
      where: {
        deploymentId_nonce: {
          deploymentId,
          nonce: BigInt(requestData.nonce),
        },
      },
    })

    if (existingRequest) {
      return NextResponse.json(
        { error: 'Nonce already used' },
        { status: 400 }
      )
    }

    // Verify the EIP-712 signature
    try {
      const domain = createRedemptionDomain(
        deployment.chainId,
        deployment.vaultToken as `0x${string}`
      )

      // Verify the EIP-712 signature
      const isValid = await verifyTypedData({
        address: signedRequest.user,
        domain,
        types: REDEMPTION_TYPES,
        primaryType: 'RedemptionRequest',
        message: requestData,
        signature: signedRequest.signature,
      })

      if (!isValid) {
        return NextResponse.json(
          { error: 'Invalid signature' },
          { status: 400 }
        )
      }
    } catch (error) {
      console.error('Signature verification failed:', error)
      return NextResponse.json(
        { error: 'Invalid signature' },
        { status: 400 }
      )
    }

    // Create the redemption request
    const redemptionRequest = await prisma.redemptionRequest.create({
      data: {
        deploymentId,
        userAddress: signedRequest.user.toLowerCase(),
        shareAmount: BigInt(signedRequest.shareAmount),
        expectedAssets: BigInt(expectedAssets),
        minAssetsOut: BigInt(signedRequest.minAssetsOut),
        signature: signedRequest.signature,
        nonce: BigInt(signedRequest.nonce),
        deadline: new Date(Number(signedRequest.deadline) * 1000),
        status: RedemptionStatus.PENDING,
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
        deploymentId,
        type: 'REDEMPTION_REQUEST',
        description: `Redemption request submitted for ${signedRequest.shareAmount} shares`,
        metadata: {
          userAddress: signedRequest.user,
          shareAmount: signedRequest.shareAmount.toString(),
          expectedAssets: expectedAssets,
          requestId: redemptionRequest.id,
        },
      },
    })

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
    }

    return NextResponse.json(serializeBigInt(response), { status: 201 })
  } catch (error) {
    console.error('Error creating redemption request:', error)
    return NextResponse.json(
      { error: 'Failed to create redemption request' },
      { status: 500 }
    )
  }
}