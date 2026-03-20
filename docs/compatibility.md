# Compatibility

This document describes what **lovable-local-cloud** expects from a target app and what limitations apply.

---

## Expected App Structure

lovable-local-cloud is designed to work with web apps exported from [Lovable](https://lovable.dev). A compatible app should have:

### Required

- **`package.json`** at the repository root
- **Vite-based frontend** (standard Lovable export)
- **Standard npm install/build flow** (`npm ci` + `npm run build`)
- **Static build output** in `dist/` (or a configured alternative)

### Frontend Environment Variables

The app must read its Supabase configuration from Vite environment variables:

| Variable                          | Description                              | Default Value              |
|-----------------------------------|------------------------------------------|----------------------------|
| `VITE_SUPABASE_URL`              | URL of the Supabase-compatible API       | `http://localhost:54321`   |
| `VITE_SUPABASE_PUBLISHABLE_KEY`  | Anonymous (public) Supabase key          | Local dev anon key         |
| `VITE_SUPABASE_PROJECT_ID`       | Project identifier                       | `local`                    |

These are injected at build time by the frontend Docker stage and baked into the Vite bundle.

### Optional

- **`supabase/migrations/`** — SQL migration files applied during bootstrap (sorted by filename)
- **`supabase/seed.sql`** — Seed data applied after migrations
- **`supabase/functions/`** — Deno-based edge functions mounted into the functions runtime
- **`lovable-local-cloud.config.json`** — Override file for build/bootstrap defaults (see below)

---

## Config Override File

If your app needs non-default build commands or paths, place a `lovable-local-cloud.config.json` in the root of your target repo:

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
    "storageBuckets": ["avatars", "documents"]
  }
}
```

All fields are optional. If the file is absent, all defaults apply automatically.

### Supported Overrides

| Field                         | Default                  | Description                            |
|-------------------------------|--------------------------|----------------------------------------|
| `frontend.installCommand`    | `npm ci`                 | Command to install dependencies        |
| `frontend.buildCommand`      | `npm run build`          | Command to build the frontend          |
| `frontend.outputDir`         | `dist`                   | Directory containing build output      |
| `bootstrap.migrationsDir`    | `supabase/migrations`    | Directory containing SQL migrations    |
| `bootstrap.seedFile`         | `supabase/seed.sql`      | Path to seed SQL file                  |
| `bootstrap.functionsDir`     | `supabase/functions`     | Directory containing edge functions    |
| `bootstrap.storageBuckets`   | `[]`                     | List of storage buckets to create      |

---

## Known Limitations

### General

- This is a **local development and testing tool**, not production infrastructure
- The local Supabase stack is compatible but not identical to the managed Supabase platform
- Performance characteristics differ from cloud environments
- Not all Supabase extensions or features may be available locally

### Auth

- **Email/password auth** works in local mode with MailHog capturing emails
- Auth emails (confirmation, password reset) are delivered to MailHog, not real inboxes
- `SITE_URL` must point to `http://localhost:3000` for auth redirects to work

### Database

- PostgreSQL runs as a single local instance — no read replicas, no connection pooling
- Extensions available depend on the Docker image used
- Database state persists in a Docker volume; use `docker compose down -v` to fully reset

### Storage

- Storage uses the local filesystem backend (not S3)
- File size limit defaults to 50 MB
- Storage data persists in a Docker volume

### Edge Functions

- Functions run in a Deno-based runtime compatible with Supabase Edge Functions
- If no functions exist in the target repo, the functions service still starts (with a built-in smoke function)
- Complex function dependencies or secrets may require additional configuration

### Realtime

- Realtime is included and active from v0
- Basic channel subscriptions work; advanced features may have differences from managed Supabase

---

## What is NOT Supported

The following are explicitly **out of scope** for lovable-local-cloud v0:

| Feature                    | Status      | Notes                                        |
|----------------------------|-------------|----------------------------------------------|
| **OAuth providers**        | Not in v0   | May be added in a future version             |
| **Supabase Studio**        | Not included| Use direct SQL or REST for database access   |
| **Analytics**              | Not included| Not part of the default stack                |
| **Lovable Editor**         | N/A         | This is not a Lovable platform emulator      |
| **Production deployment**  | N/A         | This is a local testing harness only         |
| **CI/CD workflows**        | Not in v0   | GitHub Actions integration is a future goal  |
| **GHCR image publication** | Not in v0   | Images are built locally                     |
| **Custom domains / HTTPS** | Not in v0   | All services run on localhost over HTTP       |
| **Connection pooling**     | Not in v0   | Single Postgres instance, direct connections  |
