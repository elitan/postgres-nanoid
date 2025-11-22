# PostgreSQL Nanoid

Secure, URL-safe unique identifiers for PostgreSQL. Simple, fast, works everywhere.

## Installation

<details>
<summary>Click to expand installation SQL (copy-paste ready)</summary>

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP FUNCTION IF EXISTS nanoid CASCADE;
DROP FUNCTION IF EXISTS nanoid_optimized CASCADE;

-- Helper function for random generation
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

-- Main nanoid function - secure random IDs
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
    IF size IS NULL OR size < 1 THEN
        RAISE EXCEPTION 'The size must be defined and greater than 0!';
    END IF;
    IF alphabet IS NULL OR length(alphabet) = 0 OR length(alphabet) > 255 THEN
        RAISE EXCEPTION 'The alphabet can''t be undefined, zero or bigger than 255 symbols!';
    END IF;
    IF additionalBytesFactor IS NULL OR additionalBytesFactor < 1 THEN
        RAISE EXCEPTION 'The additional bytes factor can''t be less than 1!';
    END IF;

    random_size := size - length(prefix);

    IF random_size < 1 THEN
        RAISE EXCEPTION 'The size must be larger than the prefix length! Need at least % characters.', length(prefix) + 1;
    END IF;

    alphabetLength := length(alphabet);

    mask := (2 << cast(floor(log(alphabetLength - 1) / log(2)) AS int)) - 1;
    step := cast(ceil(additionalBytesFactor * mask * random_size / alphabetLength) AS int);

    IF step > 1024 THEN
        step := 1024;
    END IF;

    random_part := nanoid_optimized(random_size, alphabet, mask, step);
    finalId := prefix || random_part;

    RETURN finalId;
END
$$;
```

</details>

**Works on all Postgres providers:**
- AWS RDS, Google Cloud SQL, Azure Database, etc
- Self-hosted Postgres (v12+)
- Requires `pgcrypto` extension (available on most managed providers)

## Quick Start

```sql
-- Generate IDs with prefixes
SELECT nanoid('cus_');    -- cus_V1StGXR8_Z5jdHi6B
SELECT nanoid('ord_');    -- ord_K3JwF9HgNxP2mQrTy
SELECT nanoid('user_');   -- user_9LrfQXpAwB3mHkSt

-- Use in tables
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    public_id TEXT NOT NULL UNIQUE DEFAULT nanoid('cus_'),
    name TEXT NOT NULL
);
```

## Why Nanoids

| Feature             | Auto-increment    | UUID          | Nanoid       |
| ------------------- | ----------------- | ------------- | ------------ |
| **Secure**          | No (reveals count)| Yes           | Yes          |
| **Length**          | Variable          | 36 chars      | 21 chars     |
| **URL-friendly**    | Yes               | No (dashes)   | Yes          |
| **Distributed**     | No                | Yes           | Yes          |
| **Performance**     | Fast              | Slower        | Fast         |

## Performance

```sql
SELECT nanoid('ord_') FROM generate_series(1, 100000);
-- ~0.9s = 110,000 IDs/sec
```

- Fast generation (100K+ IDs/sec)
- Memory efficient
- No coordination needed across distributed systems

## Usage

### Basic examples

```sql
-- Default (21 chars)
SELECT nanoid();                    -- V1StGXR8_Z5jdHi6B-myT

-- With prefix
SELECT nanoid('user_');             -- user_V1StGXR8_Z5jdHi6B
SELECT nanoid('ord_');              -- ord_K3JwF9HgNxP2mQrTy

-- Custom size
SELECT nanoid('cus_', 25);          -- cus_V1StGXR8_Z5jdHi6B-my

-- Custom alphabet (hex-only)
SELECT nanoid('tx_', 16, '0123456789abcdef');  -- tx_a3f9d2c1b8e4
```

### Production tables

```sql
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    public_id TEXT NOT NULL UNIQUE DEFAULT nanoid('cus_'),
    name TEXT NOT NULL,
    CHECK (public_id ~ '^cus_[0-9a-zA-Z]{17}$')
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    public_id TEXT NOT NULL UNIQUE DEFAULT nanoid('ord_'),
    customer_id TEXT REFERENCES customers(public_id),
    amount DECIMAL(10,2)
);
```

**Size calculation:** Default size 21 with prefix `cus_` (4 chars) = 17 random characters

### Batch generation

```sql
WITH batch_ids AS (
    SELECT nanoid('item_') as id, 'Product ' || generate_series as name
    FROM generate_series(1, 100000)
)
INSERT INTO products (public_id, name)
SELECT id, name FROM batch_ids;
-- ~1 second for 100k IDs
```

### Parameters

- `prefix` (text, default `''`) - String prepended to ID
- `size` (int, default `21`) - Total length including prefix
- `alphabet` (text, default `'0-9a-zA-Z'`) - 62-char alphabet
- `additionalBytesFactor` (float, default `1.02`) - Buffer multiplier for efficiency

### Custom alphabets

```sql
-- Hex-only IDs
SELECT nanoid('tx_', 16, '0123456789abcdef');
-- tx_a3f9d2c1b8e4

