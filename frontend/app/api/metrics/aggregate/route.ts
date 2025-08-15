import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
// No auth middleware needed

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const includeChainBreakdown = searchParams.get('includeChainBreakdown') === 'true';
    const activeOnly = searchParams.get('activeOnly') !== 'false'; // Default to true

    // Get latest metrics from each active deployment
    const deployments = await prisma.sovaBtcDeployment.findMany({
      where: activeOnly ? { status: 'ACTIVE' } : {},
      include: {
        network: true,
        metrics: {
          orderBy: { timestamp: 'desc' },
          take: 1,
        },
        collaterals: {
          where: { isActive: true },
          select: {
            symbol: true,
            name: true,
            chainId: true,
          },
        },
      },
    });

    let totalTvl = 0;
    let totalSupply = 0;
    let totalUsers = 0;
    let totalTransactions = 0;
    let weightedSharePriceSum = 0;
    let totalSupplyForWeighting = 0;

    const chainBreakdown: any[] = [];
    const supportedCollaterals = new Set<string>();

    deployments.forEach(deployment => {
      const latestMetric = deployment.metrics[0];
      
      if (latestMetric) {
        const tvl = parseFloat(latestMetric.tvl.toString());
        const supply = parseFloat(latestMetric.totalSupply.toString());
        const sharePrice = parseFloat(latestMetric.sharePrice.toString());
        
        totalTvl += tvl;
        totalSupply += supply;
        totalUsers += latestMetric.users;
        totalTransactions += latestMetric.transactions;
        
        // Weighted average share price calculation
        weightedSharePriceSum += sharePrice * supply;
        totalSupplyForWeighting += supply;

        if (includeChainBreakdown) {
          chainBreakdown.push({
            chainId: deployment.chainId,
            networkName: deployment.network.name,
            tvl: latestMetric.tvl.toString(),
            totalSupply: latestMetric.totalSupply.toString(),
            sharePrice: latestMetric.sharePrice.toString(),
            users: latestMetric.users,
            transactions: latestMetric.transactions,
            apy: latestMetric.apy?.toString() || null,
            collateralsCount: deployment.collaterals.length,
            lastUpdated: latestMetric.timestamp,
            deployment: {
              id: deployment.id,
              vaultToken: deployment.vaultToken,
              vaultStrategy: deployment.vaultStrategy,
              status: deployment.status,
              verified: deployment.verified,
            },
          });
        }

        // Collect unique collaterals across all chains
        deployment.collaterals.forEach(collateral => {
          supportedCollaterals.add(collateral.symbol);
        });
      }
    });

    // Calculate weighted average share price
    const avgSharePrice = totalSupplyForWeighting > 0 
      ? weightedSharePriceSum / totalSupplyForWeighting 
      : 0;

    // Get network status summary
    const networkStatuses = await prisma.sovaBtcNetworkMetrics.findMany({
      where: {
        chainId: { in: deployments.map(d => d.chainId) },
      },
      distinct: ['chainId'],
      orderBy: { timestamp: 'desc' },
      select: {
        chainId: true,
        isOnline: true,
        timestamp: true,
      },
    });

    const onlineChains = networkStatuses.filter(n => n.isOnline).length;
    const totalChains = networkStatuses.length;

    const response = {
      summary: {
        totalTvl: totalTvl.toString(),
        totalSupply: totalSupply.toString(),
        avgSharePrice: avgSharePrice.toString(),
        totalUsers,
        totalTransactions,
        supportedChainsCount: deployments.length,
        onlineChainsCount: onlineChains,
        totalChainsCount: totalChains,
        uniqueCollateralsCount: supportedCollaterals.size,
        lastUpdated: new Date().toISOString(),
      },
      collaterals: Array.from(supportedCollaterals),
      networkHealth: {
        onlinePercentage: totalChains > 0 ? ((onlineChains / totalChains) * 100).toFixed(1) : '0',
        chains: networkStatuses.map(status => ({
          chainId: status.chainId,
          isOnline: status.isOnline,
          lastChecked: status.timestamp,
        })),
      },
      ...(includeChainBreakdown && { chainBreakdown }),
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Failed to fetch aggregated metrics:', error);
    return NextResponse.json(
      { error: 'Failed to fetch aggregated metrics' },
      { status: 500 }
    );
  }
}

// Route is exported directly as GET function