# pg-nanoid

## Get started

Execute the code in [`nanoid.sql`](nanoid.sql). This will create the `nanoid()` function in Postgres for your to use.

Use the `nanoid()` function wherever you want a nano id.

## Example

```sql
CREATE TABLE customers(
  id serial PRIMARY KEY,
  public_id text NOT NULL UNIQUE CHECK (public_id LIKE 'cus_%') DEFAULT nanoid(8, '023456789abcdefghjkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ', 1.6, 'cus_'),
  name text NOT NULL
);
```
