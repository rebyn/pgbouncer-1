### Traffic Flow

0.0.0.0:5432 (stunnel) -> 127.0.0.1:6432 (pgbouncer)
127.0.0.1:6432 (pgbouncer) -> 127.0.0.1:7432 (stunnel)
127.0.0.1:7432 (stunnel) -> ec2-xxx.compute1.amazon.com:5432 (Heroku PG)


```
pgbouncer:
  image: quay.io/rebyn/pgbouncer:latest
  environment:
    POSTGRES_URL: "postgres://USERNAME:PASSWORD@DB_HOST:DB_PORT/DB_NAME"
    PGBOUNCER_DEFAULT_POOL_SIZE: 25
    PGBOUNCER_POOL_MODE: transaction
```