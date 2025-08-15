import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { DeploymentStatus } from '@prisma/client';
// No auth middleware needed

// GET /api/deployments - Fetch all deployments with relations
export async function GET(request: NextRequest) {
  try {
    const deployments = await prisma.sovaBtcDeployment.findMany({
      include: {
        network: true,
        collaterals: true,
        metrics: {
          orderBy: { timestamp: 'desc' },
          take: 1, // Get latest metrics only
        },
        activities: {
          orderBy: { createdAt: 'desc' },
          take: 5, // Get last 5 activities
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json(deployments);
  } catch (error) {
    console.error('Error fetching deployments:', error);
    return NextResponse.json(
      { error: 'Failed to fetch deployments' },
      { status: 500 }
    );
  }
}

// POST /api/deployments - Create new deployment
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      chainId,
      vaultStrategy,
      vaultToken,
      priceOracle,
      status = DeploymentStatus.NOT_DEPLOYED,
      deployer,
      blockNumber,
      transactionHash,
      verified = false,
      collaterals = [],
    } = body;

    // First, ensure the network exists
    const network = await prisma.sovaBtcNetwork.findUnique({
      where: { chainId },
    });

    if (!network) {
      // Create network if it doesn't exist
      const networkData = body.network;
      if (!networkData) {
        return NextResponse.json(
          { error: 'Network not found and no network data provided' },
          { status: 400 }
        );
      }

      await prisma.sovaBtcNetwork.create({
        data: {
          chainId,
          name: networkData.name,
          rpcUrl: networkData.rpcUrl,
          blockExplorer: networkData.blockExplorer,
          nativeCurrency: networkData.nativeCurrency,
          isTestnet: networkData.isTestnet || false,
        },
      });
    }

    // Create deployment with collaterals
    const deployment = await prisma.sovaBtcDeployment.create({
      data: {
        chainId,
        vaultStrategy,
        vaultToken,
        priceOracle,
        status,
        deployer,
        blockNumber,
        transactionHash,
        verified,
        collaterals: {
          create: collaterals.map((collateral: any) => ({
            symbol: collateral.symbol,
            name: collateral.name,
            address: collateral.address,
            decimals: collateral.decimals,
            oracleId: collateral.oracleId,
          })),
        },
        activities: {
          create: {
            type: 'DEPLOYMENT_CREATED',
            description: `Deployment created for chain ${chainId}`,
            metadata: {
              vaultStrategy,
              vaultToken,
              priceOracle,
            },
            txHash: transactionHash,
          },
        },
      },
      include: {
        network: true,
        collaterals: true,
        activities: true,
      },
    });

    return NextResponse.json(deployment, { status: 201 });
  } catch (error: any) {
    console.error('Error creating deployment:', error);
    
    // Handle unique constraint violation
    if (error.code === 'P2002') {
      return NextResponse.json(
        { error: 'Deployment already exists for this chain' },
        { status: 409 }
      );
    }
    
    return NextResponse.json(
      { error: 'Failed to create deployment' },
      { status: 500 }
    );
  }
}

// Routes are exported directly as GET and POST functions