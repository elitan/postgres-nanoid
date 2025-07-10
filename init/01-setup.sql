-- Initialize the nanoid function
-- This runs automatically when the container starts

-- Create the pgcrypto extension
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop existing functions to ensure clean state
DROP FUNCTION IF EXISTS nanoid CASCADE;
DROP FUNCTION IF EXISTS nanoid_optimized CASCADE;
DROP FUNCTION IF EXISTS nanoid_extract_timestamp CASCADE;

-- Create the optimized helper function for random part generation
CREATE OR REPLACE FUNCTION nanoid_optimized(size int, alphabet text, mask int, step int)
    RETURNS text
    LANGUAGE plpgsql
    VOLATILE LEAKPROOF PARALLEL SAFE
    AS $$
DECLARE
    idBuilder text := '';
    counter int := 0;
    bytes bytea;
    alphabetIndex int;
    alphabetArray text[];
    alphabetLength int := 64;
BEGIN
    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);
    LOOP
        bytes := gen_random_bytes(step);
        FOR counter IN 0..step - 1 LOOP
            alphabetIndex :=(get_byte(bytes, counter) & mask) + 1;
            IF alphabetIndex <= alphabetLength THEN
                idBuilder := idBuilder || alphabetArray[alphabetIndex];
                IF length(idBuilder) = size THEN
                    RETURN idBuilder;
                END IF;
            END IF;
        END LOOP;
    END LOOP;
END
$$;

-- Main nanoid function with inline timestamp encoding
CREATE OR REPLACE FUNCTION nanoid(
    prefix text DEFAULT '', 
    size int DEFAULT 21, 
    alphabet text DEFAULT '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', 
    additionalBytesFactor float DEFAULT 1.02
)
    RETURNS text
    LANGUAGE plpgsql
    VOLATILE LEAKPROOF PARALLEL SAFE
    AS $$
DECLARE
    timestamp_ms bigint;
    timestamp_encoded text := '';
    remainder int;
    temp_ts bigint;
    random_size int;
    random_part text;
    finalId text;
    alphabetArray text[];
    alphabetLength int;
    mask int;
    step int;
BEGIN
    -- Input validation
    IF size IS NULL OR size < 1 THEN
        RAISE EXCEPTION 'The size must be defined and greater than 0!';
    END IF;
    IF alphabet IS NULL OR length(alphabet) = 0 OR length(alphabet) > 255 THEN
        RAISE EXCEPTION 'The alphabet can''t be undefined, zero or bigger than 255 symbols!';
    END IF;
    IF additionalBytesFactor IS NULL OR additionalBytesFactor < 1 THEN
        RAISE EXCEPTION 'The additional bytes factor can''t be less than 1!';
    END IF;
    
    -- Get current timestamp and encode using nanoid alphabet (inline for simplicity)
    timestamp_ms := extract(epoch from clock_timestamp()) * 1000;
    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);
    temp_ts := timestamp_ms;
    
    -- Handle zero case
    IF temp_ts = 0 THEN
        timestamp_encoded := alphabetArray[1];
    ELSE
        -- Convert to base using nanoid alphabet
        WHILE temp_ts > 0 LOOP
            remainder := temp_ts % alphabetLength;
            timestamp_encoded := alphabetArray[remainder + 1] || timestamp_encoded;
            temp_ts := temp_ts / alphabetLength;
        END LOOP;
    END IF;
    
    -- Pad to 8 characters for consistent lexicographic sorting
    WHILE length(timestamp_encoded) < 8 LOOP
        timestamp_encoded := alphabetArray[1] || timestamp_encoded;
    END LOOP;
    
    -- Calculate remaining size for random part  
    random_size := size - length(prefix) - 8; -- 8 = timestamp length
    
    IF random_size < 1 THEN
        RAISE EXCEPTION 'The size including prefix and timestamp must leave room for random component! Need at least % characters.', length(prefix) + 9;
    END IF;
    
    -- Generate random part using optimized function
    mask := (2 << cast(floor(log(alphabetLength - 1) / log(2)) AS int)) - 1;
    step := cast(ceil(additionalBytesFactor * mask * random_size / alphabetLength) AS int);
    
    IF step > 1024 THEN
        step := 1024;
    END IF;
    
    random_part := nanoid_optimized(random_size, alphabet, mask, step);
    
    -- Combine: prefix + timestamp + random
    finalId := prefix || timestamp_encoded || random_part;
    
    RETURN finalId;
END
$$;

-- Helper function to extract timestamp from nanoid (useful for debugging/analysis)
CREATE OR REPLACE FUNCTION nanoid_extract_timestamp(
    nanoid_value text, 
    prefix_length int DEFAULT 0,
    alphabet text DEFAULT '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
)
    RETURNS timestamp
    LANGUAGE plpgsql
    IMMUTABLE LEAKPROOF PARALLEL SAFE
    AS $$
DECLARE
    timestamp_encoded text;
    timestamp_ms bigint := 0;
    alphabetArray text[];
    alphabetLength int;
    char_pos int;
    i int;
BEGIN
    -- Extract 8-character timestamp after the prefix
    timestamp_encoded := substring(nanoid_value, prefix_length + 1, 8);
    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);
    
    -- Decode from base using nanoid alphabet (inline for simplicity)
    FOR i IN 1..length(timestamp_encoded) LOOP
        char_pos := array_position(alphabetArray, substring(timestamp_encoded, i, 1));
        IF char_pos IS NULL THEN
            RAISE EXCEPTION 'Invalid character in timestamp: %', substring(timestamp_encoded, i, 1);
        END IF;
        timestamp_ms := timestamp_ms * alphabetLength + (char_pos - 1);
    END LOOP;
    
    -- Convert to timestamp
    RETURN to_timestamp(timestamp_ms / 1000.0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid nanoid format or timestamp extraction failed: %', SQLERRM;
END
$$;

-- Create a test table for demonstrations
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    public_id TEXT NOT NULL UNIQUE CHECK (public_id LIKE 'cus_%') DEFAULT nanoid('cus_'),
    name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Test that everything works
SELECT 'Database initialized successfully. Testing nanoid function:' as status;
SELECT nanoid('test_') as sample_nanoid;