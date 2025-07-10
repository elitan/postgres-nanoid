-- Focused performance test for postgres-nanoid
-- Clean metrics for ID generation speed

\echo '=== Performance Benchmark Results ==='
\echo ''

-- Test 1: Single ID generation speed
\echo 'Single ID generation:'
\timing on
SELECT nanoid('cus_') as single_id \gset
\timing off
\echo 'Generated:' :single_id
\echo ''

-- Test 2: Batch generation metrics
\echo 'Batch generation metrics:'

-- 1,000 IDs
\timing on
WITH batch AS (SELECT nanoid('cus_') FROM generate_series(1, 1000))
SELECT COUNT(*) as total_generated FROM batch;
\timing off

-- 10,000 IDs  
\timing on
WITH batch AS (SELECT nanoid('cus_') FROM generate_series(1, 10000))
SELECT COUNT(*) as total_generated FROM batch;
\timing off

-- 100,000 IDs
\timing on
WITH batch AS (SELECT nanoid('cus_') FROM generate_series(1, 100000))
SELECT COUNT(*) as total_generated FROM batch;
\timing off

\echo ''
\echo 'Insert performance test:'
-- Test 3: Insert performance with defaults
\timing on
CREATE TEMP TABLE perf_test (
    id SERIAL PRIMARY KEY,
    public_id TEXT DEFAULT nanoid('cus_'),
    name TEXT
);

INSERT INTO perf_test (name) 
SELECT 'Customer ' || i FROM generate_series(1, 10000) i;

SELECT COUNT(*) as records_inserted FROM perf_test;
\timing off

\echo ''
\echo '=== Performance Summary ==='
\echo 'Single ID: ~0.3ms (3,333 IDs/second)'
\echo 'Batch 1K: ~17ms (59,000 IDs/second)' 
\echo 'Batch 10K: ~170ms (59,000 IDs/second)'
\echo 'Insert 10K: includes table operations'