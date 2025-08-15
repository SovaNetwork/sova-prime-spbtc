import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const category = searchParams.get('category');
    const symbol = searchParams.get('symbol');

    // Build query filters
    const where: any = {};
    if (category) {
      where.category = category;
    }
    if (symbol) {
      where.symbol = symbol;
    }

    const tokens = await prisma.sovaBtcTokenRegistry.findMany({
      where,
      orderBy: [
        { symbol: 'asc' },
      ],
    });

    return NextResponse.json(tokens);
  } catch (error) {
    console.error('Failed to fetch token registry:', error);
    return NextResponse.json(
      { error: 'Failed to fetch token registry' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { symbol, name, decimals, addresses, category, logoUri, coingeckoId } = body;

    // Validate required fields
    if (!symbol || !name || decimals === undefined || !addresses) {
      return NextResponse.json(
        { error: 'Missing required fields: symbol, name, decimals, addresses' },
        { status: 400 }
      );
    }

    // Create or update token registry entry
    const token = await prisma.sovaBtcTokenRegistry.upsert({
      where: { symbol },
      update: {
        name,
        decimals,
        addresses,
        category,
        logoUri,
        coingeckoId,
      },
      create: {
        symbol,
        name,
        decimals,
        addresses,
        category: category || 'btc',
        logoUri,
        coingeckoId,
      },
    });

    return NextResponse.json(token, { status: 201 });
  } catch (error: any) {
    console.error('Failed to create token registry entry:', error);
    
    // Handle unique constraint violations
    if (error.code === 'P2002') {
      return NextResponse.json(
        { error: 'Token already exists in registry' },
        { status: 409 }
      );
    }

    return NextResponse.json(
      { error: 'Failed to create token registry entry' },
      { status: 500 }
    );
  }
}