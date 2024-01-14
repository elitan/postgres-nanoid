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
