# pg-nanoid

## Get started

Execute the code in [`nanoid.sql`](nanoid.sql) in your Postgres database. This will create the `nanoid()` function in Postgres that you can use.

Use the `nanoid()` function wherever you want a nano id.

## Example

```sql
CREATE TABLE customers(
  id serial PRIMARY KEY,
  public_id text NOT NULL UNIQUE CHECK (public_id LIKE 'cus_%') DEFAULT nanoid('cus_', 8),
  name text NOT NULL
);
```

## Usage

`nano()` takes four arguments:

- `prefix`: The prefix to use for the id. Defaults to `''`.
- `size`: The size of the id. Defaults to `21`. Note: The size does not include the prefix.
- `alphabet`: The alphabet to use for the id. Defaults to `'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz-'`.
- `additionalBytesFactor`.

For the most part, only the first two arguments are needed. The `alphabet` and `additionalBytesFactor` are only needed if you want to change the default values.
