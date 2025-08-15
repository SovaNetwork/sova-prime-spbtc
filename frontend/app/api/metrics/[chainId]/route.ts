import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { serializeBigInt } from '@/lib/utils';

// GET /api/metrics/[chainId] - Get historical metrics for a deployment
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ chainId: string }> }
) {
  try {
    const { chainId: chainIdStr } = await params;
    const chainId = parseInt(chainIdStr);
    const searchParams = request.nextUrl.searchParams;
    
    // Parse query parameters
    const limit = parseInt(searchParams.get('limit') || '100');
    const period = searchParams.get('period') || '24h'; // 1h, 24h, 7d, 30d, all
    
    // Calculate date range based on period
    let startDate = new Date();
    switch (period) {
      case '1h':
        startDate.setHours(startDate.getHours() - 1);
        break;
      case '24h':
        startDate.setDate(startDate.getDate() - 1);
        break;
      case '7d':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(startDate.getDate() - 30);
        break;
      case 'all':
        startDate = new Date(0); // Beginning of time
        break;
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

    // Get metrics
    const metrics = await prisma.sovaBtcDeploymentMetrics.findMany({
      where: {
        deploymentId: deployment.id,
        timestamp: {
          gte: startDate,
        },
      },
      orderBy: { timestamp: 'desc' },
      take: limit,
    });

    // Get network metrics
    const networkMetrics = await prisma.sovaBtcNetworkMetrics.findMany({
      where: {
        chainId,
        timestamp: {
          gte: startDate,
        },
      },
      orderBy: { timestamp: 'desc' },
      take: limit,
    });

    // Calculate aggregates
    const aggregates = {
      averageTvl: metrics.length > 0
        ? metrics.reduce((sum, m) => sum + parseFloat(m.tvl.toString()), 0) / metrics.length
        : 0,
      maxTvl: metrics.length > 0
        ? Math.max(...metrics.map(m => parseFloat(m.tvl.toString())))
        : 0,
      minTvl: metrics.length > 0
        ? Math.min(...metrics.map(m => parseFloat(m.tvl.toString())))
        : 0,
      latestTvl: metrics[0]?.tvl.toString() || '0',
      latestSharePrice: metrics[0]?.sharePrice.toString() || '1000000000000000000',
      latestApy: metrics[0]?.apy?.toString() || '0',
      totalUsers: metrics[0]?.users || 0,
      totalTransactions: metrics[0]?.transactions || 0,
    };

    return NextResponse.json(serializeBigInt({
      deployment,
      metrics,
      networkMetrics,
      aggregates,
      period,
      count: metrics.length,
    }));
  } catch (error) {
    console.error('Error fetching metrics:', error);
    return NextResponse.json(
      { error: 'Failed to fetch metrics' },
      { status: 500 }
    );
  }
}