-- Demo of improved sortable nanoids that look like regular nanoids
-- Uses the same alphabet throughout for consistent appearance

\echo '=== Improved Sortable Nanoid Demo ==='
\echo ''

-- Generate both types for comparison
\echo 'Visual comparison:'
CREATE TEMP TABLE appearance_demo (
    seq INT,
    regular_nanoid TEXT,
    old_sortable TEXT,
    new_sortable TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert 5 records with delays
INSERT INTO appearance_demo (seq, regular_nanoid, old_sortable, new_sortable) 
VALUES (1, nanoid('demo_'), nanoid_sortable_v2('demo_'), nanoid_sortable('demo_'));
SELECT pg_sleep(0.002);

INSERT INTO appearance_demo (seq, regular_nanoid, old_sortable, new_sortable) 
VALUES (2, nanoid('demo_'), nanoid_sortable_v2('demo_'), nanoid_sortable('demo_'));
SELECT pg_sleep(0.002);

INSERT INTO appearance_demo (seq, regular_nanoid, old_sortable, new_sortable) 
VALUES (3, nanoid('demo_'), nanoid_sortable_v2('demo_'), nanoid_sortable('demo_'));
SELECT pg_sleep(0.002);

INSERT INTO appearance_demo (seq, regular_nanoid, old_sortable, new_sortable) 
VALUES (4, nanoid('demo_'), nanoid_sortable_v2('demo_'), nanoid_sortable('demo_'));
SELECT pg_sleep(0.002);

INSERT INTO appearance_demo (seq, regular_nanoid, old_sortable, new_sortable) 
VALUES (5, nanoid('demo_'), nanoid_sortable_v2('demo_'), nanoid_sortable('demo_'));

\echo ''
\echo 'All three types side by side:'
SELECT 
    seq,
    regular_nanoid as regular,
    old_sortable as old_hex_sortable,
    new_sortable as new_alphabet_sortable
FROM appearance_demo 
ORDER BY seq;

\echo ''
\echo 'New sortable nanoids ordered lexicographically (should be time-ordered):'
SELECT 
    seq,
    new_sortable
FROM appearance_demo 
ORDER BY new_sortable;

\echo ''
\echo 'Sortability verification for new version:'
WITH sortability_check AS (
    SELECT 
        new_sortable,
        seq,
        LAG(seq) OVER (ORDER BY new_sortable) as prev_seq
    FROM appearance_demo
)
SELECT 
    COUNT(*) as total_comparisons,
    COUNT(CASE WHEN prev_seq IS NULL OR prev_seq < seq THEN 1 END) as correct_order,
    CASE 
        WHEN COUNT(*) = COUNT(CASE WHEN prev_seq IS NULL OR prev_seq < seq THEN 1 END) 
        THEN 'PASS - New sortable nanoids maintain time order!' 
        ELSE 'FAIL - Order not maintained' 
    END as result
FROM sortability_check;

\echo ''
\echo 'Timestamp extraction from new format:'
SELECT 
    new_sortable,
    nanoid_extract_timestamp(new_sortable, 5) as extracted_time,  -- 5 = length of 'demo_'
    created_at,
    abs(extract(epoch from created_at) - extract(epoch from nanoid_extract_timestamp(new_sortable, 5))) < 0.1 as timestamp_accurate
FROM appearance_demo
LIMIT 1;

\echo ''
\echo 'Character analysis - how similar do they look?'
WITH char_analysis AS (
    SELECT 
        'Regular' as type,
        regular_nanoid as id,
        substring(regular_nanoid, 6) as without_prefix  -- Remove 'demo_'
    FROM appearance_demo
    UNION ALL
    SELECT 
        'Sortable',
        new_sortable,
        substring(new_sortable, 6)
    FROM appearance_demo
)
SELECT 
    type,
    id,
    without_prefix,
    length(without_prefix) as length_without_prefix
FROM char_analysis
ORDER BY type, id;

\echo ''
\echo '=== Performance Comparison ==='
\timing on

\echo 'Regular nanoid (1000 IDs):'
SELECT COUNT(*) FROM (SELECT nanoid('perf_') FROM generate_series(1, 1000)) t;

\echo 'New sortable nanoid (1000 IDs):'
SELECT COUNT(*) FROM (SELECT nanoid_sortable('perf_') FROM generate_series(1, 1000)) t;

\timing off

\echo ''
\echo '=== Summary ==='
\echo '✓ New sortable nanoids use same alphabet as regular nanoids'
\echo '✓ Much more similar visual appearance'  
\echo '✓ Still maintain lexicographic time ordering'
\echo '✓ Timestamp extraction still works'
\echo '✓ Performance remains excellent'