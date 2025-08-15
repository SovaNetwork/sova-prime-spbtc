import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
// No auth middleware needed

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const activeOnly = searchParams.get('activeOnly') !== 'false'; // Default to true
    const groupBySymbol = searchParams.get('groupBySymbol') === 'true';

    // Get all collaterals across all chains
    const collaterals = await prisma.sovaBtcCollateral.findMany({
      where: {
        ...(activeOnly && { isActive: true }),
        deployment: {
          status: 'ACTIVE',
        },
      },
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
      orderBy: [
        { symbol: 'asc' },
        { deployment: { network: { isTestnet: 'asc' } } },
        { name: 'asc' },
      ],
    });

    if (groupBySymbol) {
      // Group collaterals by symbol across chains
      const grouped = collaterals.reduce((acc, collateral) => {
        if (!acc[collateral.symbol]) {
          acc[collateral.symbol] = {
            symbol: collateral.symbol,
            name: collateral.name,
            decimals: collateral.decimals,
            logoUri: collateral.logoUri,
            coingeckoId: collateral.coingeckoId,
            isVerified: collateral.isVerified,
            deployments: [],
            chainsCount: 0,
            totalDeployments: 0,
          };
        }

        acc[collateral.symbol].deployments.push({
          chainId: collateral.chainId,
          networkName: collateral.deployment.network.name,
          isTestnet: collateral.deployment.network.isTestnet,
          address: collateral.address,
          deploymentId: collateral.deploymentId,
          isActive: collateral.isActive,
          verified: collateral.deployment.verified,
        });

        acc[collateral.symbol].chainsCount = acc[collateral.symbol].deployments.length;
        acc[collateral.symbol].totalDeployments++;

        return acc;
      }, {} as Record<string, any>);

      const groupedArray = Object.values(grouped);

      return NextResponse.json({
        collaterals: groupedArray,
        summary: {
          uniqueSymbols: groupedArray.length,
          totalDeployments: collaterals.length,
          averageDeploymentsPerSymbol: groupedArray.length > 0 
            ? (collaterals.length / groupedArray.length).toFixed(1)
            : '0',
          verifiedSymbols: groupedArray.filter((c: any) => 
            c.deployments.some((d: any) => d.verified)
          ).length,
        },
      });
    } else {
      // Return flat list with chain information
      const collateralsList = collaterals.map(collateral => ({
        id: collateral.id,
        symbol: collateral.symbol,
        name: collateral.name,
        address: collateral.address,
        decimals: collateral.decimals,
        chainId: collateral.chainId,
        isActive: collateral.isActive,
        isVerified: collateral.isVerified,
        logoUri: collateral.logoUri,
        coingeckoId: collateral.coingeckoId,
        deployment: {
          id: collateral.deploymentId,
          status: collateral.deployment.status,
          verified: collateral.deployment.verified,
        },
        network: {
          name: collateral.deployment.network.name,
          isTestnet: collateral.deployment.network.isTestnet,
          blockExplorer: collateral.deployment.network.blockExplorer,
        },
        createdAt: collateral.createdAt,
        updatedAt: collateral.updatedAt,
      }));

      // Create summary by chain
      const chainSummary = collaterals.reduce((acc, collateral) => {
        const chainId = collateral.chainId.toString();
        if (!acc[chainId]) {
          acc[chainId] = {
            chainId: collateral.chainId,
            networkName: collateral.deployment.network.name,
            isTestnet: collateral.deployment.network.isTestnet,
            collateralsCount: 0,
            uniqueSymbols: new Set<string>(),
            verifiedCount: 0,
          };
        }

        acc[chainId].collateralsCount++;
        acc[chainId].uniqueSymbols.add(collateral.symbol);
        if (collateral.isVerified) {
          acc[chainId].verifiedCount++;
        }

        return acc;
      }, {} as Record<string, any>);

      const chainSummaryArray = Object.values(chainSummary).map((summary: any) => ({
        ...summary,
        uniqueSymbols: summary.uniqueSymbols.size,
      }));

      return NextResponse.json({
        collaterals: collateralsList,
        chainSummary: chainSummaryArray,
        summary: {
          totalCollaterals: collaterals.length,
          uniqueSymbols: new Set(collaterals.map(c => c.symbol)).size,
          supportedChains: chainSummaryArray.length,
          verifiedCollaterals: collaterals.filter(c => c.isVerified).length,
          activeCollaterals: collaterals.filter(c => c.isActive).length,
        },
      });
    }
  } catch (error) {
    console.error('Failed to fetch collaterals summary:', error);
    return NextResponse.json(
      { error: 'Failed to fetch collaterals summary' },
      { status: 500 }
    );
  }
}

// Route is exported directly as GET function