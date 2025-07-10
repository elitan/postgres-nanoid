-- Parameter testing for alphabet and additionalBytesFactor
-- Run with: \i /tests/parameter_test.sql

\echo '=== Parameter Testing ===';
\echo '';

-- Test 1: Custom alphabet parameter
\echo 'Test 1: Custom alphabet parameter';
\echo '';

-- Test hex alphabet
\echo 'Hex alphabet (0-9, A-F):';
SELECT nanoid('hex_', 16, '0123456789ABCDEF') as hex_nanoid;
\echo '';

-- Test binary alphabet  
\echo 'Binary alphabet (0, 1):';
SELECT nanoid('bin_', 20, '01') as binary_nanoid;
\echo '';

-- Test custom alphabet with special chars
\echo 'Custom alphabet (vowels only):';
SELECT nanoid('vowel_', 15, 'AEIOU') as vowel_nanoid;
\echo '';

-- Test 2: Alphabet validation
\echo 'Test 2: Alphabet validation';
\echo '';

\echo 'Testing empty alphabet (should error):';
DO $$
BEGIN
    PERFORM nanoid('test_', 10, '');
    RAISE NOTICE 'ERROR: Should have failed with empty alphabet!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Correctly caught error: %', SQLERRM;
END
$$;
\echo '';

\echo 'Testing too large alphabet (should error):';
DO $$
DECLARE
    large_alphabet text;
BEGIN
    -- Create alphabet > 255 characters
    large_alphabet := repeat('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', 10);
    PERFORM nanoid('test_', 10, large_alphabet);
    RAISE NOTICE 'ERROR: Should have failed with large alphabet!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Correctly caught error: %', SQLERRM;
END
$$;
\echo '';

-- Test 3: additionalBytesFactor parameter
\echo 'Test 3: additionalBytesFactor parameter';
\echo '';

\echo 'Testing minimum additionalBytesFactor (1.0):';
\timing on
SELECT nanoid('min_', 21, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 1.0) as min_factor;
\timing off
\echo '';

\echo 'Testing default additionalBytesFactor (1.02):';
\timing on
SELECT nanoid('def_', 21, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 1.02) as default_factor;
\timing off
\echo '';

\echo 'Testing higher additionalBytesFactor (2.0):';
\timing on
SELECT nanoid('high_', 21, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 2.0) as high_factor;
\timing off
\echo '';

-- Test 4: additionalBytesFactor validation
\echo 'Test 4: additionalBytesFactor validation';
\echo '';

\echo 'Testing invalid additionalBytesFactor < 1 (should error):';
DO $$
BEGIN
    PERFORM nanoid('test_', 10, '0123456789', 0.5);
    RAISE NOTICE 'ERROR: Should have failed with additionalBytesFactor < 1!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'PASS: Correctly caught error: %', SQLERRM;
END
$$;
\echo '';

-- Test 5: Performance comparison with different additionalBytesFactor values
\echo 'Test 5: Performance comparison (generating 1000 IDs each)';
\echo '';

\echo 'Performance with additionalBytesFactor = 1.0:';
\timing on
SELECT count(*) as generated_count 
FROM (
    SELECT nanoid('perf1_', 21, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 1.0)
    FROM generate_series(1, 1000)
) t;
\timing off
\echo '';

\echo 'Performance with additionalBytesFactor = 1.02 (default):';
\timing on
SELECT count(*) as generated_count 
FROM (
    SELECT nanoid('perf2_', 21, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 1.02)
    FROM generate_series(1, 1000)
) t;
\timing off
\echo '';

\echo 'Performance with additionalBytesFactor = 2.0:';
\timing on
SELECT count(*) as generated_count 
FROM (
    SELECT nanoid('perf3_', 21, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 2.0)
    FROM generate_series(1, 1000)
) t;
\timing off
\echo '';

-- Test 6: Alphabet impact on timestamp extraction
\echo 'Test 6: Alphabet compatibility with timestamp extraction';
\echo '';

\echo 'NOTE: Custom alphabets change timestamp encoding base, affecting extraction accuracy';
\echo 'This is expected behavior - timestamp extraction requires same alphabet as generation';
\echo '';

