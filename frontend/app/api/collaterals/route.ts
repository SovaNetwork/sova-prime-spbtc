import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const chainId = searchParams.get('chainId');
    const deploymentId = searchParams.get('deploymentId');

    // Build query filters
    const where: any = {};
    if (chainId) {
      where.chainId = parseInt(chainId);
    }
    if (deploymentId) {
      where.deploymentId = deploymentId;
    }

    const collaterals = await prisma.sovaBtcCollateral.findMany({
      where,
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
      orderBy: [
        { isActive: 'desc' },
        { symbol: 'asc' },
      ],
    });

    return NextResponse.json(collaterals);
  } catch (error) {
    console.error('Failed to fetch collaterals:', error);
    return NextResponse.json(
      { error: 'Failed to fetch collaterals' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { deploymentId, symbol, name, address, chainId, decimals, oracleId, logoUri, coingeckoId } = body;

    // Validate required fields
    if (!deploymentId || !symbol || !name || !address || !chainId || decimals === undefined) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Check if deployment exists
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { id: deploymentId },
    });

    if (!deployment) {
      return NextResponse.json(
        { error: 'Deployment not found' },
        { status: 404 }
      );
    }

    // Create collateral
    const collateral = await prisma.sovaBtcCollateral.create({
      data: {
        deploymentId,
        symbol,
        name,
        address,
        chainId,
        decimals,
        oracleId,
        logoUri,
        coingeckoId,
        isActive: true,
        isVerified: false,
      },
    });

    // Update token registry
    let tokenRegistry = await prisma.sovaBtcTokenRegistry.findUnique({
      where: { symbol },
    });

    if (!tokenRegistry) {
      // Create new token registry entry
      await prisma.sovaBtcTokenRegistry.create({
        data: {
          symbol,
          name,
          decimals,
          addresses: { [chainId.toString()]: address },
          category: 'btc',
          logoUri,
          coingeckoId,
        },
      });
    } else {
      // Update addresses if needed
      const addresses = tokenRegistry.addresses as Record<string, string>;
      if (!addresses[chainId.toString()]) {
        addresses[chainId.toString()] = address;
        await prisma.sovaBtcTokenRegistry.update({
          where: { id: tokenRegistry.id },
          data: { addresses },
        });
      }
    }

    // Log activity
    await prisma.sovaBtcActivity.create({
      data: {
        deploymentId,
        type: 'COLLATERAL_ADDED',
        description: `Added ${symbol} collateral on chain ${chainId}`,
        metadata: { symbol, address, chainId },
      },
    });

    return NextResponse.json(collateral, { status: 201 });
  } catch (error: any) {
    console.error('Failed to create collateral:', error);
    
    // Handle unique constraint violations
    if (error.code === 'P2002') {
      return NextResponse.json(
        { error: 'Collateral already exists' },
        { status: 409 }
      );
    }

    return NextResponse.json(
      { error: 'Failed to create collateral' },
      { status: 500 }
    );
  }
}

// Routes are exported directly as GET and POST functions