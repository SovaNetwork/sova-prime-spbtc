# MultiBTC Vault Ponder Indexer

A high-performance blockchain indexer for the Multi-Collateral BTC Vault system using Ponder and Neon Database.

## Overview

This indexer replaces The Graph with Ponder, offering:
- ~10x faster indexing than Graph Node
- Direct PostgreSQL access with Neon's serverless infrastructure
- TypeScript-native with full type safety
- Hot-reloading during development
- Multiple query interfaces (GraphQL, SQL, direct Postgres)

## Features

### Indexed Data
- User deposits and redemptions
- Redemption queue status
- Vault metrics and snapshots
- Admin operations
- Daily aggregated metrics
- Price updates

### Database Tables
- `users` - User activity tracking
- `deposits` - All deposit transactions
- `redemption_requests` - Queue redemption requests
- `processed_redemptions` - Processed redemptions
- `claimed_redemptions` - Claimed redemptions
- `vault_snapshots` - Periodic vault state snapshots
- `admin_operations` - Admin actions (pause/unpause)
- `daily_metrics` - Daily aggregated statistics

## Setup

### Prerequisites
- Node.js 18+
- PostgreSQL database (we use Neon)

### Installation
```bash
cd examples/ponder-indexer
npm install
```

### Configuration
Update `.env.local`:
```env
# Base Sepolia RPC
PONDER_RPC_URL_1=https://base-sepolia.g.alchemy.com/v2/YOUR_KEY

# Neon Database
DATABASE_URL=postgresql://user:pass@host/database?sslmode=require
```

## Running the Indexer

### Development Mode
```bash
npm run dev
```
- Hot-reloading enabled
- API available at http://localhost:42069
- GraphQL playground at http://localhost:42069/graphql

### Production Mode
```bash
npm run start
```

## Query Interfaces

### GraphQL API
Access at `http://localhost:42069/graphql`

Example queries:

```graphql
# Get user deposits
query GetUserDeposits($user: String!) {
  deposits(where: { user: $user }) {
    id
    amount
    shares
    timestamp
    txHash
  }
}

# Get pending redemptions
query GetPendingRedemptions {
  redemptionRequests(where: { processed: false }) {
    requestId
    user
    shares
    claimableAfter
  }
}

# Get vault metrics
query GetVaultMetrics {
  vaultSnapshots(orderBy: blockNumber, orderDirection: desc, limit: 1) {
    totalAssets
    totalSupply
    sharePrice
    timestamp
  }
}
```

### SQL Interface
Direct SQL queries at `http://localhost:42069/sql`

```sql
-- Total deposits by user
SELECT 
  user,
  SUM(amount) as total_deposited,
  COUNT(*) as deposit_count
FROM deposits
GROUP BY user
ORDER BY total_deposited DESC;

-- Daily metrics
SELECT * FROM daily_metrics
ORDER BY date DESC
LIMIT 30;
```

### Direct Database Access
Connect directly to Neon PostgreSQL:
```javascript
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const result = await pool.query('SELECT * FROM vault_snapshots ORDER BY block_number DESC LIMIT 1');
```

## Contract Addresses (Base Sepolia)

- **MultiBTCVault**: `0x73E27097221d4d9D5893a83350dC7A967b46fab7`
- **RedemptionQueue**: `0x22BC73098CE1Ba2CaE5431fb32051cB4fc0F9C52`

## Performance

- **Indexing Speed**: ~10x faster than The Graph
- **Query Response**: <50ms for most queries
- **Database**: Serverless PostgreSQL with auto-scaling
- **Real-time Updates**: Events processed within 1-2 blocks

## Monitoring

### Health Check
```bash
curl http://localhost:42069/health
```

### Metrics Dashboard
Access real-time metrics:
```bash
curl http://localhost:42069/sql -X POST -H "Content-Type: application/json" \
  -d '{"query": "SELECT * FROM vault_snapshots ORDER BY block_number DESC LIMIT 1"}'
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check DATABASE_URL in .env.local
   - Ensure SSL is enabled (`?sslmode=require`)

2. **RPC Rate Limiting**
   - Use a premium RPC endpoint
   - Adjust block fetch batch size

3. **Memory Issues**
   - Increase Node.js memory: `NODE_OPTIONS="--max-old-space-size=4096" npm run dev`

## Development

### Adding New Events
1. Update schema in `ponder.schema.ts`
2. Add event handlers in `src/index.ts`
3. Run migrations: `npm run migrate`

### Testing
```bash
npm test
```

## Deployment

### Deploy to Production
1. Set up production database (Neon recommended)
2. Configure environment variables
3. Deploy using PM2 or Docker:

```bash
# PM2
pm2 start npm --name "ponder-indexer" -- start

# Docker
docker build -t vault-indexer .
docker run -d --env-file .env.production vault-indexer
```

## Resources

- [Ponder Documentation](https://ponder.sh)
- [Neon Database](https://neon.tech)
- [Base Sepolia Explorer](https://sepolia.basescan.org)

## License

MIT