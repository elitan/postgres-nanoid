-- Comprehensive tests for both nanoid() and nanoid_sortable() functions
-- This test suite verifies the security-first dual function approach
-- Run with: \i /tests/dual_function_test.sql

\echo '=== Dual Function Comprehensive Tests ==='
\echo 'Testing both nanoid() (secure random) and nanoid_sortable() (time-ordered)'
\echo ''

-- Test 1: Basic function availability and signatures
\echo 'Test 1: Function availability and basic generation'
SELECT 
    'Regular nanoid:' as function_type,
    nanoid() as generated_id,
    length(nanoid()) as id_length;

SELECT 
    'Sortable nanoid:' as function_type,
    nanoid_sortable() as generated_id,
    length(nanoid_sortable()) as id_length;

SELECT 
    'Regular with prefix:' as function_type,
    nanoid('test_') as generated_id,
    length(nanoid('test_')) as id_length;

SELECT 
    'Sortable with prefix:' as function_type,
    nanoid_sortable('test_') as generated_id,
    length(nanoid_sortable('test_')) as id_length;
\echo ''

-- Test 2: Randomness vs Sortability Verification
\echo 'Test 2: Randomness vs Sortability Verification'
CREATE TEMP TABLE comparison_test (
    seq INT,
    random_nanoid TEXT,
    sortable_nanoid TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Generate pairs with time delays
INSERT INTO comparison_test (seq, random_nanoid, sortable_nanoid) VALUES (1, nanoid('rnd_'), nanoid_sortable('srt_'));
SELECT pg_sleep(0.002);
INSERT INTO comparison_test (seq, random_nanoid, sortable_nanoid) VALUES (2, nanoid('rnd_'), nanoid_sortable('srt_'));
SELECT pg_sleep(0.002);
INSERT INTO comparison_test (seq, random_nanoid, sortable_nanoid) VALUES (3, nanoid('rnd_'), nanoid_sortable('srt_'));
SELECT pg_sleep(0.002);
INSERT INTO comparison_test (seq, random_nanoid, sortable_nanoid) VALUES (4, nanoid('rnd_'), nanoid_sortable('srt_'));
SELECT pg_sleep(0.002);
INSERT INTO comparison_test (seq, random_nanoid, sortable_nanoid) VALUES (5, nanoid('rnd_'), nanoid_sortable('srt_'));

-- Show the results
SELECT 
    seq,
    random_nanoid,
    sortable_nanoid,
    created_at
FROM comparison_test 
ORDER BY seq;

-- Verify sortable nanoids are time-ordered
WITH sortable_ordered AS (
    SELECT 
        sortable_nanoid,
        LAG(sortable_nanoid) OVER (ORDER BY created_at) < sortable_nanoid as is_ordered
    FROM comparison_test
),
sortable_check AS (
    SELECT 
        COUNT(*) as total_records,
        SUM(CASE WHEN is_ordered IS NULL OR is_ordered THEN 1 ELSE 0 END) as correctly_sorted
    FROM sortable_ordered
)
SELECT 
    'Sortable nanoids:' as test_type,
    total_records,
    correctly_sorted,
    CASE WHEN total_records = correctly_sorted THEN 'PASS - Time ordered' ELSE 'FAIL - Not time ordered' END as result
FROM sortable_check;

-- Verify random nanoids are NOT consistently time-ordered
WITH random_ordered AS (
    SELECT 
        random_nanoid,
        LAG(random_nanoid) OVER (ORDER BY created_at) < random_nanoid as is_ordered
    FROM comparison_test
),
random_check AS (
    SELECT 
        COUNT(*) as total_records,
        SUM(CASE WHEN is_ordered IS NULL OR is_ordered THEN 1 ELSE 0 END) as correctly_sorted
    FROM random_ordered
)
SELECT 
    'Random nanoids:' as test_type,
    total_records,
    correctly_sorted,
    CASE WHEN correctly_sorted < total_records THEN 'PASS - Random order' ELSE 'INCONCLUSIVE - May be coincidentally ordered' END as result
FROM random_check;
\echo ''

-- Test 3: Timestamp Extraction (sortable only)
\echo 'Test 3: Timestamp extraction capabilities'
WITH extraction_test AS (
    SELECT 
        sortable_nanoid,
        created_at,
        nanoid_extract_timestamp(sortable_nanoid, 4) as extracted_timestamp  -- 4 = length of 'srt_'
    FROM comparison_test
    LIMIT 1
)
SELECT 
    sortable_nanoid,
    created_at,
    extracted_timestamp,
    CASE 
        WHEN abs(extract(epoch from created_at) - extract(epoch from extracted_timestamp)) < 1 
        THEN 'PASS - Timestamp extraction works' 
        ELSE 'FAIL - Timestamp mismatch' 
    END as extraction_test
FROM extraction_test;

-- Test that regular nanoids cannot have timestamps extracted meaningfully
\echo 'Note: Regular nanoids do not contain extractable timestamps.'
\echo ''

-- Test 4: Performance Comparison
\echo 'Test 4: Performance comparison'
\timing on

-- Regular nanoid performance
WITH regular_batch AS (
    SELECT nanoid('perf_') FROM generate_series(1, 1000)
)
SELECT 'Regular nanoids:' as type, COUNT(*) as ids_generated FROM regular_batch;

-- Sortable nanoid performance  
WITH sortable_batch AS (
    SELECT nanoid_sortable('perf_') FROM generate_series(1, 1000)
)
SELECT 'Sortable nanoids:' as type, COUNT(*) as ids_generated FROM sortable_batch;

\timing off
\echo ''

-- Test 5: Security Analysis - Business Intelligence Leakage
\echo 'Test 5: Security analysis - business intelligence leakage demonstration'
CREATE TEMP TABLE business_simulation (
    day_num INT,
    random_customer_id TEXT,
    sortable_order_id TEXT,
    created_at TIMESTAMP
);

-- Simulate customer and order creation over several "days"
INSERT INTO business_simulation VALUES 
(1, nanoid('cus_'), nanoid_sortable('ord_'), '2025-01-01 09:00:00'),
(1, nanoid('cus_'), nanoid_sortable('ord_'), '2025-01-01 14:00:00'),
(2, nanoid('cus_'), nanoid_sortable('ord_'), '2025-01-02 10:00:00'),
(2, nanoid('cus_'), nanoid_sortable('ord_'), '2025-01-02 11:00:00'),
(2, nanoid('cus_'), nanoid_sortable('ord_'), '2025-01-02 16:00:00'),
(3, nanoid('cus_'), nanoid_sortable('ord_'), '2025-01-03 08:00:00');

SELECT 
    day_num,
    random_customer_id,
    sortable_order_id,
    created_at
FROM business_simulation 
ORDER BY day_num;

\echo 'Analysis: Random customer IDs provide no timing info.'
\echo 'Sortable order IDs reveal business patterns (peak times, growth trends).'
\echo ''

-- Test 6: Error Handling for Both Functions
\echo 'Test 6: Error handling for both functions'

-- Test regular nanoid error handling
DO $$
BEGIN
    PERFORM nanoid('very_long_prefix_', 5);  -- Should fail: size too small
    RAISE NOTICE 'ERROR: Regular nanoid should have failed!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Regular nanoid error handling: %', SQLERRM;
END
$$;

-- Test sortable nanoid error handling
DO $$
BEGIN
    PERFORM nanoid_sortable('very_long_prefix_', 10);  -- Should fail: no room for timestamp + random
    RAISE NOTICE 'ERROR: Sortable nanoid should have failed!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Sortable nanoid error handling: %', SQLERRM;
END
$$;
\echo ''

-- Test 7: Large Scale Uniqueness
\echo 'Test 7: Large scale uniqueness verification'
CREATE TEMP TABLE uniqueness_test AS
SELECT 
    nanoid('uniq_') as random_id,
    nanoid_sortable('uniq_') as sortable_id
FROM generate_series(1, 10000);

WITH uniqueness_stats AS (
    SELECT 
        COUNT(*) as total_records,
        COUNT(DISTINCT random_id) as unique_random,
        COUNT(DISTINCT sortable_id) as unique_sortable
    FROM uniqueness_test
)
SELECT 
    total_records,
    unique_random,
    unique_sortable,
    CASE 
        WHEN total_records = unique_random AND total_records = unique_sortable 
        THEN 'PASS - All IDs unique'
        ELSE 'FAIL - Duplicates found'
    END as uniqueness_result
FROM uniqueness_stats;
\echo ''

-- Test 8: Prefix and Size Variations
\echo 'Test 8: Prefix and size variations'
SELECT 
    'No prefix, default size:' as test_case,
    nanoid() as random_id,
    nanoid_sortable() as sortable_id
UNION ALL
SELECT 
    'Short prefix, default size:',
    nanoid('a_'),
    nanoid_sortable('a_')
UNION ALL
SELECT 
    'Long prefix, large size:',
    nanoid('customer_account_', 35),
    nanoid_sortable('customer_account_', 35)
UNION ALL
SELECT 
    'Custom alphabet test:',
    nanoid('hex_', 16, '0123456789abcdef'),
    nanoid_sortable('hex_', 24, '0123456789abcdef');
\echo ''

\echo '=== Dual Function Tests Complete ==='
\echo ''
\echo 'Summary:'
\echo '- nanoid(): Secure, random, fast, no timing information'
\echo '- nanoid_sortable(): Time-ordered, reveals timing, use carefully'
\echo ''
\echo 'Recommendation: Use nanoid() by default for security.'
\echo 'Only use nanoid_sortable() when temporal ordering is essential.'