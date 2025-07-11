-- Test sortable nanoid functionality
-- WARNING: nanoid_sortable() embeds timestamps which can leak business intelligence.
-- Use only when time-ordering is essential and privacy trade-offs are acceptable.
-- Run with: \i /tests/sortable_test.sql

\echo '=== Sortable Nanoid Tests ==='
\echo 'WARNING: These tests use nanoid_sortable() which embeds timing information.'
\echo ''

-- Test 1: Basic sortable nanoid generation
\echo 'Test 1: Basic sortable nanoid generation'
SELECT nanoid_sortable('cus_') as sortable_id;
\echo ''

-- Test 2: Multiple sortable IDs with delays to verify ordering
\echo 'Test 2: Sortability verification with timestamps'
CREATE TEMP TABLE sortable_test (
    id SERIAL,
    nanoid_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert with small delays to ensure different timestamps
INSERT INTO sortable_test (nanoid_value) VALUES (nanoid_sortable('test_'));
SELECT pg_sleep(0.001);
INSERT INTO sortable_test (nanoid_value) VALUES (nanoid_sortable('test_'));
SELECT pg_sleep(0.001); 
INSERT INTO sortable_test (nanoid_value) VALUES (nanoid_sortable('test_'));
SELECT pg_sleep(0.001);
INSERT INTO sortable_test (nanoid_value) VALUES (nanoid_sortable('test_'));
SELECT pg_sleep(0.001);
INSERT INTO sortable_test (nanoid_value) VALUES (nanoid_sortable('test_'));

-- Show results: nanoid should be lexicographically ordered by creation time
SELECT 
    id,
    nanoid_value,
    created_at,
    -- Check if nanoid is lexicographically ordered by creation time
    CASE 
        WHEN LAG(nanoid_value) OVER (ORDER BY created_at) IS NULL THEN true
        ELSE LAG(nanoid_value) OVER (ORDER BY created_at) < nanoid_value 
    END as is_sorted_correctly
FROM sortable_test 
ORDER BY created_at;

-- Summary of sortability test
WITH ordered_check AS (
    SELECT 
        nanoid_value,
        LAG(nanoid_value) OVER (ORDER BY created_at) < nanoid_value as is_ordered
    FROM sortable_test
),
sortability_check AS (
    SELECT 
        COUNT(*) as total_records,
        SUM(CASE WHEN is_ordered IS NULL OR is_ordered THEN 1 ELSE 0 END) as correctly_sorted
    FROM ordered_check
)
SELECT 
    total_records,
    correctly_sorted,
    CASE WHEN total_records = correctly_sorted THEN 'PASS' ELSE 'FAIL' END as sortability_test
FROM sortability_check;
\echo ''

-- Test 3: Timestamp extraction
\echo 'Test 3: Timestamp extraction from sortable nanoids'
WITH test_extraction AS (
    SELECT 
        nanoid_value,
        created_at,
        nanoid_extract_timestamp(nanoid_value, 5) as extracted_timestamp -- 5 = length of 'test_'
    FROM sortable_test
    LIMIT 1
)
SELECT 
    nanoid_value,
    created_at,
    extracted_timestamp,
    -- Check if extracted timestamp is close to created_at (within 1 second)
    CASE 
        WHEN abs(extract(epoch from created_at) - extract(epoch from extracted_timestamp)) < 1 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END as timestamp_extraction_test
FROM test_extraction;
\echo ''

-- Test 4: Performance comparison between regular and sortable nanoids
\echo 'Test 4: Performance comparison'
\timing on

-- Regular nanoid performance
WITH regular_batch AS (
    SELECT nanoid('perf_') FROM generate_series(1, 1000)
)
SELECT COUNT(*) as regular_nanoids_generated FROM regular_batch;

-- Sortable nanoid performance  
WITH sortable_batch AS (
    SELECT nanoid_sortable('perf_') FROM generate_series(1, 1000)
)
SELECT COUNT(*) as sortable_nanoids_generated FROM sortable_batch;

\timing off
\echo ''

-- Test 5: Large batch sortability test
\echo 'Test 5: Large batch sortability verification'
CREATE TEMP TABLE large_sortable_test AS
SELECT 
    nanoid_sortable('batch_') as sortable_id,
    NOW() + (random() * interval '1 hour') as simulated_time
FROM generate_series(1, 100);

-- Check if IDs are sortable (they should be since they all have very close timestamps)
WITH sorted_check AS (
    SELECT 
        sortable_id,
        LAG(sortable_id) OVER (ORDER BY sortable_id) as prev_id,
        simulated_time,
        LAG(simulated_time) OVER (ORDER BY sortable_id) as prev_time
    FROM large_sortable_test
)
SELECT 
    COUNT(*) as total_pairs,
    COUNT(CASE WHEN prev_id IS NULL OR prev_id < sortable_id THEN 1 END) as correctly_ordered_pairs,
    ROUND(
        COUNT(CASE WHEN prev_id IS NULL OR prev_id < sortable_id THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as ordering_percentage
FROM sorted_check;
\echo ''

-- Test 6: Different prefix lengths
\echo 'Test 6: Different prefix lengths'
SELECT 
    'Short prefix:' as test_case,
    nanoid_sortable('c_', 25) as id
UNION ALL
SELECT 
    'Long prefix:',
    nanoid_sortable('customer_account_', 35) as id
UNION ALL  
SELECT 
    'No prefix:',
    nanoid_sortable('', 21) as id;
\echo ''

\echo '=== Sortable Nanoid Tests Complete ==='
\echo 'Key features:'
\echo '- Lexicographically sortable by creation time'
\echo '- 8-character encoded timestamp prefix (millisecond precision)'
\echo '- Compatible with existing nanoid alphabet and size parameters'
\echo '- Timestamp extractable for debugging/analysis'
\echo ''
\echo 'SECURITY WARNING: Use regular nanoid() for better privacy.'
\echo 'Only use nanoid_sortable() when time-ordering is essential.'