#!/usr/bin/env bash
# Bring up a local PostgreSQL for development and tests.
# Uses docker when available, otherwise a system cluster.
set -euo pipefail

DB_USER=${DB_USER:-iwp}
DB_PASS=${DB_PASS:-iwp}

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker inspect iwp-postgres >/dev/null 2>&1 \
    && docker start iwp-postgres \
    || docker run -d --name iwp-postgres \
         -e POSTGRES_USER="$DB_USER" -e POSTGRES_PASSWORD="$DB_PASS" \
         -e POSTGRES_DB=iwp_dev -p 5432:5432 postgres:16
else
  echo "docker unavailable; starting system cluster"
  pg_ctlcluster 16 main start || true
fi

for _ in $(seq 1 30); do
  PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d postgres -c 'select 1' >/dev/null 2>&1 && break
  sleep 1
done

PGPASSWORD="$DB_PASS" psql -h localhost -U "$DB_USER" -d postgres \
  -tc "SELECT 1 FROM pg_database WHERE datname='iwp_test'" | grep -q 1 \
  || PGPASSWORD="$DB_PASS" createdb -h localhost -U "$DB_USER" iwp_test

echo "postgres ready"
