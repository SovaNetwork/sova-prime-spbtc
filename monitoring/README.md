# BTC Vault Monitoring

This directory contains monitoring and metrics collection scripts for the BTC Vault system.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Scripts

### Health Check (`healthCheck.js`)

Performs comprehensive health checks on the BTC Vault system:
- Liquidity monitoring
- NAV deviation detection
- Share price tracking
- Collateral status verification
- Recent activity analysis
- Overall health score calculation

Run once:
```bash
npm run health
```

Run continuously (every 60 seconds):
```bash
npm run health:watch
```

### Metrics Collector (`metricsCollector.js`)

Continuously collects and stores metrics:
- TVL tracking
- Transaction volumes
- Event monitoring
- Rate calculations
- Historical statistics

Start collector:
```bash
npm run metrics
```

### Combined Monitoring

Run both health check and metrics collection:
```bash
npm run monitor
```

## Output Files

The monitoring scripts generate several output files:

- `health-metrics.json` - Latest health check results
- `metrics-data/latest-metrics.json` - Most recent metrics snapshot
- `metrics-data/metrics-history.json` - Historical metrics data
- `metrics-data/metrics.csv` - Metrics in CSV format for analysis

## Alert Configuration

### Slack Webhook

Set `ALERT_WEBHOOK_URL` in `.env` to receive alerts:

```bash
ALERT_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Alert Thresholds

Configure thresholds in the scripts:
- Minimum liquidity: 10 BTC
- Maximum price deviation: 5%
- Minimum health score: 80/100
- Maximum pending withdrawals: 100

## Monitoring Dashboard

### Grafana Setup

1. Import the provided dashboard configuration
2. Configure Prometheus data source
3. Set up alerting rules

### Tenderly Integration

1. Set Tenderly credentials in `.env`
2. Import contracts to Tenderly project
3. Configure alert rules in Tenderly dashboard

## Cron Setup

For production monitoring, set up cron jobs:

```bash
# Health check every 5 minutes
*/5 * * * * cd /path/to/monitoring && npm run health >> health.log 2>&1

# Metrics collection (continuous)
@reboot cd /path/to/monitoring && npm run metrics >> metrics.log 2>&1
```

## Troubleshooting

### Connection Issues

If you see "Failed to connect to provider":
1. Check RPC URL in `.env`
2. Verify network connectivity
3. Ensure RPC rate limits are not exceeded

### Missing Metrics

If metrics are not being collected:
1. Verify contract addresses in `.env`
2. Check that contracts are deployed on the network
3. Ensure sufficient RPC credits/quota

### Alert Not Sending

If alerts are not being sent:
1. Verify webhook URL is correct
2. Test webhook manually
3. Check network firewall settings

## Security

- Never commit `.env` file
- Use read-only RPC endpoints
- Rotate API keys regularly
- Monitor for unusual activity patterns

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs in `health.log` and `metrics.log`
3. Contact the development team