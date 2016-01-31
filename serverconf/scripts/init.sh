#!/usr/bin/env bash

set -x 
set -e

POSTGRES_URL=${POSTGRES_URL:-localhost}
POOL_MODE=${PGBOUNCER_POOL_MODE:-transaction}
SERVER_RESET_QUERY=${PGBOUNCER_SERVER_RESET_QUERY}

DB=$(echo $POSTGRES_URL | perl -lne 'print "$1 $2 $3 $4 $5 $6 $7" if /^postgres:\/\/([^:]+):([^@]+)@(.*?):(.*?)\/(.*?)(\\?.*)?$/')
DB_URI=( $DB )
DB_USER=${DB_URI[0]}
DB_PASS=${DB_URI[1]}
DB_HOST=${DB_URI[2]}
DB_PORT=${DB_URI[3]}
DB_NAME=${DB_URI[4]}
DB_MD5_PASS="md5"`echo -n ${DB_PASS}${DB_USER} | md5sum | awk '{print $1}'`

rm -rf /etc/stunnel/stunnel-pgbouncer.conf
rm -rf /etc/pgbouncer/pgbouncer.ini
rm -rf /etc/pgbouncer/users.txt

mkdir -p /etc/stunnel/
mkdir -p /etc/pgbouncer/

cat >> /etc/pgbouncer/pgbouncer.ini << EOFEOF
[pgbouncer]
logfile = /var/log/postgresql/pgbouncer.log
pidfile = /var/run/postgresql/pgbouncer.pid
listen_addr = 127.0.0.1
listen_port = 6432
unix_socket_dir = /var/run/postgresql
auth_type = md5
auth_file = /etc/pgbouncer/users.txt
admin_users = veroadmin
pool_mode = ${POOL_MODE}
server_reset_query = ${SERVER_RESET_QUERY}
max_client_conn = ${PGBOUNCER_MAX_CLIENT_CONN:-100}
default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE:-1}
reserve_pool_size = ${PGBOUNCER_RESERVE_POOL_SIZE:-1}
reserve_pool_timeout = ${PGBOUNCER_RESERVE_POOL_TIMEOUT:-5.0}
log_connections = ${PGBOUNCER_LOG_CONNECTIONS:-1}
log_disconnections = ${PGBOUNCER_LOG_DISCONNECTIONS:-1}
log_pooler_errors = ${PGBOUNCER_LOG_POOLER_ERRORS:-1}
stats_period = ${PGBOUNCER_STATS_PERIOD:-60}
[databases]
${DB_NAME} = dbname=${DB_NAME} host=127.0.0.1 port=7432 user=${DB_USER} password=${DB_PASS} connect_query='SELECT 1'
EOFEOF

cat >> /etc/pgbouncer/users.txt << EOFEOF
"$DB_USER" "$DB_MD5_PASS"
EOFEOF

cat >> /etc/stunnel/stunnel-pgbouncer.conf << EOFEOF
[ingress]
protocol = pgsql
client = no
accept = 0.0.0.0:5432
connect = 127.0.0.1:6432
retry = no
retry = ${PGBOUNCER_CONNECTION_RETRY:-"no"}
cert = /etc/stunnel/stunnel.pem

[egress]
client = yes
protocol = pgsql
accept  = 127.0.0.1:7432
connect = $DB_HOST:$DB_PORT
retry = ${PGBOUNCER_CONNECTION_RETRY:-"no"}
EOFEOF

chmod go-rwx /etc/pgbouncer/*
chmod go-rwx /etc/stunnel/*
chmod 600 /etc/stunnel/stunnel.pem
chown -R postgres:postgres /etc/pgbouncer
chown root:postgres /var/log/postgresql
chmod 1775 /var/log/postgresql
chmod 640 /etc/pgbouncer/users.txt

exec /usr/bin/supervisord -n