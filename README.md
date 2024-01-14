# pg-nanoid

A tiny, secure, URL-friendly, unique string ID generator for Postgres with prefix support (e.g. `cus_1Hh9jz4D8JZKw5JX`).

- **Small.** Just a simple Postgres function.
- **Safe.** It uses pgcrypto random generator and can be used in clusters.
- **Portable**. Nano ID was ported
  to [over 20 programming languages](https://github.com/ai/nanoid/blob/main/README.md#other-programming-languages).

## Get started

Execute the SQL Code in [`nanoid.sql`](nanoid.sql) in your Postgres database. Doing so will crete the `nanoid()` function that generates a Nano ID.

## Examples

```sql
SELECT nanoid();
-- fI9CMk9CpKzn2NLPFWLzk

SELECT nanoid('', 4);
-- BPLy

SELECT nanoid('cus_');
-- cus_cjVgkx0ZcloBkDtLa

SELECT nanoid('cus_', 8);
-- cus_CDsm

SELECT nanoid('cus_', 100);
-- cus_vh6np9wmP1Q1dYSWjUR4DMG8MHCs2bNfGezXz42bOBwIXMbx1pM8htS54Gld0G5GH6ipwixrTOWt8EHNQzDLpmG2N72MQSCx

SELECT nanoid('cus_', 4);
-- Query 1 ERROR at Line 1: : ERROR:  The size including the prefix must be greater than 0!
-- CONTEXT:  PL/pgSQL function nanoid(text,integer,text,double precision) line 23 at RAISE
-- Reason: The size must be greater than the prefix length.
```

Create a table and auto generate a Nano ID for each row:

```sql
CREATE TABLE customers(
  id serial PRIMARY KEY,
  public_id text NOT NULL UNIQUE CHECK (public_id LIKE 'cus_%') DEFAULT nanoid('cus_', 8),
  name text NOT NULL
);
```

## Usage

`nano()` takes four arguments:

- `prefix`: The prefix to use for the ID. Defaults to `''` (empty string).
- `size`: The size of the ID (including the prefix). Defaults to `21`.
- `alphabet`: The alphabet to use to generate the ID. Defaults to `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ`.
- `additionalBytesFactor`: A factor determining the randomness quality of the generated ID by adjusting the number of random bytes used. A higher value increases randomness at the cost of performance. Default value is 1.02 which is the most optimal value for the default `alphabet`.

## Calculating the additional bytes factor for a custom alphabet

If you change the alphabet of the `nanoid()` function, you could optimize the performance by calculating a new additional
bytes factor with the following SQL statement:

```sql
WITH input as (SELECT '23456789abcdefghijklmnopqrstuvwxyz' as alphabet)
SELECT round(1 + abs((((2 << cast(floor(log(length(alphabet) - 1) / log(2)) as int)) - 1) - length(alphabet)::numeric) / length(alphabet)), 2) as "Optimal additional bytes factor"
FROM input;
```

Utilizing a custom-calculated additional bytes factor in `nanoid()` enhances string generation performance. This factor
determines how many bytes are generated in a single batch, optimizing computational efficiency. Generating an optimal number
of bytes per batch minimizes redundant operations and conserves memory.

## Thanks

Thanks to [`nanoid-postgres`](https://github.com/viascom/nanoid-postgres) which was used as a reference for this project.
