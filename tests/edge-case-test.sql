-- Edge case tests for nanoid functions
-- Run with: \i /tests/edge-case-test.sql

\echo '=== Edge Case Tests ==='
\echo ''

-- Test 1: Single-char alphabet (should fail)
\echo 'Test 1: Single-char alphabet (should fail)'
DO $$
BEGIN
    PERFORM nanoid('test_', 10, 'a');
    RAISE NOTICE 'FAIL: Should have errored on single-char alphabet';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: %', SQLERRM;
END
$$;
\echo ''

-- Test 2: Two-char alphabet (minimum valid)
\echo 'Test 2: Two-char alphabet (minimum valid)'
SELECT nanoid('bin_', 20, '01') as binary_nanoid;
\echo ''

-- Test 3: NULL parameters
\echo 'Test 3: NULL size (should fail)'
DO $$
BEGIN
    PERFORM nanoid('test_', NULL);
    RAISE NOTICE 'FAIL: Should have errored on NULL size';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: %', SQLERRM;
END
$$;
\echo ''

\echo 'Test 4: NULL alphabet (should fail)'
DO $$
BEGIN
    PERFORM nanoid('test_', 10, NULL);
    RAISE NOTICE 'FAIL: Should have errored on NULL alphabet';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: %', SQLERRM;
END
$$;
\echo ''

-- Test 5: Alphabet with duplicates (should work, just less entropy)
\echo 'Test 5: Alphabet with duplicates'
SELECT nanoid('dup_', 15, 'aaabbbccc') as duplicate_alphabet_nanoid;
\echo ''

-- Test 6: Large prefix close to size limit
\echo 'Test 6: Large prefix (19 chars with size 21)'
SELECT nanoid('verylongprefixhere_', 21) as long_prefix_nanoid;
\echo ''

-- Test 7: Prefix equals size minus 1 (minimum random = 1)
\echo 'Test 7: Prefix length = size - 1 (1 random char)'
SELECT nanoid('exactly_19_chars___', 20) as minimal_random_nanoid;
\echo ''

-- Test 8: Prefix equals size (should fail - no room for random)
\echo 'Test 8: Prefix equals size (should fail)'
DO $$
BEGIN
    PERFORM nanoid('exactly_20_chars____', 20);
    RAISE NOTICE 'FAIL: Should have errored when prefix = size';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: %', SQLERRM;
END
$$;
\echo ''

-- Test 9: Size = 1 with no prefix (minimum valid)
\echo 'Test 9: Size = 1 with no prefix'
SELECT nanoid('', 1) as single_char_nanoid;
\echo ''

-- Test 10: Sortable with minimum size for timestamp + random
\echo 'Test 10: Sortable minimum size (prefix + 8 timestamp + 1 random = 10)'
SELECT nanoid_sortable('', 9) as minimal_sortable;
\echo ''

-- Test 11: Sortable size too small (should fail)
\echo 'Test 11: Sortable size too small (should fail)'
DO $$
BEGIN
    PERFORM nanoid_sortable('', 8);
    RAISE NOTICE 'FAIL: Should have errored - no room for random part';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: %', SQLERRM;
END
$$;
\echo ''

-- Test 12: 100K uniqueness stress test
\echo 'Test 12: 100K uniqueness stress test'
\timing on
WITH ids AS (
    SELECT nanoid('stress_') as id FROM generate_series(1, 100000)
),
uniqueness AS (
    SELECT COUNT(*) as total, COUNT(DISTINCT id) as unique_count FROM ids
)
SELECT
    total,
    unique_count,
    CASE WHEN total = unique_count THEN 'PASS' ELSE 'FAIL' END as uniqueness_test
FROM uniqueness;
\timing off
\echo ''

\echo '=== Edge Case Tests Complete ==='
