import { gql } from '@apollo/client';

// Vault Metrics Queries
export const GET_VAULT_METRICS = gql`
  query GetVaultMetrics {
    vaultMetricss {
      items {
        id
        totalAssets
        totalShares
        sharePrice
        timestamp
        totalUsers
        activeUsers
        totalDeposits
        totalWithdrawals
        blockNumber
      }
    }
  }
`;

// Deposit Queries
export const GET_RECENT_DEPOSITS = gql`
  query GetRecentDeposits {
    btcDepositss {
      items {
        id
        sender
        owner
        assets
        shares
        blockNumber
        blockTimestamp
        transactionHash
      }
    }
  }
`;

// Withdrawal Queries
export const GET_RECENT_WITHDRAWALS = gql`
  query GetRecentWithdrawals {
    btcWithdrawalss {
      items {
        id
        sender
        receiver
        owner
        assets
        shares
        blockNumber
        blockTimestamp
        transactionHash
      }
    }
  }
`;

// User Position Queries
export const GET_USER_POSITION = gql`
  query GetUserPosition($user: String!) {
    userPositionss(where: { user: $user }) {
      items {
        id
        user
        shares
        lastBlockNumber
        lastBlockTimestamp
      }
    }
  }
`;

// Collateral Updates
export const GET_COLLATERAL_UPDATES = gql`
  query GetCollateralUpdates {
    collateralUpdatess {
      items {
        id
        token
        enabled
        blockNumber
        blockTimestamp
      }
    }
  }
`;

// Liquidity Events
export const GET_LIQUIDITY_EVENTS = gql`
  query GetLiquidityEvents {
    liquidityEventss {
      items {
        id
        eventType
        amount
        blockNumber
        blockTimestamp
        transactionHash
      }
    }
  }
`;

// NAV Updates
export const GET_NAV_UPDATES = gql`
  query GetNavUpdates {
    navUpdatess {
      items {
        id
        oldNav
        newNav
        blockNumber
        blockTimestamp
      }
    }
  }
`;

// Strategy Reports
export const GET_STRATEGY_REPORTS = gql`
  query GetStrategyReports {
    strategyReportss {
      items {
        id
        totalAssets
        totalShares
        sharePrice
        blockNumber
        blockTimestamp
      }
    }
  }
`;

// Combined Transaction History - using separate queries since Ponder doesn't support unions
export const GET_TRANSACTION_HISTORY = gql`
  query GetTransactionHistory {
    btcDepositss {
      items {
        id
        sender
        owner
        assets
        shares
        blockTimestamp
        transactionHash
      }
    }
    btcWithdrawalss {
      items {
        id
        sender
        receiver
        owner
        assets
        shares
        blockTimestamp
        transactionHash
      }
    }
  }
`;

// Aggregated Stats
export const GET_VAULT_STATS = gql`
  query GetVaultStats {
    vaultMetricss {
      items {
        id
        totalAssets
        totalShares
        sharePrice
        timestamp
        totalDeposits
        totalWithdrawals
        totalUsers
        activeUsers
      }
    }
  }
`;