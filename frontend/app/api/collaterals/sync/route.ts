import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';
import { BlockchainService } from '@/lib/services/blockchainService';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { deploymentId, chainId } = body;

    // Validate required fields
    if (!deploymentId || !chainId) {
      return NextResponse.json(
        { error: 'Missing required fields: deploymentId and chainId' },
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

    // Initialize blockchain service
    const blockchainService = new BlockchainService(prisma);

    try {
      // Sync collaterals from blockchain
      const collaterals = await blockchainService.syncCollateralsToDatabase(chainId, deploymentId);

      // Disconnect blockchain service
      await blockchainService.disconnect();

      return NextResponse.json({
        success: true,
        message: `Synced ${collaterals.length} collaterals from chain ${chainId}`,
        collaterals,
      });
    } catch (syncError: any) {
      await blockchainService.disconnect();
      
      console.error('Sync error:', syncError);
      return NextResponse.json(
        { 
          error: 'Failed to sync collaterals from blockchain',
          details: syncError.message,
        },
        { status: 500 }
      );
    }
  } catch (error) {
    console.error('Failed to sync collaterals:', error);
    return NextResponse.json(
      { error: 'Failed to process sync request' },
      { status: 500 }
    );
  }
}