#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# lovable-local-cloud — Bootstrap / Init Script
# Runs once after core services are healthy.
# ============================================================

LOG_PREFIX="[llc-init]"
log() { echo "$LOG_PREFIX $*"; }
err() { echo "$LOG_PREFIX ERROR: $*" >&2; }

# --- Config ---
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:-postgres-local-dev}"
export PGPASSWORD="$DB_PASSWORD"

TARGET_APP="/target-app"
MIGRATIONS_DIR="${TARGET_APP}/supabase/migrations"
SEED_FILE="${TARGET_APP}/supabase/seed.sql"

SUPABASE_URL="${SUPABASE_URL:-http://kong:8000}"
SERVICE_ROLE_KEY="${SERVICE_ROLE_KEY}"
ANON_KEY="${ANON_KEY}"

# --- Wait for Postgres ---
log "Waiting for Postgres..."
for i in $(seq 1 30); do
  if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; then
    log "Postgres is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    err "Postgres did not become ready in time."
    exit 1
  fi
  sleep 2
done

# --- Setup Supabase roles and schemas ---
log "Setting up Supabase-compatible roles and schemas..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=0 <<'EOSQL'
-- Create roles if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'postgres-local-dev';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin NOINHERIT CREATEROLE LOGIN PASSWORD 'postgres-local-dev';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE ROLE supabase_storage_admin NOINHERIT CREATEROLE LOGIN PASSWORD 'postgres-local-dev';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE ROLE supabase_admin NOINHERIT CREATEROLE LOGIN PASSWORD 'postgres-local-dev';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dashboard_user') THEN
    CREATE ROLE dashboard_user NOINHERIT CREATEROLE LOGIN PASSWORD 'postgres-local-dev';
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_functions_admin') THEN
    CREATE ROLE supabase_functions_admin NOINHERIT CREATEROLE LOGIN PASSWORD 'postgres-local-dev';
  END IF;
END
$$;

-- Grant roles
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;
GRANT supabase_auth_admin TO postgres;
GRANT supabase_storage_admin TO postgres;
GRANT supabase_admin TO postgres;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION supabase_auth_admin;
CREATE SCHEMA IF NOT EXISTS storage AUTHORIZATION supabase_storage_admin;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE SCHEMA IF NOT EXISTS _realtime;
CREATE SCHEMA IF NOT EXISTS supabase_functions AUTHORIZATION supabase_functions_admin;

-- Grant schema access
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO anon, authenticated, service_role;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgjwt WITH SCHEMA extensions;

-- Grant extensions schema usage
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA extensions TO anon, authenticated, service_role;

EOSQL

log "Roles and schemas created."

# --- Apply migrations ---
if [ -d "$MIGRATIONS_DIR" ] && [ "$(ls -A "$MIGRATIONS_DIR" 2>/dev/null)" ]; then
  log "Applying migrations from $MIGRATIONS_DIR..."
  for f in "$MIGRATIONS_DIR"/*.sql; do
    log "  Applying: $(basename "$f")"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$f" || {
      err "Migration failed: $(basename "$f")"
      # Continue with other migrations — some may be already applied
    }
  done
  log "Migrations complete."
else
  log "No migrations found. Skipping."
fi

# --- Apply seed ---
if [ -f "$SEED_FILE" ] && [ -s "$SEED_FILE" ]; then
  log "Applying seed from $SEED_FILE..."
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SEED_FILE" || {
    err "Seed application had errors (may be idempotent, continuing)."
  }
  log "Seed complete."
else
  log "No seed file found. Skipping."
fi

# --- Wait for Storage API ---
log "Waiting for Storage API..."
for i in $(seq 1 30); do
  if curl -sf http://storage:5000/status > /dev/null 2>&1; then
    log "Storage API is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    err "Storage API did not become ready in time."
    exit 1
  fi
  sleep 2
done

# --- Create storage buckets ---
log "Creating smoke test bucket (llc-smoke)..."
curl -sf -X POST "http://storage:5000/bucket" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"id":"llc-smoke","name":"llc-smoke","public":true}' || log "Bucket llc-smoke may already exist."

# Read config for additional buckets if available
CONFIG_FILE="${TARGET_APP}/lovable-local-cloud.config.json"
if [ -f "$CONFIG_FILE" ]; then
  log "Reading config from $CONFIG_FILE..."
  BUCKETS=$(jq -r '.bootstrap.storageBuckets[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
  for bucket in $BUCKETS; do
    log "Creating bucket: $bucket"
    curl -sf -X POST "http://storage:5000/bucket" \
      -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"id\":\"${bucket}\",\"name\":\"${bucket}\",\"public\":true}" || log "Bucket ${bucket} may already exist."
  done
fi

log ""
log "=========================================="
log " Bootstrap complete!"
log "=========================================="
log ""
log " Frontend:    http://localhost:${FRONTEND_PORT:-3000}"
log " API Gateway: http://localhost:${API_GATEWAY_PORT:-54321}"
log " MailHog UI:  http://localhost:${MAILHOG_PORT:-8025}"
log " Postgres:    localhost:${POSTGRES_PORT:-54322}"
log ""
log "=========================================="

exit 0
