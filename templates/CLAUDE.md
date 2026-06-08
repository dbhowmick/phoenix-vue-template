# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`__MODULE__` is a Phoenix application. Stack: **Phoenix 1.8 + Vue 3 + Postgres + Oban**.

- OTP app: `:__OTP__`
- Module namespaces: `__MODULE__.*` (business logic — Repo, Mailer, Application) and `__MODULE_WEB__.*` (web layer — Endpoint, Router, etc.)
- Dev DB: `__OTP___dev` (Postgres, default `postgres`/`postgres` from `config/dev.exs`)

## Essential commands

All from `mix.exs` aliases:

```
mix setup                              # deps.get + ecto.setup + assets.setup + assets.build
mix phx.server                         # dev server on :4000 with live reload + watchers
iex -S mix phx.server                  # same, with IEx shell attached
mix test                               # auto-creates test DB, runs ExUnit
mix test test/path/to/file_test.exs:42 # single test by file + line
mix test --failed                      # rerun last failures
mix ecto.reset                         # drop + create + migrate + seed
mix assets.build                       # pnpm vite build
mix assets.deploy                      # vite build --mode production + phx.digest
mix credo --strict                     # static analysis (.credo.exs)
mix dialyzer                           # type analysis (PLT cached in priv/plts/)
mix precommit                          # compile --warnings-as-errors + deps.unlock --unused + format + credo --strict + dialyzer + test
```

Run `mix precommit` before every commit.

## Architecture

- `lib/__OTP__/` — business logic root: `application.ex`, `repo.ex`, `mailer.ex`. New contexts go here.
- `lib/__OTP___web/` — web layer: `endpoint.ex`, `router.ex`, `telemetry.ex`, `components/`, `controllers/`, `gettext.ex`, `plugs/`. `PageController.home` renders the SPA shell; a catch-all `GET /*path` at the bottom of `router.ex` sends every browser path through it so vue-router survives deep-link refreshes.
- `frontend/` — Vue 3 SPA (Vite 8 + Tailwind v4 + Meldui + Pinia + Vue Router 5, OXC toolchain). Entry is `src/main.ts`. Vite builds into `../priv/static`; dev server runs on `:4001` (HMR `:4002`) inside a `node` watcher started by `mix phx.server`. Package manager is **pnpm**. Meldui is the component substrate (`import { Button, ... } from '@meldui/vue'`), Tabler icons via `@meldui/tabler-vue`, `<Toaster />` mounted in `App.vue`. CSRF token comes from `<meta name="csrf-token">` in the root layout via `src/lib/csrf.ts`. The `phoenix` npm package + `@types/phoenix` are pre-installed so Channels are one UserSocket + endpoint route away when needed.
- `priv/static/assets/` — Vite build output (gitignored). Populated by `mix assets.build` / `mix assets.deploy`. **No `assets/` directory** on the Phoenix side — Vite owns all CSS/JS.
- `priv/repo/migrations/` — Ecto migrations (Oban schema landed in the initial `add_oban` migration).
- HTTP server: Bandit (`Bandit.PhoenixAdapter` in `config/config.exs`).

## Background jobs (Oban)

Oban runs in a two-release topology — queues split by `RELEASE_NAME` in `config/runtime.exs`:

- `__OTP___server` (web) — `default` + `mailer` queues; hosts Pruner + Cron plugins.
- `__OTP___processors` — heavy queues you add as features land (e.g. `documents`, `embeddings`); Pruner only.
- Dev / iex / test (no `RELEASE_NAME`) — all queues run on one node.

Workers go under `lib/__OTP__/.../workers/`. Pattern:

```elixir
defmodule __MODULE__.Some.Workers.MyWorker do
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}), do: :ok
end
```

Tests use `config :__OTP__, Oban, testing: :inline` (jobs run synchronously on enqueue).

## Dev flow

`mix phx.server` runs Phoenix on `:4000` and spawns Vite on `:4001`. The root layout (`lib/__OTP___web/components/layouts/root.html.heex`) conditionally injects either the dev `<script src="//host:4001/@vite/client">` tags or the prod digested `/assets/main.{js,css}` links, keyed off `Application.get_env(:__OTP__, :vite_dev_server)`. Prod build: `MIX_ENV=prod mix assets.deploy` → Vite builds + `phx.digest` cache-busts.

## Framework rules — see AGENTS.md

`AGENTS.md` is the source of truth for Phoenix 1.8 / LiveView / Ecto / HEEx / Elixir / forms / streams / test conventions. **Read it before writing code.** High-level reminders that come up constantly:

- **HTTP client is `Req` only** — never HTTPoison / Tesla / httpc.
- **Tailwind v4 lives on the Vue side** — `frontend/src/assets/main.css` is canonical (no `tailwind.config.js`, no Phoenix-side asset pipeline).
- **Use Meldui for SPA UI** — `import { Button, ... } from '@meldui/vue'` and `@meldui/tabler-vue` for icons. Don't reintroduce daisyUI.
- **Forms always via `Phoenix.Component.to_form/2`**; never pass a changeset directly to `<.form for=...>`.
- **No `live_redirect` / `live_patch`** — use `<.link navigate>` / `push_navigate`.
- **No `String.to_atom/1` on user input** (memory leak).
- **No `Phoenix.View`** (removed).

## Commit message conventions

- **Never add `Co-Authored-By: Claude ...` trailers** to commit messages. Author the commit normally; no AI attribution.
