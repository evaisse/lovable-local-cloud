# lovable-local-cloud — Technical Specification

## 1. Mission

**lovable-local-cloud** is a local-first Docker Compose testing harness for web apps exported from [Lovable](https://lovable.dev).

It provides a reproducible local environment so developers can run, test, and debug their exported Lovable apps against a real Supabase-compatible backend — without deploying anything to the cloud.

### What this project IS

- A **Lovable-compatible local testing harness**
- A deterministic, Docker Compose-based fullstack environment
- A tool for local E2E testing of exported Lovable apps

### What this project is NOT

- **Not** an official Lovable product
- **Not** a replacement for Lovable Cloud
- **Not** production hosting infrastructure
- **Not** a guarantee of full parity with every managed Lovable feature

---

## 2. Architecture

### 2.1 Services

The Docker Compose stack includes the following services:

| Service       | Role                                              |
|---------------|---------------------------------------------------|
| `frontend`    | Builds and serves the exported Lovable app        |
| `db`          | PostgreSQL database                               |
| `kong`        | API gateway (routes to Auth, REST, Storage, etc.) |
| `auth`        | Supabase Auth (GoTrue)                            |
| `rest`        | Supabase REST API (PostgREST)                     |
| `realtime`    | Supabase Realtime                                 |
| `storage`     | Supabase Storage                                  |
| `functions`   | Supabase Edge Functions (Deno-based)              |
| `mailhog`     | Local email capture (SMTP + web UI)               |
| `init`        | Bootstrap container (migrations, seeds, buckets)  |

Services **not** included in the default stack (out of scope for v0):
- Supabase Studio
- Analytics

### 2.2 Port Mappings

| Service          | Host Port | Description                |
|------------------|-----------|----------------------------|
| Frontend         | `3000`    | Lovable app UI             |
| API Gateway      | `54321`   | Kong → Auth/REST/Storage   |
| PostgreSQL       | `54322`   | Direct database access     |
| MailHog UI       | `8025`    | Email capture web UI       |
| MailHog SMTP     | `1025`    | SMTP for Auth emails       |

---

## 3. Frontend

### Build Pipeline

- **Base image:** Node 22 (multi-stage Docker build)
- **Install:** `npm ci` (default, overridable)
- **Build:** `npm run build` (default, overridable)
- **Output directory:** `dist/` (default, overridable)
- **Serving:** nginx with SPA fallback (all non-file routes → `index.html`)

### Injected Environment Variables

The following variables are injected at build time so the frontend can connect to the local Supabase-compatible backend:

| Variable                          | Purpose                                  |
|-----------------------------------|------------------------------------------|
| `VITE_SUPABASE_URL`              | URL of the local API gateway             |
| `VITE_SUPABASE_PUBLISHABLE_KEY`  | Anonymous (public) key for Supabase      |
| `VITE_SUPABASE_PROJECT_ID`       | Local project identifier (default: `local`) |

---

## 4. Backend

The backend is a Supabase-compatible stack composed of:

- **PostgreSQL** — primary database
- **Auth (GoTrue)** — email/password authentication, routed through Kong
- **REST (PostgREST)** — auto-generated REST API from the database schema
- **Storage** — file upload/download with bucket support
- **Realtime** — WebSocket-based real-time subscriptions
- **Edge Functions** — Deno-based serverless functions

All backend services are accessed through the Kong API gateway at port `54321`.

---

## 5. Bootstrap Flow

The `init` container performs deterministic bootstrap on every stack start:

1. **Validate** `TARGET_APP_PATH` — ensure the mounted app directory exists and contains a `package.json`
2. **Generate secrets** — create local development JWT secret, anon key, and service role key if not already set
3. **Wait for services** — poll Postgres, Kong, Auth, REST, Storage, and Realtime until all report healthy
4. **Apply migrations** — run SQL files from `supabase/migrations/` in the target repo (if present)
5. **Apply seeds** — run `supabase/seed.sql` from the target repo (if present)
6. **Create storage buckets** — create buckets defined in config or defaults (if any)
7. **Register edge functions** — mount functions from `supabase/functions/` (if present)
8. **Create harness fixtures** — optionally set up minimal test fixtures for baseline tests

Bootstrap is designed to be idempotent for repeated `docker compose up` runs.

---

## 6. Testing

### 6.1 Smoke Tests

Fast, curl-based checks that validate service availability:

- Frontend responds with HTTP 200
- REST API responds at `/rest/v1/`
- Auth route is reachable at `/auth/v1/health`
- Storage route is reachable at `/storage/v1/`
- Functions route is reachable (or built-in smoke function responds)
- Realtime endpoint is alive

### 6.2 Playwright Baseline Tests

Built-in browser-based tests that validate the baseline environment:

- App page loads without errors
- No obvious startup failures (console errors, blank screens)
- Environment connectivity (frontend can reach the API)
- Auth flow: sign-up / sign-in with email/password via MailHog
- Storage: upload and download baseline verification
- Functions: invoke a smoke function
- Realtime: verify WebSocket connectivity

These tests are **generic** — they do not assume app-specific selectors or business logic. Target repos can add their own Playwright tests on top.

---

## 7. Configuration

### 7.1 Environment Variables

Primary configuration is through `.env` (copied from `.env.example`). Key variables:

- `TARGET_APP_PATH` — path to the exported Lovable app on the host
- `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT`
- `JWT_SECRET`, `ANON_KEY`, `SERVICE_ROLE_KEY`
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_PROJECT_ID`
- `FRONTEND_PORT`, `SITE_URL`
- MailHog and Auth SMTP settings

### 7.2 Optional Config Override

Target repos may include a `lovable-local-cloud.config.json` file to override defaults:

```json
{
  "frontend": {
    "installCommand": "npm ci",
    "buildCommand": "npm run build",
    "outputDir": "dist"
  },
  "bootstrap": {
    "migrationsDir": "supabase/migrations",
    "seedFile": "supabase/seed.sql",
    "functionsDir": "supabase/functions",
    "storageBuckets": []
  }
}
```

If this file is not present, all defaults apply automatically.

---

## 8. License

This project is licensed under the [Apache License 2.0](../LICENSE).
