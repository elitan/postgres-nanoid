-- Sortability test for postgres-nanoid
-- Demonstrates that nanoids are NOT sortable by creation time
-- Run with: \i /tests/sortability_test.sql

\timing on

-- Generate IDs with timestamps to show lack of time-based sorting
CREATE TEMP TABLE sortability_test (
    id SERIAL,
    nanoid_value TEXT DEFAULT nanoid('test_'),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert records with small delays to show time progression
INSERT INTO sortability_test DEFAULT VALUES;
SELECT pg_sleep(0.001); -- 1ms delay
INSERT INTO sortability_test DEFAULT VALUES;
SELECT pg_sleep(0.001);
INSERT INTO sortability_test DEFAULT VALUES;
SELECT pg_sleep(0.001);
INSERT INTO sortability_test DEFAULT VALUES;
SELECT pg_sleep(0.001);
INSERT INTO sortability_test DEFAULT VALUES;

-- Show the results - nanoids are NOT in chronological order
SELECT 
    id,
    nanoid_value,
    created_at,
    -- Show if nanoid is lexicographically ordered by creation time
    LAG(nanoid_value) OVER (ORDER BY created_at) < nanoid_value as is_sorted
FROM sortability_test 
ORDER BY created_at;

-- Generate larger sample to demonstrate randomness
SELECT 'Larger sample showing randomness:' as demo;
WITH sample AS (
    SELECT 
        nanoid('demo_') as id,
        generate_series as seq
    FROM generate_series(1, 20)
)
SELECT id, seq FROM sample ORDER BY seq;

\timing off