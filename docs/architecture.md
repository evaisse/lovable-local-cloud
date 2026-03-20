# Architecture

This document describes the architecture of the **lovable-local-cloud** Docker Compose stack.

---

## Stack Overview

```
┌─────────────────────────────────────────────────────────────┐
│                       Host Machine                          │
│                                                             │
│   TARGET_APP_PATH ──► mounted into frontend build stage     │
│                                                             │
│   Browser ──► http://localhost:3000  (frontend / nginx)     │
│           ──► http://localhost:54321 (API gateway / Kong)   │
│           ──► http://localhost:8025  (MailHog UI)            │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Stack                      │
│                                                             │
│  ┌──────────┐    ┌──────────────────────────────────────┐   │
│  │ frontend │    │              kong (API Gateway)       │   │
│  │  :3000   │    │               :54321                  │   │
│  │  nginx   │    │  ┌──────┐ ┌──────┐ ┌─────────┐       │   │
│  └──────────┘    │  │ auth │ │ rest │ │ storage │       │   │
│                  │  └──┬───┘ └──┬───┘ └────┬────┘       │   │
│                  │     │        │          │             │   │
│                  └─────┼────────┼──────────┼─────────────┘   │
│                        │        │          │                 │
│                  ┌─────▼────────▼──────────▼─────┐          │
│                  │        db (PostgreSQL)         │          │
│                  │           :54322               │          │
│                  └───────────────────────────────-┘          │
│                                                             │
│  ┌───────────┐  ┌────────────┐  ┌──────────────────────┐   │
│  │ realtime  │  │ functions  │  │      mailhog          │   │
│  │  :4000    │  │  (Deno)    │  │  UI :8025 SMTP :1025  │   │
│  └───────────┘  └────────────┘  └──────────────────────┘   │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    init (bootstrap)                    │  │
│  │  migrations → seeds → buckets → readiness checks      │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Service Dependency Graph

```
init ──► db ──► rest
              ──► auth ──► mailhog
              ──► storage
              ──► realtime
         kong ──► auth
              ──► rest
              ──► storage
              ──► realtime
              ──► functions
frontend (independent build, connects to kong at runtime)
```

### Startup Order

1. **db** — PostgreSQL must be healthy before anything else
2. **kong** — API gateway starts once db is available
3. **auth, rest, storage, realtime, functions** — backend services start once db and kong are ready
4. **mailhog** — starts independently (no dependencies)
5. **frontend** — builds the target app and starts nginx (independent of backend readiness)
6. **init** — runs last, waits for all services, then applies migrations/seeds/buckets

---

## Port Mappings

| Service      | Container Port | Host Port | Protocol |
|--------------|---------------|-----------|----------|
| frontend     | 80            | 3000      | HTTP     |
| kong         | 8000          | 54321     | HTTP     |
| db           | 5432          | 54322     | TCP      |
| mailhog UI   | 8025          | 8025      | HTTP     |
| mailhog SMTP | 1025          | 1025      | SMTP     |
| realtime     | 4000          | 4000      | WS/HTTP  |

All ports bind to `localhost` by default for security.

---

## Volume Strategy

| Volume              | Purpose                                    | Persistence  |
|---------------------|--------------------------------------------|--------------|
| `db-data`           | PostgreSQL data directory                  | Persistent   |
| `storage-data`      | Supabase Storage files                     | Persistent   |
| `TARGET_APP_PATH`   | Mounted read-only into frontend build      | Host bind    |

Volumes survive `docker compose down`. To fully reset, use `docker compose down -v`.

---

## Bootstrap Flow

The `init` container executes in order:

```
1. Validate TARGET_APP_PATH
   └─ Check that /app exists and contains package.json

2. Generate secrets (if not set)
   └─ JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY

3. Wait for services
   ├─ Poll PostgreSQL (pg_isready)
   ├─ Poll Kong (/health)
   ├─ Poll Auth (/auth/v1/health)
   ├─ Poll REST (/rest/v1/)
   ├─ Poll Storage (/storage/v1/)
   └─ Poll Realtime (WebSocket or HTTP health)

4. Apply migrations
   └─ Run supabase/migrations/*.sql against db (if present)

5. Apply seeds
   └─ Run supabase/seed.sql against db (if present)

6. Create storage buckets
   └─ POST to Storage API for each configured bucket

7. Register edge functions
   └─ Mount supabase/functions/ into the functions runtime

8. Create harness fixtures (optional)
   └─ Minimal test data for baseline Playwright tests
```

---

## Testing Layers

### Smoke Tests

Fast, non-browser checks using `curl`:

- `GET http://localhost:3000` → 200
- `GET http://localhost:54321/rest/v1/` → 200
- `GET http://localhost:54321/auth/v1/health` → 200
- `GET http://localhost:54321/storage/v1/` → 200
- `GET http://localhost:54321/functions/v1/smoke` → 200
- Realtime health check

### Playwright Baseline Tests

Browser-based tests that verify:

- Page loads and renders
- No console errors on startup
- Frontend can reach the API gateway
- Auth sign-up/sign-in flow works with MailHog
- Storage upload/download works
- Edge function invocation works
- Realtime WebSocket connects

---

## Frontend ↔ Backend Connectivity

The frontend connects to the backend exclusively through environment variables injected at build time:

```
VITE_SUPABASE_URL=http://localhost:54321
VITE_SUPABASE_PUBLISHABLE_KEY=<anon-key>
VITE_SUPABASE_PROJECT_ID=local
```

At runtime in the browser:

1. The app's Supabase client reads `VITE_SUPABASE_URL` (baked into the JS bundle by Vite)
2. All API calls go to `http://localhost:54321` (Kong)
3. Kong routes requests to the appropriate backend service:
   - `/auth/v1/*` → Auth (GoTrue)
   - `/rest/v1/*` → REST (PostgREST)
   - `/storage/v1/*` → Storage
   - `/realtime/v1/*` → Realtime
   - `/functions/v1/*` → Edge Functions

The `VITE_SUPABASE_PUBLISHABLE_KEY` (anon key) is safe for frontend use — it only grants anonymous-level access. The `SERVICE_ROLE_KEY` is never exposed to the frontend.
