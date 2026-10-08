#!/bin/sh
# Richtet den phpMyAdmin-Konfigurationsspeicher ein: Datenbank "phpmyadmin"
# mit den Tabellen aus dem phpMyAdmin-Image und den Benutzer "pma"
# (Passwort PMA_CONTROL_PASSWORD aus docker/.env).
# Kann beliebig oft ausgeführt werden, z. B. nach einem neuen DB-Volume.
set -e
cd "$(dirname "$0")"

PMA_CONTROL_PASSWORD=$(grep '^PMA_CONTROL_PASSWORD=' .env | cut -d= -f2- | tr -d "'\"")
if [ -z "$PMA_CONTROL_PASSWORD" ]; then
    echo "PMA_CONTROL_PASSWORD fehlt in docker/.env" >&2
    exit 1
fi

mysql_root() {
    docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot'
}

# Tabellen anlegen (das Skript nutzt CREATE ... IF NOT EXISTS)
docker compose exec -T phpmyadmin cat /var/www/html/sql/create_tables.sql </dev/null | mysql_root

mysql_root <<SQL
CREATE USER IF NOT EXISTS 'pma'@'%' IDENTIFIED BY '$PMA_CONTROL_PASSWORD';
ALTER USER 'pma'@'%' IDENTIFIED BY '$PMA_CONTROL_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON phpmyadmin.* TO 'pma'@'%';
SQL

echo "phpMyAdmin-Konfigurationsspeicher eingerichtet."
