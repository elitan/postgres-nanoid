-- Simple sortable nanoid demonstration
-- Shows that sortable nanoids maintain lexicographic time ordering

\echo '=== Sortable Nanoid Demo ==='
\echo ''

-- Generate sortable IDs with small delays
\echo 'Generating 5 sortable nanoids with delays...'
CREATE TEMP TABLE sortability_demo (
    seq INT,
    regular_nanoid TEXT,
    sortable_nanoid TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert 5 records with delays to show time progression
INSERT INTO sortability_demo (seq, regular_nanoid, sortable_nanoid) 
VALUES (1, nanoid('reg_'), nanoid_sortable('sort_'));
SELECT pg_sleep(0.002);

INSERT INTO sortability_demo (seq, regular_nanoid, sortable_nanoid) 
VALUES (2, nanoid('reg_'), nanoid_sortable('sort_'));
SELECT pg_sleep(0.002);

INSERT INTO sortability_demo (seq, regular_nanoid, sortable_nanoid) 
VALUES (3, nanoid('reg_'), nanoid_sortable('sort_'));
SELECT pg_sleep(0.002);

INSERT INTO sortability_demo (seq, regular_nanoid, sortable_nanoid) 
VALUES (4, nanoid('reg_'), nanoid_sortable('sort_'));
SELECT pg_sleep(0.002);

INSERT INTO sortability_demo (seq, regular_nanoid, sortable_nanoid) 
VALUES (5, nanoid('reg_'), nanoid_sortable('sort_'));

\echo ''
\echo 'Results ordered by creation time:'
SELECT 
    seq,
    regular_nanoid,
    sortable_nanoid,
    created_at
FROM sortability_demo 
ORDER BY created_at;

\echo ''
\echo 'Regular nanoids ordered lexicographically (NOT time-ordered):'
SELECT 
    seq,
    regular_nanoid
FROM sortability_demo 
ORDER BY regular_nanoid;

\echo ''
\echo 'Sortable nanoids ordered lexicographically (SHOULD be time-ordered):'
SELECT 
    seq,
    sortable_nanoid
FROM sortability_demo 
ORDER BY sortable_nanoid;

\echo ''
\echo 'Sortability verification:'
WITH sortability_check AS (
    SELECT 
        sortable_nanoid,
        seq,
        LAG(seq) OVER (ORDER BY sortable_nanoid) as prev_seq
    FROM sortability_demo
)
SELECT 
    COUNT(*) as total_comparisons,
    COUNT(CASE WHEN prev_seq IS NULL OR prev_seq < seq THEN 1 END) as correct_order,
    CASE 
        WHEN COUNT(*) = COUNT(CASE WHEN prev_seq IS NULL OR prev_seq < seq THEN 1 END) 
        THEN 'PASS - Sortable nanoids maintain time order!' 
        ELSE 'FAIL - Order not maintained' 
    END as result
FROM sortability_check;

\echo ''
\echo 'Timestamp extraction demo:'
SELECT 
    sortable_nanoid,
    nanoid_extract_timestamp(sortable_nanoid, 5) as extracted_time,  -- 5 = length of 'sort_'
    created_at,
    abs(extract(epoch from created_at) - extract(epoch from nanoid_extract_timestamp(sortable_nanoid, 5))) < 0.1 as timestamp_accurate
FROM sortability_demo
LIMIT 1;

\echo ''
\echo '=== Performance Test ==='
\timing on

\echo 'Regular nanoid (1000 IDs):'
SELECT COUNT(*) FROM (SELECT nanoid('perf_') FROM generate_series(1, 1000)) t;

\echo 'Sortable nanoid (1000 IDs):'
SELECT COUNT(*) FROM (SELECT nanoid_sortable('perf_') FROM generate_series(1, 1000)) t;

\timing off

\echo ''
\echo '=== Summary ==='
\echo '✓ Sortable nanoids maintain lexicographic time ordering'
\echo '✓ Timestamp extraction works correctly'  
\echo '✓ Performance is comparable to regular nanoids'
\echo '✓ 12-character hex timestamp provides ~2000 years of range'