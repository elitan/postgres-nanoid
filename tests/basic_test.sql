-- Basic functionality tests for postgres-nanoid
-- Run with: \i /tests/basic_test.sql

\echo '=== Basic Functionality Tests ==='
\echo ''

-- Test 1: Basic nanoid generation
\echo 'Test 1: Basic nanoid generation'
SELECT nanoid() as basic_nanoid;
\echo ''

-- Test 2: Nanoid with prefix
\echo 'Test 2: Nanoid with prefix'
SELECT nanoid('cus_') as prefixed_nanoid;
\echo ''

-- Test 3: Custom size
\echo 'Test 3: Custom size'
SELECT nanoid('test_', 25) as sized_nanoid;
\echo ''

-- Test 4: Uniqueness and time-ordering test
\echo 'Test 4: Uniqueness and time-ordering test (generating IDs with delays)'
CREATE TEMP TABLE sortability_test (
    seq INT,
    nanoid_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert with small delays to verify time ordering
INSERT INTO sortability_test (seq, nanoid_value) VALUES (1, nanoid('test_'));
SELECT pg_sleep(0.002);
INSERT INTO sortability_test (seq, nanoid_value) VALUES (2, nanoid('test_'));
SELECT pg_sleep(0.002);
INSERT INTO sortability_test (seq, nanoid_value) VALUES (3, nanoid('test_'));
SELECT pg_sleep(0.002);
INSERT INTO sortability_test (seq, nanoid_value) VALUES (4, nanoid('test_'));
SELECT pg_sleep(0.002);
INSERT INTO sortability_test (seq, nanoid_value) VALUES (5, nanoid('test_'));

-- Show that nanoids are time-ordered when sorted lexicographically
SELECT 
    seq,
    nanoid_value,
    created_at
FROM sortability_test 
ORDER BY nanoid_value;  -- Lexicographic order should match time order

-- Verify sortability  
WITH sorted_data AS (
    SELECT 
        seq,
        LAG(seq) OVER (ORDER BY nanoid_value) as prev_seq
    FROM sortability_test
),
sortability_check AS (
    SELECT 
        COUNT(*) as total_records,
        COUNT(CASE 
            WHEN prev_seq IS NULL OR prev_seq < seq 
            THEN 1 
        END) as correctly_sorted
    FROM sorted_data
)
SELECT 
    total_records,
    correctly_sorted,
    CASE 
        WHEN total_records = correctly_sorted 
        THEN 'PASS - Nanoids are time-ordered!' 
        ELSE 'FAIL - Time ordering broken' 
    END as time_ordering_test
FROM sortability_check;
\echo ''

-- Test 5: Insert into customers table
\echo 'Test 5: Insert into customers table'
INSERT INTO customers (name) VALUES ('Test Customer 1'), ('Test Customer 2');
SELECT public_id, name FROM customers ORDER BY public_id DESC LIMIT 2;
\echo ''

-- Test 6: Timestamp extraction
\echo 'Test 6: Timestamp extraction from nanoids'
WITH timestamp_test AS (
    SELECT 
        nanoid_value,
        created_at,
        nanoid_extract_timestamp(nanoid_value, 5) as extracted_timestamp  -- 5 = length of 'test_'
    FROM sortability_test
    LIMIT 1
)
SELECT 
    nanoid_value,
    created_at,
    extracted_timestamp,
    CASE 
        WHEN abs(extract(epoch from created_at) - extract(epoch from extracted_timestamp)) < 1 
        THEN 'PASS - Timestamp extraction accurate!' 
        ELSE 'FAIL - Timestamp mismatch' 
    END as timestamp_test
FROM timestamp_test;
\echo ''

-- Test 7: Error handling
\echo 'Test 7: Error handling (should show error)'
\echo 'Testing size too small with prefix and timestamp...'
DO $$
BEGIN
    PERFORM nanoid('very_long_prefix_', 5);
    RAISE NOTICE 'ERROR: Should have failed!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Correctly caught error: %', SQLERRM;
END
$$;
\echo ''

\echo '=== All basic tests completed ==='