# Master Prompt: Implement `lovable-local-cloud`

Use this prompt as the direct handoff input for another AI coding agent.

---

You are a senior software engineer and infrastructure-focused coding agent. Your task is to implement the first working version of a project named `lovable-local-cloud`.

You must treat the following as the source of truth:

- `docs/lovable-local-cloud-spec.md`

Your output must be a real implementation, not another plan.

## 1. Mission

Build a local-first, Docker Compose-based fullstack testing harness for web apps exported from Lovable.

This project is **not** an attempt to self-host Lovable itself.

It **is** a reproducible local environment that provides:

- a static frontend server for an exported Lovable app
- a self-hosted Supabase-compatible backend
- local email capture via MailHog
- deterministic bootstrap for migrations, seeds, buckets, and readiness
- built-in smoke checks
- built-in Playwright baseline tests

The goal is to make local E2E testing effective and repeatable for exported Lovable apps with minimal or no app-specific refactoring.

## 2. Product Positioning Constraints

You must preserve the exact product framing:

- This is a `Lovable-compatible local testing harness`
- This is **not** an official Lovable product
- This is **not** a Lovable Cloud replacement
- This is **not** production hosting infrastructure
- This is **not** a guarantee of full parity with every managed Lovable feature

Use the wording from the spec consistently in docs and implementation choices.

## 3. Scope for This Implementation

Implement the first practical local v0 only.

### In scope

- Local Docker Compose stack
- Generic support for exported Lovable apps
- Frontend static serving
- Supabase-compatible backend services
- Realtime included from v0
- Email/password auth in local mode
- MailHog
- Bootstrap/init flow
- Smoke tests
- Built-in Playwright baseline tests
- Documentation and setup flow
- Apache-2.0 license

### Out of scope for now

- GitHub Actions workflows
- GHCR publication work
- Supabase Studio in the default stack
- Analytics in the default stack
- Production hardening
- Lovable editor/platform emulation
- OAuth if it slows down v0 materially

## 4. Non-Negotiable Technical Decisions

Unless implementation reality absolutely forces a change, follow these defaults:

1. Use `Docker Compose`, not Kubernetes.
2. Use official upstream Supabase images where practical.
3. Use `Node 22` for frontend builds.
4. Use a multi-stage frontend Docker build.
5. Serve the frontend with `nginx` or an equivalent static HTTP server with SPA fallback.
6. Use `Playwright` for browser tests.
7. Use `MailHog` for local email capture.
8. Use an optional JSON override file rather than requiring per-project configuration.
9. Keep Realtime active from v0.
10. Keep the stack local-first and generic.

## 5. Source of Truth Requirements

Before writing code, read and honor the complete contents of:

- `docs/lovable-local-cloud-spec.md`

You must implement the specification, not reinterpret it into a smaller toy version.

If you discover a contradiction or something impossible in the spec, choose the most conservative, least surprising implementation that preserves the product intent, and document the tradeoff.

## 6. Primary Goal

At the end of your work, a developer should be able to:

1. point the harness at a local exported Lovable repo
2. run `docker compose up --build -d`
3. access the app locally in a browser
4. have the app talking to a local Supabase-compatible backend
5. run smoke tests and built-in Playwright baseline tests

## 7. Compatibility Contract to Implement

Assume the target app follows typical Lovable export conventions:

- Vite frontend
- `package.json` exists
- standard install/build flow
- frontend env variables:
  - `VITE_SUPABASE_URL`
  - `VITE_SUPABASE_PUBLISHABLE_KEY`
  - `VITE_SUPABASE_PROJECT_ID`
- optional `supabase/migrations/`
- optional `supabase/functions/`

Also support an optional target-repo file named:

`lovable-local-cloud.config.json`

Use it to override default build/test paths or commands when needed.

## 8. Required Runtime Services

Your `docker-compose.yml` must include the services needed for v0 parity:

- `frontend`
- `db`
- `kong`
- `auth`
- `rest`
- `realtime`
- `storage`
- `functions`
- `mailhog`
- `init` or equivalent bootstrap container/script

Do not include `studio` or `analytics` by default.

## 9. Required Local URLs and Ports

Use sensible defaults aligned with the spec, unless there is a strong implementation reason not to:

- Frontend: `http://localhost:3000`
- API gateway: `http://localhost:54321`
- Postgres: `localhost:54322`
- MailHog UI: `http://localhost:8025`
- MailHog SMTP: `localhost:1025`

The implementation must clearly expose these in docs and env defaults.

## 10. Frontend Implementation Requirements

Implement a generic frontend runner that:

1. builds the target app using `Node 22`
2. defaults to `npm ci`
3. defaults to `npm run build`
4. defaults to `dist/` as output
5. injects:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
   - `VITE_SUPABASE_PROJECT_ID`
6. serves the output over HTTP
7. supports SPA fallback for deep links
8. does not assume framework-specific behavior beyond the Vite/static contract

The implementation should be generic enough for exported Lovable repos without major modifications.

## 11. Backend Implementation Requirements

Implement a Supabase-compatible local stack that supports:

- Postgres
- Auth
- REST
- Storage
- Realtime
- Edge Functions

Use upstream-compatible conventions and avoid inventing fake replacements when the real service can be run reasonably.

## 12. Bootstrap Requirements

Implement a deterministic bootstrap layer that:

1. validates `TARGET_APP_PATH`
2. generates local development secrets if missing
3. waits for core services to be ready
4. applies migrations from the target repo if present
5. applies seeds if present
6. creates storage buckets if needed
7. mounts or registers edge functions if present
8. optionally creates minimal harness-owned fixtures for baseline tests
9. fails loudly with actionable logs

