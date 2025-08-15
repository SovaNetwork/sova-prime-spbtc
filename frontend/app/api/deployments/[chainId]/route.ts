import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

// GET /api/deployments/[chainId] - Get specific deployment
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ chainId: string }> }
) {
  try {
    const { chainId: chainIdStr } = await params;
    const chainId = parseInt(chainIdStr);
    
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { chainId },
      include: {
        network: true,
        collaterals: true,
        metrics: {
          orderBy: { timestamp: 'desc' },
          take: 10, // Get last 10 metrics for chart
        },
        activities: {
          orderBy: { createdAt: 'desc' },
          take: 20, // Get last 20 activities
        },
      },
    });

    if (!deployment) {
      return NextResponse.json(
        { error: 'Deployment not found' },
        { status: 404 }
      );
    }

    return NextResponse.json(deployment);
  } catch (error) {
    console.error('Error fetching deployment:', error);
    return NextResponse.json(
      { error: 'Failed to fetch deployment' },
      { status: 500 }
    );
  }
}

// PUT /api/deployments/[chainId] - Update deployment
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ chainId: string }> }
) {
  try {
    const { chainId: chainIdStr } = await params;
    const chainId = parseInt(chainIdStr);
    const body = await request.json();
    
    // Extract update data
    const {
      vaultStrategy,
      vaultToken,
      priceOracle,
      status,
      deployer,
      blockNumber,
      transactionHash,
      verified,
      collaterals,
    } = body;

    // Update deployment
    const deployment = await prisma.sovaBtcDeployment.update({
      where: { chainId },
      data: {
        ...(vaultStrategy && { vaultStrategy }),
        ...(vaultToken && { vaultToken }),
        ...(priceOracle !== undefined && { priceOracle }),
        ...(status && { status }),
        ...(deployer && { deployer }),
        ...(blockNumber !== undefined && { blockNumber }),
        ...(transactionHash && { transactionHash }),
        ...(verified !== undefined && { verified }),
      },
      include: {
        network: true,
        collaterals: true,
      },
    });

    // Handle collateral updates if provided
    if (collaterals && Array.isArray(collaterals)) {
      // Delete existing collaterals
      await prisma.sovaBtcCollateral.deleteMany({
        where: { deploymentId: deployment.id },
      });

      // Create new collaterals
      await prisma.sovaBtcCollateral.createMany({
        data: collaterals.map((collateral: any) => ({
          deploymentId: deployment.id,
          chainId: deployment.chainId,
          symbol: collateral.symbol,
          name: collateral.name,
          address: collateral.address,
          decimals: collateral.decimals,
          oracleId: collateral.oracleId,
        })),
      });
    }

    // Log activity
    await prisma.sovaBtcActivity.create({
      data: {
        deploymentId: deployment.id,
        type: 'DEPLOYMENT_UPDATED',
        description: `Deployment updated for chain ${chainId}`,
        metadata: body,
        txHash: transactionHash,
      },
    });

    // Fetch updated deployment with relations
    const updatedDeployment = await prisma.sovaBtcDeployment.findUnique({
      where: { chainId },
      include: {
        network: true,
        collaterals: true,
        activities: {
          orderBy: { createdAt: 'desc' },
          take: 5,
        },
      },
    });

    return NextResponse.json(updatedDeployment);
  } catch (error) {
    console.error('Error updating deployment:', error);
    return NextResponse.json(
      { error: 'Failed to update deployment' },
      { status: 500 }
    );
  }
}

// DELETE /api/deployments/[chainId] - Remove deployment
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ chainId: string }> }
) {
  try {
    const { chainId: chainIdStr } = await params;
    const chainId = parseInt(chainIdStr);
    
    // Check if deployment exists
    const deployment = await prisma.sovaBtcDeployment.findUnique({
      where: { chainId },
    });

    if (!deployment) {
      return NextResponse.json(
        { error: 'Deployment not found' },
        { status: 404 }
      );
    }

    // Delete deployment (cascades to related records)
    await prisma.sovaBtcDeployment.delete({
      where: { chainId },
    });

    return NextResponse.json(
      { message: 'Deployment deleted successfully' },
      { status: 200 }
    );
  } catch (error) {
    console.error('Error deleting deployment:', error);
    return NextResponse.json(
      { error: 'Failed to delete deployment' },
      { status: 500 }
    );
  }
}