import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { ActivityType } from '@prisma/client';

// GET /api/activity - Get recent activities with pagination
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    
    // Parse query parameters
    const page = parseInt(searchParams.get('page') || '1');
    const limit = parseInt(searchParams.get('limit') || '20');
    const chainIds = searchParams.getAll('chainId').map(id => parseInt(id)).filter(id => !isNaN(id));
    const singleChainId = searchParams.get('chainId');
    const type = searchParams.get('type') as ActivityType | null;
    
    const skip = (page - 1) * limit;

    // Build where clause
    const where: any = {};
    
    // Support both single chainId and multiple chainIds
    if (chainIds.length > 0) {
      const deployments = await prisma.sovaBtcDeployment.findMany({
        where: { chainId: { in: chainIds } },
        select: { id: true },
      });
      if (deployments.length > 0) {
        where.deploymentId = { in: deployments.map(d => d.id) };
      }
    } else if (singleChainId) {
      const deployment = await prisma.sovaBtcDeployment.findUnique({
        where: { chainId: parseInt(singleChainId) },
        select: { id: true },
      });
      if (deployment) {
        where.deploymentId = deployment.id;
      }
    }
    
    if (type) {
      where.type = type;
    }

    // Get activities
    const [activities, total] = await Promise.all([
      prisma.sovaBtcActivity.findMany({
        where,
        include: {
          deployment: {
            include: {
              network: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limit,
      }),
      prisma.sovaBtcActivity.count({ where }),
    ]);

    return NextResponse.json({
      activities,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('Error fetching activities:', error);
    return NextResponse.json(
      { error: 'Failed to fetch activities' },
      { status: 500 }
    );
  }
}

// POST /api/activity - Log new activity
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { chainId, type, description, metadata, txHash } = body;

    // Validate required fields
    if (!chainId || !type || !description) {
      return NextResponse.json(
        { error: 'Missing required fields: chainId, type, description' },
        { status: 400 }
      );
    }

    // Validate activity type
    if (!Object.values(ActivityType).includes(type)) {
      return NextResponse.json(
        { error: `Invalid activity type. Must be one of: ${Object.values(ActivityType).join(', ')}` },
        { status: 400 }
      );
    }

    // Get deployment
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { chainId },
    });

    if (!deployment) {
      return NextResponse.json(
        { error: 'Deployment not found' },
        { status: 404 }
      );
    }

    // Create activity
    const activity = await prisma.sovaBtcActivity.create({
      data: {
        deploymentId: deployment.id,
        type,
        description,
        metadata: metadata || null,
        txHash: txHash || null,
      },
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    });

    return NextResponse.json(activity, { status: 201 });
  } catch (error) {
    console.error('Error creating activity:', error);
    return NextResponse.json(
      { error: 'Failed to create activity' },
      { status: 500 }
    );
  }
}