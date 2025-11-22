/*
 * Postgres Nano ID - Secure and optionally sortable unique identifiers
 * 
 * A PostgreSQL implementation of nanoids with dual functions:
 * - nanoid(): Purely random, secure IDs (recommended default)
 * - nanoid_sortable(): Time-ordered IDs (use only when sorting is essential)
 * 
 * Features:
 * - Cryptographically secure random generation
 * - URL-safe characters using nanoid alphabet  
 * - Prefix support (e.g., 'cus_', 'ord_')
 * - High performance optimized for batch generation
 * - Optional lexicographic time ordering (with security trade-offs)
 * 
 * Security Note: nanoid_sortable() embeds timestamps which can leak business
 * intelligence and timing information. Use nanoid() for better security.
 * 
 * Inspired by nanoid-postgres (https://github.com/viascom/nanoid-postgres)
 * and the broader nanoid ecosystem.
 */
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Drop existing functions to ensure clean state
DROP FUNCTION IF EXISTS nanoid CASCADE;
DROP FUNCTION IF EXISTS nanoid_sortable CASCADE;
DROP FUNCTION IF EXISTS nanoid_optimized CASCADE;
DROP FUNCTION IF EXISTS nanoid_extract_timestamp CASCADE;

-- Create the optimized helper function for random part generation
CREATE OR REPLACE FUNCTION nanoid_optimized(size int, alphabet text, mask int, step int)
    RETURNS text
    LANGUAGE plpgsql
    VOLATILE PARALLEL SAFE
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

-- Sortable nanoid function with timestamp encoding (use only if temporal ordering is required)
-- WARNING: This function embeds timestamps in IDs, which can leak business intelligence
-- and timing information. Use the regular nanoid() function for better security.
CREATE OR REPLACE FUNCTION nanoid_sortable(
    prefix text DEFAULT '',
    size int DEFAULT 21,
    alphabet text DEFAULT '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
    additionalBytesFactor float DEFAULT 1.02
)
    RETURNS text
    LANGUAGE plpgsql
    VOLATILE PARALLEL SAFE
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

-- Main nanoid function - purely random, secure by default
CREATE OR REPLACE FUNCTION nanoid(
    prefix text DEFAULT '',
    size int DEFAULT 21,
    alphabet text DEFAULT '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
    additionalBytesFactor float DEFAULT 1.02
)
    RETURNS text
    LANGUAGE plpgsql
    VOLATILE PARALLEL SAFE
    AS $$
DECLARE
    random_size int;
    random_part text;
    finalId text;
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
    
    -- Calculate random part size (full size minus prefix)
    random_size := size - length(prefix);
    
    IF random_size < 1 THEN
        RAISE EXCEPTION 'The size must be larger than the prefix length! Need at least % characters.', length(prefix) + 1;
    END IF;
    
    alphabetLength := length(alphabet);
    
    -- Generate purely random part using optimized function
    mask := (2 << cast(floor(log(alphabetLength - 1) / log(2)) AS int)) - 1;
    step := cast(ceil(additionalBytesFactor * mask * random_size / alphabetLength) AS int);
    
    IF step > 1024 THEN
        step := 1024;
    END IF;
    
    random_part := nanoid_optimized(random_size, alphabet, mask, step);
    
    -- Combine: prefix + random (no timestamp)
    finalId := prefix || random_part;
    
    RETURN finalId;
END
$$;

-- Helper function to extract timestamp from sortable nanoid (only works with nanoid_sortable)
CREATE OR REPLACE FUNCTION nanoid_extract_timestamp(
    nanoid_value text,
    prefix_length int DEFAULT 0,
    alphabet text DEFAULT '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
)
    RETURNS timestamp
    LANGUAGE plpgsql
    IMMUTABLE PARALLEL SAFE
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