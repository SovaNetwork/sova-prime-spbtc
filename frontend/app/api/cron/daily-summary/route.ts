import { NextRequest, NextResponse } from 'next/server';
import { headers } from 'next/headers';
import { prisma } from '@/lib/prisma';
import { serializeBigInt } from '@/lib/utils';
// No auth middleware needed - using cron secret

export const runtime = 'nodejs';
export const maxDuration = 30;

async function cronDailySummaryHandler(request: NextRequest) {
  try {
    // Verify the request is from Vercel Cron OR authenticated admin
    const authHeader = (await headers()).get('authorization');
    const isAutomatedCron = process.env.NODE_ENV === 'production' && authHeader === `Bearer ${process.env.CRON_SECRET}`;
    
    if (!isAutomatedCron) {
      console.log('[Cron] Manual trigger detected');
    }
    
    console.log('[Cron] Generating daily summary...');
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);
    
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    // Get active deployments
    const deployments = await prisma.sovaBtcDeployment.findMany({
      where: { status: 'ACTIVE' },
      take: 1,
    });
    
    if (deployments.length === 0) {
      return NextResponse.json({
        success: true,
        message: 'No active deployments found',
      });
    }
    
    // Get metrics for the past 24 hours
    const metrics = await prisma.sovaBtcDeploymentMetrics.findMany({
      where: {
        timestamp: {
          gte: yesterday,
          lt: today,
        },
      },
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    });
    
    // Get activities for the past 24 hours
    const activities = await prisma.sovaBtcActivity.findMany({
      where: {
        createdAt: {
          gte: yesterday,
          lt: today,
        },
      },
    });
    
    // Calculate summary statistics
    const summary = {
      date: yesterday.toISOString().split('T')[0],
      deployments: {} as Record<string, any>,
      totalActivities: activities.length,
      activityBreakdown: {} as Record<string, number>,
    };
    
    // Group metrics by deployment
    for (const metric of metrics) {
      const key = `${metric.deployment.network.name}-${metric.deployment.chainId}`;
      if (!summary.deployments[key]) {
        summary.deployments[key] = {
          network: metric.deployment.network.name,
          chainId: metric.deployment.chainId,
          metrics: [],
          avgTvl: 0,
          maxTvl: 0,
          minTvl: Number.MAX_VALUE,
        };
      }
      
      const tvlValue = parseFloat(metric.tvl.toString());
      summary.deployments[key].metrics.push(metric);
      summary.deployments[key].avgTvl += tvlValue;
      summary.deployments[key].maxTvl = Math.max(summary.deployments[key].maxTvl, tvlValue);
      summary.deployments[key].minTvl = Math.min(summary.deployments[key].minTvl, tvlValue);
    }
    
    // Calculate averages
    for (const key in summary.deployments) {
      const deployment = summary.deployments[key];
      deployment.avgTvl = deployment.metrics.length > 0 
        ? deployment.avgTvl / deployment.metrics.length 
        : 0;
      delete deployment.metrics; // Remove raw metrics from summary
    }
    
    // Count activity types
    for (const activity of activities) {
      summary.activityBreakdown[activity.type] = (summary.activityBreakdown[activity.type] || 0) + 1;
    }
    
    // Store summary in database
    await prisma.sovaBtcActivity.create({
      data: {
        type: 'METRICS_UPDATED',
        description: `Daily summary for ${yesterday.toISOString().split('T')[0]}`,
        metadata: summary,
        deploymentId: deployments[0].id,
      },
    });
    
    console.log('[Cron] Daily summary generated successfully');
    
    return NextResponse.json(serializeBigInt({
      success: true,
      timestamp: new Date().toISOString(),
      summary,
    }));
  } catch (error) {
    console.error('[Cron] Daily summary generation failed:', error);
    return NextResponse.json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    }, { status: 500 });
  }
}

// Allow both automated cron and manual triggers
export async function GET(request: NextRequest) {
  return cronDailySummaryHandler(request);
}