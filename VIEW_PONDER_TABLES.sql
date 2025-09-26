-- View Ponder Tables in Neon
-- Run this SQL in your Neon SQL editor to see the Ponder tables

-- 1. List all schemas
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name LIKE 'ponder%'
ORDER BY schema_name;

-- 2. List all tables created by Ponder
SELECT 
    schemaname as schema,
    tablename as table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname LIKE 'ponder%'
ORDER BY schemaname, tablename;

-- 3. Count records in each Ponder table (replace schema name with actual from above)
-- Note: You'll need to update 'ponder-indexer_eee6dc32' with your actual schema name
SELECT 
    'deposits' as table_name, 
    COUNT(*) as record_count 
FROM "ponder-indexer_eee6dc32"."deposits"
UNION ALL
SELECT 
    'withdrawals', 
    COUNT(*) 
FROM "ponder-indexer_eee6dc32"."withdrawals"
UNION ALL
SELECT 
    'collateralUpdates', 
    COUNT(*) 
FROM "ponder-indexer_eee6dc32"."collateralUpdates"
UNION ALL
SELECT 
    'vaultMetrics', 
    COUNT(*) 
FROM "ponder-indexer_eee6dc32"."vaultMetrics";

-- 4. View recent deposits (example)
SELECT * 
FROM "ponder-indexer_eee6dc32"."deposits" 
ORDER BY "blockTimestamp" DESC 
LIMIT 10;

-- 5. View public views (these are what your app should query)
SELECT 
    schemaname as schema,
    viewname as view_name
FROM pg_views 
WHERE schemaname = 'public'
ORDER BY viewname;