-- Generate nanoid with custom alphabet and test timestamp extraction
WITH custom_test AS (
    SELECT 
        nanoid('hex_', 20, '0123456789ABCDEF') as custom_id,
        NOW() as created_at
)
SELECT 
    custom_id,
    'Custom hex alphabet encodes timestamp differently than default' as note,
    'Timestamp extraction requires matching alphabet for accurate results' as limitation
FROM custom_test;

-- Show that default alphabet extraction works properly
WITH default_test AS (
    SELECT 
        nanoid('def_', 20) as default_id,
        NOW() as created_at
)
SELECT 
    default_id,
    created_at,
    nanoid_extract_timestamp(default_id, 4) as extracted_timestamp,
    CASE 
        WHEN abs(extract(epoch from created_at) - extract(epoch from nanoid_extract_timestamp(default_id, 4))) < 1 
        THEN 'PASS - Default alphabet timestamp extraction works!' 
        ELSE 'FAIL - Default alphabet timestamp extraction failed' 
    END as default_alphabet_test
FROM default_test;
\echo '';

-- Test 7: Sortability with custom alphabets
\echo 'Test 7: Sortability with custom alphabets';
\echo '';

CREATE TEMP TABLE custom_alphabet_test (
    seq INT,
    hex_nanoid TEXT,
    binary_nanoid TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert with delays to test time ordering with custom alphabets
INSERT INTO custom_alphabet_test (seq, hex_nanoid, binary_nanoid) 
VALUES (1, nanoid('hex_', 20, '0123456789ABCDEF'), nanoid('bin_', 30, '01'));
SELECT pg_sleep(0.002);

INSERT INTO custom_alphabet_test (seq, hex_nanoid, binary_nanoid) 
VALUES (2, nanoid('hex_', 20, '0123456789ABCDEF'), nanoid('bin_', 30, '01'));
SELECT pg_sleep(0.002);

INSERT INTO custom_alphabet_test (seq, hex_nanoid, binary_nanoid) 
VALUES (3, nanoid('hex_', 20, '0123456789ABCDEF'), nanoid('bin_', 30, '01'));

-- Check if custom alphabet nanoids are time-ordered
SELECT 
    seq,
    hex_nanoid,
    binary_nanoid
FROM custom_alphabet_test 
ORDER BY hex_nanoid;  -- Should be in seq order

\echo '';

-- Verify custom alphabet sortability
WITH hex_sorted AS (
    SELECT 
        seq,
        LAG(seq) OVER (ORDER BY hex_nanoid) as prev_seq
    FROM custom_alphabet_test
),
hex_check AS (
    SELECT 
        COUNT(*) as total_records,
        COUNT(CASE 
            WHEN prev_seq IS NULL OR prev_seq < seq 
            THEN 1 
        END) as correctly_sorted
    FROM hex_sorted
)
SELECT 
    'Hex alphabet sortability:' as test_type,
    total_records,
    correctly_sorted,
    CASE 
        WHEN total_records = correctly_sorted 
        THEN 'PASS - Custom hex alphabet maintains time-ordering!' 
        ELSE 'FAIL - Custom hex alphabet time ordering broken' 
    END as sortability_test
FROM hex_check;

WITH binary_sorted AS (
    SELECT 
        seq,
        LAG(seq) OVER (ORDER BY binary_nanoid) as prev_seq
    FROM custom_alphabet_test
),
binary_check AS (
    SELECT 
        COUNT(*) as total_records,
        COUNT(CASE 
            WHEN prev_seq IS NULL OR prev_seq < seq 
            THEN 1 
        END) as correctly_sorted
    FROM binary_sorted
)
SELECT 
    'Binary alphabet sortability:' as test_type,
    total_records,
    correctly_sorted,
    CASE 
        WHEN total_records = correctly_sorted 
        THEN 'PASS - Custom binary alphabet maintains time-ordering!' 
        ELSE 'FAIL - Custom binary alphabet time ordering broken' 
    END as sortability_test
FROM binary_check;

\echo '';
\echo '=== Parameter testing completed ===';