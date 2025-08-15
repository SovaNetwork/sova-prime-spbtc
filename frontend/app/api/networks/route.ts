import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

// GET /api/networks - Get all networks
export async function GET(request: NextRequest) {
  try {
    const networks = await prisma.sovaBtcNetwork.findMany({
      include: {
        deployments: {
          include: {
            collaterals: true,
            metrics: {
              orderBy: { timestamp: 'desc' },
              take: 1,
            },
          },
        },
        metrics: {
          orderBy: { timestamp: 'desc' },
          take: 1,
        },
      },
      orderBy: { chainId: 'asc' },
    });

    return NextResponse.json(networks);
  } catch (error) {
    console.error('Error fetching networks:', error);
    return NextResponse.json(
      { error: 'Failed to fetch networks' },
      { status: 500 }
    );
  }
}

// POST /api/networks - Create or update network
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { chainId, name, rpcUrl, blockExplorer, nativeCurrency, isTestnet } = body;

    // Validate required fields
    if (!chainId || !name || !rpcUrl || !blockExplorer || !nativeCurrency) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Upsert network
    const network = await prisma.sovaBtcNetwork.upsert({
      where: { chainId },
      update: {
        name,
        rpcUrl,
        blockExplorer,
        nativeCurrency,
        isTestnet: isTestnet || false,
      },
      create: {
        chainId,
        name,
        rpcUrl,
        blockExplorer,
        nativeCurrency,
        isTestnet: isTestnet || false,
      },
    });

    return NextResponse.json(network);
  } catch (error) {
    console.error('Error creating/updating network:', error);
    return NextResponse.json(
      { error: 'Failed to create/update network' },
      { status: 500 }
    );
  }
}