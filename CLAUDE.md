# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`phoenix-vue-template` is a personal starter template for the owner's go-to stack: **Phoenix 1.8 + Vue 3 + Postgres + Oban**. The intent is to clone this repo from GitHub and immediately begin shipping a new project without re-doing the same wiring every time.

**Current state:** Phoenix 1.8.5 + LiveView 1.1 + Bandit + Postgres + Oban (OSS 2.22) + Vue 3 SPA (Vite 8 + Tailwind v4 + Meldui + OXC). Static analysis (Credo + Dialyzer) wired into `mix precommit`. The Phoenix-side esbuild/tailwind pipeline has been removed — Vite owns all asset compilation, builds into `priv/static/assets/`.


## Template Goal

The template captures the wiring I reach for on every new Phoenix project so I can stop rebuilding the same plumbing. When adding a major piece (Vue SPA, Oban, auth, query modules, two-release topology, storage façade, etc.), **prefer mirroring proven patterns from existing production code over inventing new ones** — this template exists to make those patterns reusable.

## Current State vs. Template Goal

| Area | Status | Notes |
|---|---|---|
| Phoenix 1.8 + LiveView 1.1 + Bandit + Postgres + Req + Swoosh | ✓ in place | — |
| Vue 3 SPA (Vite 8 + Tailwind v4 + Meldui + OXC + Pinia + Vue Router 5) | ✓ in place | Vite-served in dev on `:4001` (HMR `:4002`), digested into `priv/static/assets/` in prod. `root.html.heex` injects `<script>` tags conditionally on `Application.get_env(:phoenix_vue_template, :vite_dev_server)`. SPA catch-all route is declared LAST. CSRF token in `<meta name="csrf-token">`, read by `frontend/src/lib/csrf.ts`. Meldui (Reka-UI based) is the component substrate; Tabler icons via `@meldui/tabler-vue`; Geist + Bricolage Grotesque fonts via `@fontsource-variable/*`. |
| Oban (OSS 2.22) | ✓ in place | Two-release topology in `config/runtime.exs`: `phoenix_vue_template_server` runs `default`/`mailer` queues + Pruner + Cron; `phoenix_vue_template_processors` runs heavy queues + Pruner only. Tests use `testing: :inline`. |
| Credo (`--strict`) + Dialyzer | ✓ in place | Comprehensive `.credo.exs` check list. Dialyzer PLT stored at `priv/plts/` (gitignored). Both run as part of `mix precommit`. |
| Authentication | ⚡ generator | `mix phoenix_vue.gen.auth --mode {single\|multi}` lands the full stack (User / PasswordCredential / Session / Organization / Member, migrations, three-module split, JSON controllers, Argon2id hasher, session-fixation defense, opaque DB-backed cookie tokens, CSRF wiring, Vue SPA login/register/forgot/verify/onboarding views, Pinia auth store). One-shot — see the **Generators** section below. |
| Query modules | ✓ convention | Established by the auth generator's output: every schema `lib/.../<thing>.ex` gets a sibling `<thing>_queries.ex`; schemas never call `Repo`. Follow the same pattern when adding your own schemas. |
| OAuth, SAML, 2FA, audit log, storage façade, fine-grained RBAC | ✗ | Add as features land; mirror established conventions and `mix phoenix_vue.gen.auth`'s structure. |

## Essential Commands

All from `mix.exs` aliases:

```
mix setup                              # deps.get + ecto.setup + assets.setup + assets.build
mix phx.server                         # dev server on :4000 with live reload + watchers
iex -S mix phx.server                  # same, with IEx shell attached
mix test                               # auto-creates test DB, runs ExUnit
mix test test/path/to/file_test.exs:42 # single test by file + line
mix test --failed                      # rerun last failures
mix ecto.reset                         # drop + create + migrate + seed
mix assets.build                       # cmd --cd frontend pnpm vite build
mix assets.deploy                      # vite build --mode production + phx.digest
mix credo --strict                     # static analysis (.credo.exs)
mix dialyzer                           # type analysis (PLT cached in priv/plts/)
mix precommit                          # compile --warnings-as-errors + deps.unlock --unused + format + credo --strict + dialyzer + test
```

