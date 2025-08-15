import { NextResponse } from 'next/server';

export async function GET() {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV,
    network: process.env.NEXT_PUBLIC_NETWORK,
    version: process.env.npm_package_version || '1.0.0',
    contracts: {
      vault: process.env.NEXT_PUBLIC_VAULT_ADDRESS,
      queue: process.env.NEXT_PUBLIC_QUEUE_ADDRESS,
      registry: process.env.NEXT_PUBLIC_REGISTRY_ADDRESS,
    },
    services: {
      indexer: process.env.NEXT_PUBLIC_INDEXER_URL ? 'configured' : 'not configured',
      alchemy: process.env.NEXT_PUBLIC_ALCHEMY_KEY ? 'configured' : 'not configured',
      walletconnect: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID ? 'configured' : 'not configured',
    }
  };

  return NextResponse.json(health, { status: 200 });
}