Bootstrap should be idempotent enough for repeated local runs.

## 13. Secrets and Safety Rules

Follow these rules strictly:

1. Do not expose `SERVICE_ROLE_KEY` to the frontend.
2. Generate local dev secrets only.
3. Make it clear in docs that secrets are not production-safe.
4. Keep local env and generated secrets git-ignored.
5. Prefer binding exposed ports to localhost when practical.

## 14. Realtime Requirements

Realtime is required in v0.

You must:

- include the service in the default stack
- include it in readiness checks
- include at least one baseline verification that proves it is alive and usable

If fully realistic app-level realtime assertions are hard generically, use a harness-owned smoke path that still proves the service works.

## 15. Edge Functions Requirements

Support functions from the target app if present.

Rules:

1. If `supabase/functions/` exists, wire it into the functions runtime.
2. If no functions exist, the stack must still boot.
3. If needed, include one built-in smoke function so the functions runtime can still be verified.

## 16. Storage Requirements

You must support:

1. bucket creation during bootstrap
2. upload/download baseline verification
3. persistent local storage volume

If needed, create a harness-owned smoke bucket such as `llc-smoke`.

## 17. Email/Auth Requirements

In v0, email/password auth must work locally.

Requirements:

- Auth must route through Kong
- Auth emails must go to MailHog
- `SITE_URL` must point to the local frontend URL
- MailHog UI must be usable for debugging

OAuth is optional and may be omitted if it would slow down the first working version.

## 18. Testing Requirements

You must implement two testing layers.

### A. Smoke tests

Provide a fast smoke layer that checks at least:

- frontend responds
- REST responds
- auth route is reachable
- storage route is reachable
- functions route is reachable or smoke function works
- realtime readiness works

### B. Playwright baseline tests

Provide built-in Playwright tests that validate the baseline environment.

Important constraint:
Do **not** assume arbitrary app-specific selectors or business flows for every Lovable app.

The built-in baseline suite should focus on:

- app page load
- no obvious startup failure
- environment connectivity
- at least one auth/storage/functions/realtime validation path where feasible

The implementation should also be structured so target-repo Playwright tests can be added later or optionally invoked.

## 19. Required Deliverables

Produce at least the following artifacts in the new project:

- `README.md`
- `LICENSE`
- `docker-compose.yml`
- `.env.example`
- frontend Docker assets
- bootstrap scripts
- smoke test scripts
- Playwright config and baseline specs
- `docs/architecture.md`
- `docs/compatibility.md`
- optional example `lovable-local-cloud.config.json`

## 20. Documentation Requirements

Your docs must clearly explain:

1. what the project is
2. what it is not
3. how to point it to a target app
4. how to boot it locally
5. how to reset it
6. what compatibility assumptions exist
7. what known limitations exist
8. how smoke tests and Playwright work

Keep all documentation and code comments in English.

## 21. Acceptance Criteria

The implementation is only acceptable if all of the following are true:

1. A target exported Lovable repo can be referenced through `TARGET_APP_PATH`.
2. `docker compose up --build -d` starts the stack locally.
3. The frontend is reachable.
4. The local Supabase-compatible API is reachable.
5. Email/password auth works in local mode.
6. MailHog captures auth mail.
7. Migrations are applied automatically when present.
8. Storage upload/download baseline passes.
9. Realtime is enabled and baseline verification passes.
10. At least one edge function path works.
11. Built-in Playwright baseline tests run successfully.
12. Setup/reset/troubleshooting are documented.

## 22. Recommended Build Order

Implement in this order unless you have a strong reason not to:

1. repo skeleton and docs
2. `.env.example` and config model
3. compose stack with backend services
4. frontend builder/server
5. bootstrap/init flow
6. readiness scripts
7. smoke tests
8. Playwright baseline tests
9. polish docs and reset flow

## 23. Things You Must Avoid

Do not:

1. build a fake monolithic "Lovable Cloud" container
2. add Studio and analytics in v0
3. overcomplicate configuration before zero-config mode works
4. claim production readiness
5. rely on arbitrary product-specific selectors for the built-in baseline suite
6. expose secrets carelessly

## 24. Expected Quality Bar

The project should feel like a clean OSS starter for local testing, not a rough prototype.

That means:

- readable structure
- explicit scripts
- clear env handling
- understandable logs
- minimal but useful docs
- realistic defaults
- small, focused implementation pieces

## 25. Deliverable Format

When you complete the implementation, provide:

1. a short explanation of what you built
2. a file-by-file change summary
3. the commands you used to validate it
4. known limitations
5. suggested next steps

Do not return another plan unless blocked by a hard technical contradiction.

## 26. Final Reminder

You are implementing a **generic local test harness for exported Lovable apps**.
The project succeeds if it gives developers and future agents a concrete, reproducible local environment for strong baseline E2E validation.

Start from the spec, implement the repo, and optimize for clarity, reproducibility, and local operability.

---

## Suggested Companion Context for the Implementing Agent

Also provide this short note alongside the prompt if useful:

- Main spec: `docs/lovable-local-cloud-spec.md`
- Product name: `lovable-local-cloud`
- License: `Apache-2.0`
- v0 focus: local-only, generic exported Lovable apps, Docker Compose, Supabase-compatible backend, MailHog, smoke tests, Playwright baseline tests
- Explicit exclusions: GitHub workflow, GHCR publication, Studio, analytics, production deployment
