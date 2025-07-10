-- Performance benchmark for postgres-nanoid
-- Tests generation speed for high-volume scenarios
-- Run with: \i /tests/benchmark.sql

-- Test 1: Single ID generation timing
\timing on

SELECT 'Test 1: Single nanoid generation' as test;
SELECT nanoid('cus_');

-- Test 2: Batch generation (1,000 IDs)
SELECT 'Test 2: Generate 1,000 IDs' as test;
SELECT nanoid('cus_') FROM generate_series(1, 1000);

-- Test 3: Batch generation (10,000 IDs)
SELECT 'Test 3: Generate 10,000 IDs' as test;
SELECT nanoid('cus_') FROM generate_series(1, 10000);

-- Test 4: Insert performance test with table
CREATE TEMP TABLE test_customers (
    id SERIAL PRIMARY KEY,
    public_id TEXT NOT NULL UNIQUE DEFAULT nanoid('cus_'),
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

SELECT 'Test 4: Insert 1,000 records with nanoid' as test;
INSERT INTO test_customers (name) 
SELECT 'Customer ' || i FROM generate_series(1, 1000) i;

-- Test 5: Different prefix lengths
SELECT 'Test 5: Different prefix performance' as test;
SELECT nanoid('') FROM generate_series(1, 1000); -- No prefix
SELECT nanoid('customer_') FROM generate_series(1, 1000); -- Longer prefix

-- Test 6: Different ID sizes
SELECT 'Test 6: Different size performance' as test;
SELECT nanoid('cus_', 10) FROM generate_series(1, 1000); -- Shorter
SELECT nanoid('cus_', 50) FROM generate_series(1, 1000); -- Longer

-- Test 7: Uniqueness check on large dataset
SELECT 'Test 7: Uniqueness validation' as test;
WITH ids AS (
    SELECT nanoid('cus_') as id FROM generate_series(1, 10000)
)
SELECT 
    COUNT(*) as total_generated,
    COUNT(DISTINCT id) as unique_count,
    (COUNT(*) - COUNT(DISTINCT id)) as duplicates
FROM ids;

\timing off