Run `mix precommit` before every commit (also called out in `AGENTS.md`).

## Architecture Notes (current scaffold)

- `lib/phoenix_vue_template/` — business logic root: `application.ex`, `repo.ex`, `mailer.ex`. New contexts (`PhoenixVue.Accounts`, etc.) go here.
- `lib/phoenix_vue_template_web/` — web layer: `endpoint.ex`, `router.ex`, `telemetry.ex`, `components/`, `controllers/`, `gettext.ex`, `plugs/`. `PageController.home` renders the SPA shell; the catch-all `GET /*path` route at the bottom of `router.ex` sends every browser path through it so vue-router survives deep-link refreshes. `Plugs.AssignRequestHost` resolves the safe `@request_host` for the dev Vite URL.
- `frontend/` — Vue 3 SPA bundled by Vite; full layout + conventions in the [**Frontend (Vue 3 SPA)**](#frontend-vue-3-spa) section below. `phoenix` npm + `@types/phoenix` are pre-installed so Channels are one UserSocket + endpoint route away when needed.
- `priv/static/assets/` — Vite build output. Gitignored; populated by `mix assets.build` / `mix assets.deploy`. **No `assets/` directory** on the Phoenix side — Vite owns all CSS/JS.
- `priv/repo/migrations/` — Oban schema landed in the initial `add_oban` migration. Application migrations go here.
- Dev DB: `phoenix_vue_template_dev` (Postgres, default `postgres`/`postgres` from `config/dev.exs`).
- HTTP server: Bandit (`Bandit.PhoenixAdapter` in `config/config.exs`).

## Frontend (Vue 3 SPA)

### Layout

```
frontend/
├── index.html               SPA shell — <title> + <div id="app">
├── package.json             pnpm; engines node ^20.19 || >=22.12
├── pnpm-lock.yaml
├── env.d.ts                 /// <reference types="vite/client" />
├── vite.config.ts           dev :4001, HMR :4002, outDir → ../priv/static
├── vite-dev.mjs             dev wrapper that exits when Phoenix closes stdin
├── tsconfig.json            workspace references → app + node
├── tsconfig.app.json        DOM + Vue, paths { "@/*": ["./src/*"] }
├── tsconfig.node.json       vite.config / eslint.config type-checking
├── eslint.config.ts         flat config; vue-essential + oxlint
├── .oxlintrc.json / .oxfmtrc.json
├── .editorconfig / .gitattributes / .gitignore
└── src/
    ├── main.ts              createApp + pinia + router; mounts #app
    ├── App.vue              <RouterView /> + <Toaster /> (meldui)
    ├── assets/
    │   └── main.css         tailwindcss + tw-animate-css + meldui theme
    │                        + Geist/Bricolage fonts + Tailwind @source paths
    ├── router/
    │   └── index.ts         createWebHistory; home + 404 catch-all
    ├── views/               page components mapped from the router
    │   ├── HomeView.vue
    │   └── NotFoundView.vue
    └── lib/                 framework-agnostic helpers
        └── csrf.ts          read <meta name="csrf-token">
```

### Where new code goes

- `src/views/` — top-level page components mapped from `src/router/index.ts`. One file per route, PascalCase, suffix `View.vue`.
- `src/components/` — reusable UI not bound to a route. Create when the same fragment renders in ≥ 2 views.
- `src/composables/` — Vue composition functions (`useFoo`); one concern per file, export a single `use*`.
- `src/stores/` — Pinia stores (`defineStore`). State that outlives a single view (auth, current org, etc.).
- `src/lib/` — framework-agnostic TS helpers (CSRF, API client, formatters, time, hash).
- `src/types/` — shared TS types / Zod schemas.
- `src/assets/` — global CSS only. Per-component CSS belongs in the `.vue` `<style>` block.
- Use the `@` alias for cross-directory imports: `import { getCsrfToken } from '@/lib/csrf'`.

### Commands (from `frontend/`)

```
pnpm dev          # standalone vite — rarely needed; mix phx.server runs it
pnpm build        # type-check + production bundle into ../priv/static
pnpm preview      # serve the production bundle locally
pnpm type-check   # vue-tsc --build (incremental; cached in node_modules/.tmp)
pnpm lint         # oxlint --fix → eslint --fix --cache
pnpm format       # oxfmt src/
```

### HMR flow

`mix phx.server` spawns `node vite-dev.mjs` via the Phoenix watcher in `config/dev.exs`. Vite serves modules from `:4001`; `root.html.heex` injects `<script src="//{request_host}:4001/src/main.ts">` so the browser pulls everything live. Edits to `.vue`, `.ts`, or `.css` files HMR without a full reload. `.heex` / router changes still trigger a Phoenix `live_reload`.

## Background jobs (Oban)

Oban runs in a two-release topology — queues split by `RELEASE_NAME` in `config/runtime.exs`:

- `phoenix_vue_template_server` (web) — `default` + `mailer` queues; hosts Pruner + Cron plugins.
- `phoenix_vue_template_processors` — heavy queues you add as features land (e.g. `documents`, `embeddings`); Pruner only.
- Dev / iex / test (no `RELEASE_NAME`) — all queues run on one node.

Workers go under `lib/phoenix_vue_template/<context>/workers/`. Pattern:

```elixir
defmodule PhoenixVue.Some.Workers.MyWorker do
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}), do: :ok
end
```

Tests use `config :phoenix_vue_template, Oban, testing: :inline` (jobs run synchronously on enqueue, so assertions can observe their effects without polling).

## Dev flow

`mix phx.server` starts Phoenix on `:4000` and (via the `watchers:` config in `config/dev.exs`) spawns `node frontend/vite-dev.mjs`, which runs the Vite dev server on `:4001`. The root layout injects `<script src="//{request_host}:4001/@vite/client">` + `<script src="//{request_host}:4001/src/main.ts">` so the browser pulls modules directly from Vite — full HMR for `.vue` / `.ts` / `.css` edits. The Phoenix `live_reload` config still triggers full page reloads when `.heex` / router files change.

For prod (`MIX_ENV=prod mix assets.deploy`), Vite builds into `priv/static/assets/main.js` + `main.css`, then `mix phx.digest` cache-busts. The `:vite_dev_server` env var is unset in prod, so `root.html.heex` falls back to the digested `~p"/assets/main.{js,css}"` links.

**First-run gotcha:** after a fresh clone, run `mix setup` (not `mix phx.server` directly) so `cd frontend && pnpm install` happens first. Otherwise the `node` watcher tries to import `vite` from a non-existent `node_modules/`. (`materialize.sh` runs `mix assets.setup` for you, so this only bites on subsequent clones.)

## Framework Rules — see AGENTS.md

`AGENTS.md` is the source of truth for Phoenix 1.8 / LiveView / Ecto / HEEx / Elixir / forms / streams / test conventions. **Read it before writing code.** Do not duplicate its rules here. High-level reminders that come up constantly:

- **HTTP client is `Req` only** — never HTTPoison / Tesla / httpc.
- **Tailwind v4 lives on the Vue side** — `frontend/src/assets/main.css` is canonical (no `tailwind.config.js`, no Phoenix-side asset pipeline).
- **Use Meldui for SPA UI** — `import { Button, ... } from '@meldui/vue'` and `@meldui/tabler-vue` for icons. Don't reintroduce daisyUI.
- **Forms always via `Phoenix.Component.to_form/2`**; never pass a changeset directly to `<.form for=...>`.
- **No `live_redirect` / `live_patch`** — use `<.link navigate>` / `push_navigate`.
- **No `String.to_atom/1` on user input** (memory leak).
- **No `Phoenix.View`** (removed).

## Commit message conventions

- **Never add `Co-Authored-By: Claude ...` trailers** to commit messages. Author the commit normally; no AI attribution.

## Generators

The template ships single-shot `mix` generators under `lib/mix/tasks/` that drop pre-wired stacks into the materialized app. Templates live in `priv/templates/<generator>/`. Each generator runs once on a fresh app, refuses to run if its output already exists, and resolves the target app's OTP atom / base module / web module / repo / mailer at run time (via `Mix.Project.config` + `Mix.Phoenix.{base,web_module}/0,1`) so the templates work regardless of what name `materialize.sh` gave the project.

### `mix phoenix_vue.gen.auth --mode {single|multi}`

Lands the full authentication stack — DB schemas + migrations, Accounts / Organizations / Auth contexts, JSON `/api/*` controllers (registration, sessions, me, password reset, email verification, organizations, switch-organization), HttpOnly auth cookie + CSRF wiring, Argon2id password hashing with PHC param-upgrade rehash detection, session-sweeper Oban cron, Swoosh mailer with Oban delivery worker (tokens never sit in `oban_jobs.args`), Vue SPA pages (Login / Register / RegisterSent / ForgotPassword / ForgotPasswordSent / ResetPassword / VerifyEmail / CreateOrganization onboarding), `AuthLayout` + `OnboardingLayout`, Pinia `auth` store, `fetch`-based `api.ts` wrapper with CSRF retry, router guards. Ships `OrganizationSwitcher.vue` and the switch endpoint as a tested component but does not mount the switcher in any layout — drop it into your app chrome when ready.

**Modes**

| `--mode` | Behavior |
|---|---|
| `multi` (default) | Users can belong to N organizations. Fresh signup → `/onboarding/create-organization`. |
| `single` | Users belong to exactly one organization, auto-created at signup. DB-level partial unique index enforces it. Onboarding screen still exists but the router auto-skips it. |

Flipping `single` → `multi` later is one constant change in `frontend/src/lib/auth-mode.ts` plus an Ecto migration that drops the `members_single_tenant_user_id_index`.

**Two-cookie design** (mirrored from doqo-server)
- `_<app>_auth` — opaque random 32-byte token; SHA-256 hashed at rest in `sessions`. HttpOnly, `Secure` in prod, `SameSite=Lax`. Set directly via `Plug.Conn.put_resp_cookie/4` — never flows through `Plug.Session`.
- `_<app>_key` (the stock `Plug.Session` cookie) — *only* carries the CSRF token. The SPA reads it from `<meta name="csrf-token">` and sends `X-CSRF-Token` on every mutating XHR.

**Not generated** (deliberate scope cuts — add later as separate generators or by hand):
- OAuth providers (Identity schema, `mix phoenix_vue.gen.oauth` is a future task)
- Invite UI (the `invite_token_hash` columns + `Member.invitation_changeset/2` / `claim_changeset/2` ship — wire a controller + view when you need them)
- Rate limiting (no Hammer; the auth endpoints lean on Argon2 lockout for the most-abused path)
- App chrome (NavRail, UserProfileMenu, SecurityView, Members list) — apps wire their own
- 2FA, WebAuthn, magic links, audit log

**Re-running** is intentionally blocked: the task refuses if `<Base>.Accounts` already compiles or if anchor markers are missing in the in-place files. Delete the generated modules first if you really want to regenerate.

## When Extending the Template

Before adding a new architectural piece (OAuth, storage, query modules, etc.):

1. Prefer mirroring battle-tested implementations from prior production code over inventing new structure. If the user references a specific reference codebase, read the relevant files there first.
2. Mirror module naming (`Accounts` / `Organizations` / `Auth` split), error tuples (`{:ok, _} | {:error, _}`, never `!` bangs in app code), the query-module split (`<thing>.ex` schema + sibling `<thing>_queries.ex`; schemas never call `Repo`), and façade modules for external systems (storage, search, LLM, etc.).
3. If the piece is the kind of thing a fresh project needs every time, **make it a generator** under `lib/mix/tasks/phoenix_vue.gen.<thing>.ex` + `priv/templates/phoenix_vue.gen.<thing>/`. Mirror the `gen.auth` task's structure: assigns resolution, preflight, EEx walk with `__app__` / `__nowN__` path tokens, anchored in-place patches, `mix format` after.
4. Update this CLAUDE.md to add the new generator to the **Generators** section and flip the corresponding row in the "Current State vs. Template Goal" table to ✓ or ⚡ once the piece lands.
