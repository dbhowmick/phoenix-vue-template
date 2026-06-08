# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`phoenix-vue-template` is a personal starter template for the owner's go-to stack: **Phoenix 1.8 + Vue 3 + Postgres + Oban**. The intent is to clone this repo from GitHub and immediately begin shipping a new project without re-doing the same wiring every time.

**Current state:** Phoenix 1.8.5 + LiveView 1.1 + Bandit + Postgres + Oban (OSS 2.22) + Vue 3 SPA (Vite 8 + Tailwind v4 + Meldui + OXC). Static analysis (Credo + Dialyzer) wired into `mix precommit`. The Phoenix-side esbuild/tailwind pipeline has been removed — Vite owns all asset compilation, builds into `priv/static/assets/`.


## Template Goal & Reference Implementation

The canonical reference for what this template should grow into is `/Users/dipayan/work/doqo/doqo-workspace/doqo-server` — a mature production app on the exact same stack. When adding any major piece (Vue SPA, Oban, auth, query modules, two-release topology, storage façade, etc.), open `doqo-server/CLAUDE.md` and the relevant source files and **mirror the patterns** rather than inventing new ones. The user's preferences are codified there; this template exists to make them reusable.

## Current State vs. Template Goal

| Area | Status | Plan (mirror from doqo-server) |
|---|---|---|
| Phoenix 1.8 + LiveView 1.1 + Bandit + Postgres + Req + Swoosh | ✓ in place | — |
| Vue 3 SPA (Vite 8 + Tailwind v4 + Meldui + OXC + Pinia + Vue Router 5) | ✓ in place | Vite-served in dev on `:4001` (HMR `:4002`), digested into `priv/static/assets/` in prod. `root.html.heex` injects `<script>` tags conditionally on `Application.get_env(:phoenix_vue_template, :vite_dev_server)`. SPA catch-all route is declared LAST. CSRF token in `<meta name="csrf-token">`, read by `frontend/src/lib/csrf.ts`. Meldui (Reka-UI based) is the component substrate; Tabler icons via `@meldui/tabler-vue`; Geist + Bricolage Grotesque fonts via `@fontsource-variable/*`. |
| Oban (OSS 2.22) | ✓ in place | Two-release topology in `config/runtime.exs`: `phoenix_vue_template_server` runs `default`/`mailer` queues + Pruner + Cron; `phoenix_vue_template_processors` runs heavy queues + Pruner only. Tests use `testing: :inline`. |
| Credo (`--strict`) + Dialyzer | ✓ in place | `.credo.exs` mirrors doqo's check list. Dialyzer PLT stored at `priv/plts/` (gitignored). Both run as part of `mix precommit`. |
| Authentication | ✗ | Three-module split: `PhoenixVue.Accounts` (identity), `PhoenixVue.Organizations` (tenancy), `PhoenixVue.Auth` (plugs/tokens/mailers) |
| Query modules | ✗ | Every schema `lib/.../<thing>.ex` gets a sibling `<thing>_queries.ex`; schemas never call `Repo` |
| Migrations / schemas / API routes / OAuth / storage façade | ✗ | Add as features land; follow doqo conventions |

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
- `frontend/` — Vue 3 SPA. Entry is `src/main.ts`. Vite config (`vite.config.ts`) builds into `../priv/static`, dev server on `:4001` (HMR `:4002`). Package manager is **pnpm**. Meldui design system mounted via `<Toaster />` in `App.vue`; `src/assets/main.css` imports `@meldui/vue/themes/default` + Geist/Bricolage fonts and declares Tailwind `@source` paths covering the meldui dist. `src/lib/csrf.ts` reads the CSRF token from the root layout's `<meta>` tag. The `phoenix` npm package + `@types/phoenix` are pre-installed so Channels are one UserSocket + endpoint route away when needed.
- `priv/static/assets/` — Vite build output. Gitignored; populated by `mix assets.build` / `mix assets.deploy`. **No `assets/` directory** on the Phoenix side — Vite owns all CSS/JS.
- `priv/repo/migrations/` — Oban schema landed in the initial `add_oban` migration. Application migrations go here.
- Dev DB: `phoenix_vue_template_dev` (Postgres, default `postgres`/`postgres` from `config/dev.exs`).
- HTTP server: Bandit (`Bandit.PhoenixAdapter` in `config/config.exs`).

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

**First-run gotcha:** after a fresh clone, run `mix setup` (not `mix phx.server` directly) so `cd frontend && pnpm install` happens first. Otherwise the `node` watcher tries to import `vite` from a non-existent `node_modules/`.

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

## When Extending the Template

Before adding a new architectural piece (Vue, Oban, auth, OAuth, storage, etc.):

1. Read the corresponding section of `/Users/dipayan/work/doqo/doqo-workspace/doqo-server/CLAUDE.md`.
2. Read the actual implementation files in `doqo-server` (e.g., for Oban: `lib/doqo/documents/workers/embedding.ex` and `config/runtime.exs`; for SPA shell: `lib/doqo_web/components/layouts/root.html.heex` and `frontend/vite.config.ts`).
3. Mirror module naming (`Accounts` / `Organizations` / `Auth` split), error tuples (`{:ok, _} | {:error, _}`, never `!` bangs in app code), query-module split, façade modules for external systems (storage, etc.).
4. Update this CLAUDE.md to flip the corresponding row in the "Current State vs. Template Goal" table from ✗ to ✓ once the piece lands.
