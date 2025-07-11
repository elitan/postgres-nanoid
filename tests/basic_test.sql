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

-- Test 4: Uniqueness test for random nanoids
\echo 'Test 4: Uniqueness test (random nanoids should be unique)'
CREATE TEMP TABLE uniqueness_test (
    seq INT,
    nanoid_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert random nanoids (no time ordering expected)
INSERT INTO uniqueness_test (seq, nanoid_value) VALUES (1, nanoid('test_'));
INSERT INTO uniqueness_test (seq, nanoid_value) VALUES (2, nanoid('test_'));
INSERT INTO uniqueness_test (seq, nanoid_value) VALUES (3, nanoid('test_'));
INSERT INTO uniqueness_test (seq, nanoid_value) VALUES (4, nanoid('test_'));
INSERT INTO uniqueness_test (seq, nanoid_value) VALUES (5, nanoid('test_'));

-- Show generated nanoids (order should be random)
SELECT 
    seq,
    nanoid_value,
    created_at
FROM uniqueness_test 
ORDER BY seq;  -- Order by sequence, not nanoid

-- Verify uniqueness (all should be unique)
WITH uniqueness_check AS (
    SELECT 
        COUNT(*) as total_records,
        COUNT(DISTINCT nanoid_value) as unique_records
    FROM uniqueness_test
)
SELECT 
    total_records,
    unique_records,
    CASE 
        WHEN total_records = unique_records 
        THEN 'PASS - All nanoids are unique!' 
        ELSE 'FAIL - Duplicate nanoids found' 
    END as uniqueness_test
FROM uniqueness_check;
\echo ''

-- Test 5: Insert into customers table
\echo 'Test 5: Insert into customers table'
INSERT INTO customers (name) VALUES ('Test Customer 1'), ('Test Customer 2');
SELECT public_id, name FROM customers ORDER BY public_id DESC LIMIT 2;
\echo ''

-- Test 6: Timestamp extraction (only works with sortable nanoids)
\echo 'Test 6: Timestamp extraction (demo with sortable nanoid)'
WITH timestamp_test AS (
    SELECT 
        nanoid_sortable('demo_') as sortable_nanoid,
        NOW() as current_time
)
SELECT 
    sortable_nanoid,
    current_time,
    nanoid_extract_timestamp(sortable_nanoid, 5) as extracted_timestamp,  -- 5 = length of 'demo_'
    CASE 
        WHEN abs(extract(epoch from current_time) - extract(epoch from nanoid_extract_timestamp(sortable_nanoid, 5))) < 1 
        THEN 'PASS - Timestamp extraction accurate!' 
        ELSE 'FAIL - Timestamp mismatch' 
    END as timestamp_test
FROM timestamp_test;

\echo 'Note: Regular nanoid() IDs do not contain timestamps and cannot be extracted.'
\echo ''

-- Test 7: Error handling
\echo 'Test 7: Error handling (should show error)'
\echo 'Testing size too small with prefix...'
DO $$
BEGIN
    PERFORM nanoid('very_long_prefix_', 5);  -- Size 5 with long prefix should fail
    RAISE NOTICE 'ERROR: Should have failed!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Correctly caught error: %', SQLERRM;
END
$$;
\echo ''

\echo '=== All basic tests completed ==='