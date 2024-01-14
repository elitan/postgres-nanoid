# pg-nanoid

## Get started

Execute the code in [`nanoid.sql`](nanoid.sql) in your Postgres database. This will create the `nanoid()` function in Postgres that you can use.

Use the `nanoid()` function wherever you want a nano id.

## Example

```sql

-- add examlpe of simply running `nanoid()` to get a nano id when doing a SELECT or something. SELECT nano();

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

> For the most part, only the first two arguments are needed to specify.
