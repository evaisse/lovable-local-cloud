# lovable-local-cloud

A local-first, Docker Compose-based fullstack testing harness for web apps exported from [Lovable](https://lovable.dev).

> **Important:** This is **not** an official Lovable product. It is **not** a Lovable Cloud replacement, and it is **not** production hosting infrastructure. It is a community tool for local E2E testing of exported Lovable apps.

## What It Does

- Serves your exported Lovable app via a local static frontend server
- Provides a Supabase-compatible backend (Postgres, Auth, REST, Storage, Realtime, Edge Functions)
- Captures auth emails locally via MailHog
- Bootstraps migrations, seeds, and storage buckets automatically
- Includes smoke tests and Playwright baseline tests

## Quick Start

### Prerequisites

- Docker & Docker Compose (v2.17+)
- An exported Lovable app on your local machine

### 1. Clone this repo

```bash
git clone https://github.com/evaisse/lovable-local-cloud.git
cd lovable-local-cloud
```

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env` and set `TARGET_APP_PATH` to point to your exported Lovable app:

```env
TARGET_APP_PATH=../my-lovable-app
```

### 3. Start the stack

```bash
docker compose up --build -d
```

### 4. Access your app

| Service | URL |
|---------|-----|
| Frontend | http://localhost:3000 |
| API Gateway (Supabase) | http://localhost:54321 |
| MailHog UI | http://localhost:8025 |
| Postgres | localhost:54322 |

### 5. Run smoke tests

```bash
./scripts/smoke-test.sh
```

### 6. Run Playwright baseline tests

```bash
cd tests
npm install
npx playwright install chromium
npx playwright test
```

## How It Works

1. **Frontend** — Your Lovable app is built using Node 22 with Vite env vars pointing to the local Supabase-compatible backend, then served via nginx with SPA fallback.

2. **Backend** — A full Supabase-compatible stack runs locally: Postgres, GoTrue (Auth), PostgREST (REST API), Supabase Realtime, Storage API, and Edge Functions runtime.

3. **API Gateway** — Kong routes all API requests through a single gateway at port 54321, matching the standard Supabase URL pattern.

4. **Bootstrap** — An init container automatically sets up database roles/schemas, applies migrations and seeds from your app, and creates storage buckets.

5. **Email** — MailHog captures all auth emails locally so you can test signup/confirmation flows without a real SMTP server.

## Configuration

### Environment Variables

See `.env.example` for all available variables with descriptions.

Key variables:
- `TARGET_APP_PATH` — Path to your exported Lovable app
- `VITE_SUPABASE_URL` — Injected into the frontend build (defaults to `http://localhost:54321`)
- `VITE_SUPABASE_PUBLISHABLE_KEY` — The anonymous key for the frontend

### Optional Config File

Place a `lovable-local-cloud.config.json` in your target app repo to customize behavior:

```json
{
  "frontend": {
    "installCommand": "npm ci",
    "buildCommand": "npm run build",
    "outputDir": "dist"
  },
  "bootstrap": {
    "storageBuckets": ["avatars", "uploads"]
  }
}
```

See `examples/lovable-local-cloud.config.json` for a full example.

## Resetting

To completely reset the stack (removes all data):

```bash
./scripts/reset.sh
```

Or manually:

```bash
docker compose down -v --remove-orphans
docker compose up --build -d
```

## Testing

### Smoke Tests

Quick HTTP health checks for all services:

```bash
./scripts/smoke-test.sh
```

### Playwright Baseline Tests

Built-in tests that validate the environment without assuming app-specific selectors:

```bash
cd tests
npm install
npx playwright install chromium
npx playwright test
```

Tests verify:
- Frontend loads successfully
- SPA deep links work
- REST API responds
- Auth signup works
- Auth emails arrive in MailHog
- Storage upload/download works
- Edge Functions execute
- Realtime is reachable

## Compatibility

This harness assumes your exported Lovable app follows standard conventions:

- Vite-based frontend with `package.json`
- Standard `npm ci` / `npm run build` flow
- Output in `dist/`
- Uses `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` env vars

See `docs/compatibility.md` for full details.

## Known Limitations

- OAuth providers are not supported in v0
- Supabase Studio is not included in the default stack
- Edge Functions use a simplified routing model
- Not all Supabase features may have full parity
- Local dev secrets are not production-safe

## Architecture

See `docs/architecture.md` for a detailed architecture overview.

## License

Apache-2.0 — see [LICENSE](LICENSE)

---

*This is a community project for local testing. It is not affiliated with or endorsed by Lovable.*