-- Numbers-only (not recommended - less entropy)
SELECT nanoid('ref_', 12, '0123456789');
-- ref_847392

-- URL-safe base64
SELECT nanoid('tok_', 32, '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_');
```

## Time-Sorted IDs (Advanced)

For cases where you need lexicographic time ordering (audit logs, event streams), there's `nanoid_sortable()`. This embeds a timestamp in the ID, which **reveals creation time and business activity patterns**. Use only when necessary.

<details>
<summary>Click to expand sortable installation</summary>

```sql
-- Add to your existing installation
DROP FUNCTION IF EXISTS nanoid_sortable CASCADE;
DROP FUNCTION IF EXISTS nanoid_extract_timestamp CASCADE;

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
    IF size IS NULL OR size < 1 THEN
        RAISE EXCEPTION 'The size must be defined and greater than 0!';
    END IF;
    IF alphabet IS NULL OR length(alphabet) = 0 OR length(alphabet) > 255 THEN
        RAISE EXCEPTION 'The alphabet can''t be undefined, zero or bigger than 255 symbols!';
    END IF;
    IF additionalBytesFactor IS NULL OR additionalBytesFactor < 1 THEN
        RAISE EXCEPTION 'The additional bytes factor can''t be less than 1!';
    END IF;

    timestamp_ms := extract(epoch from clock_timestamp()) * 1000;
    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);
    temp_ts := timestamp_ms;

    IF temp_ts = 0 THEN
        timestamp_encoded := alphabetArray[1];
    ELSE
        WHILE temp_ts > 0 LOOP
            remainder := temp_ts % alphabetLength;
            timestamp_encoded := alphabetArray[remainder + 1] || timestamp_encoded;
            temp_ts := temp_ts / alphabetLength;
        END LOOP;
    END IF;

    WHILE length(timestamp_encoded) < 8 LOOP
        timestamp_encoded := alphabetArray[1] || timestamp_encoded;
    END LOOP;

    random_size := size - length(prefix) - 8;

    IF random_size < 1 THEN
        RAISE EXCEPTION 'The size including prefix and timestamp must leave room for random component! Need at least % characters.', length(prefix) + 9;
    END IF;

    mask := (2 << cast(floor(log(alphabetLength - 1) / log(2)) AS int)) - 1;
    step := cast(ceil(additionalBytesFactor * mask * random_size / alphabetLength) AS int);

    IF step > 1024 THEN
        step := 1024;
    END IF;

    random_part := nanoid_optimized(random_size, alphabet, mask, step);
    finalId := prefix || timestamp_encoded || random_part;

    RETURN finalId;
END
$$;

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
    timestamp_encoded := substring(nanoid_value, prefix_length + 1, 8);
    alphabetArray := regexp_split_to_array(alphabet, '');
    alphabetLength := array_length(alphabetArray, 1);

    FOR i IN 1..length(timestamp_encoded) LOOP
        char_pos := array_position(alphabetArray, substring(timestamp_encoded, i, 1));
        IF char_pos IS NULL THEN
            RAISE EXCEPTION 'Invalid character in timestamp: %', substring(timestamp_encoded, i, 1);
        END IF;
        timestamp_ms := timestamp_ms * alphabetLength + (char_pos - 1);
    END LOOP;

    RETURN to_timestamp(timestamp_ms / 1000.0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid nanoid format or timestamp extraction failed: %', SQLERRM;
END
$$;
```

</details>

**Usage:**

```sql
-- Time-sorted IDs (8 chars timestamp + 9 chars random for size 21 with 4-char prefix)
SELECT nanoid_sortable('log_');     -- log_0uQzNrIEg13LGTj4c
SELECT nanoid_sortable('evt_');     -- evt_0uQzNrIEutvmf1aS

-- Extract timestamp
SELECT nanoid_extract_timestamp('log_0uQzNrIBqK9ayvN1T', 4);
-- 2025-01-15 14:23:10.204

-- Use in tables
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    event_id TEXT NOT NULL UNIQUE DEFAULT nanoid_sortable('log_'),
    message TEXT
);
```

**Trade-offs:**
- **Pro:** Lexicographic time ordering without separate timestamp column
- **Con:** Reveals creation time and business activity patterns
- **Use case:** Internal audit logs where privacy less critical

## Development

```bash
# Clone and test with Docker
git clone https://github.com/elitan/postgres-nanoid
cd postgres-nanoid
make up && make test-all  # Start + run tests
make psql                 # Connect and try functions
```