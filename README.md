# pg-nanoid

## Get started

Execute the code in [`nanoid.sql`](nanoid.sql) in your Postgres database. This will create the `nanoid()` function in Postgres that you can use.

Use the `nanoid()` function wherever you want a nano id.

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
```

Create a table and auto generate a nano id for each row:

```sql
CREATE TABLE customers(
  id serial PRIMARY KEY,
  public_id text NOT NULL UNIQUE CHECK (public_id LIKE 'cus_%') DEFAULT nanoid('cus_', 8),
  name text NOT NULL
);
```

## Usage

`nano()` takes four arguments:

- `prefix`: The prefix to use for the id. Defaults to `''` (empty string).
- `size`: The size of the id (including the prefix). Defaults to `21`.
- `alphabet`: The alphabet to use to generate the id. Defaults to `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ`.
- `additionalBytesFactor`: A factor determining the randomness quality of the generated ID by adjusting the number of random bytes used. A higher value increases randomness at the cost of performance. Default value is 1.6.
