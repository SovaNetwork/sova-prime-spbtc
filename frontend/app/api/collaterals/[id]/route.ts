import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const collateral = await prisma.sovaBtcCollateral.findUnique({
      where: { id },
      include: {
        deployment: {
          include: {
            network: true,
          },
        },
      },
    });

    if (!collateral) {
      return NextResponse.json(
        { error: 'Collateral not found' },
        { status: 404 }
      );
    }

    return NextResponse.json(collateral);
  } catch (error) {
    console.error('Failed to fetch collateral:', error);
    return NextResponse.json(
      { error: 'Failed to fetch collateral' },
      { status: 500 }
    );
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const body = await request.json();
    const { isActive, isVerified, logoUri, coingeckoId, oracleId } = body;

    const collateral = await prisma.sovaBtcCollateral.update({
      where: { id },
      data: {
        ...(isActive !== undefined && { isActive }),
        ...(isVerified !== undefined && { isVerified }),
        ...(logoUri !== undefined && { logoUri }),
        ...(coingeckoId !== undefined && { coingeckoId }),
        ...(oracleId !== undefined && { oracleId }),
      },
    });

    // Update token registry if logo or coingecko ID changed
    if (logoUri !== undefined || coingeckoId !== undefined) {
      const tokenRegistry = await prisma.sovaBtcTokenRegistry.findUnique({
        where: { symbol: collateral.symbol },
      });

      if (tokenRegistry) {
        await prisma.sovaBtcTokenRegistry.update({
          where: { id: tokenRegistry.id },
          data: {
            ...(logoUri !== undefined && { logoUri }),
            ...(coingeckoId !== undefined && { coingeckoId }),
          },
        });
      }
    }

    // Log activity
    await prisma.sovaBtcActivity.create({
      data: {
        deploymentId: collateral.deploymentId,
        type: 'COLLATERAL_REMOVED', // Using this for updates as well
        description: `Updated ${collateral.symbol} collateral settings`,
        metadata: body,
      },
    });

    return NextResponse.json(collateral);
  } catch (error) {
    console.error('Failed to update collateral:', error);
    return NextResponse.json(
      { error: 'Failed to update collateral' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const collateral = await prisma.sovaBtcCollateral.findUnique({
      where: { id },
    });

    if (!collateral) {
      return NextResponse.json(
        { error: 'Collateral not found' },
        { status: 404 }
      );
    }

    // Soft delete by setting isActive to false
    await prisma.sovaBtcCollateral.update({
      where: { id },
      data: { isActive: false },
    });

    // Log activity
    await prisma.sovaBtcActivity.create({
      data: {
        deploymentId: collateral.deploymentId,
        type: 'COLLATERAL_REMOVED',
        description: `Deactivated ${collateral.symbol} collateral`,
        metadata: { symbol: collateral.symbol, address: collateral.address },
      },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Failed to delete collateral:', error);
    return NextResponse.json(
      { error: 'Failed to delete collateral' },
      { status: 500 }
    );
  }
}

// Routes are now exported directly as GET, PUT, DELETE functions