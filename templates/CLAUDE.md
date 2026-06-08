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
mix assets.build                       # tailwind + esbuild (one-shot)
mix assets.deploy                      # minify + phx.digest for prod
mix precommit                          # compile --warnings-as-errors + deps.unlock --unused + format + test
```

Run `mix precommit` before every commit.

## Architecture

- `lib/__OTP__/` — business logic root: `application.ex`, `repo.ex`, `mailer.ex`. New contexts go here.
- `lib/__OTP___web/` — web layer: `endpoint.ex`, `router.ex`, `telemetry.ex`, `components/`, `controllers/`, `gettext.ex`, `plugs/`. `PageController.home` renders the SPA shell; a catch-all `GET /*path` at the bottom of `router.ex` sends every browser path through it so vue-router survives deep-link refreshes.
- `frontend/` — Vue 3 SPA (Vite 8 + Tailwind v4 + Pinia + Vue Router 5, OXC toolchain). Entry is `src/main.ts`. Vite builds into `../priv/static`; dev server runs on `:4001` (HMR `:4002`) inside a `node` watcher started by `mix phx.server`. Package manager is **pnpm**. CSRF token comes from `<meta name="csrf-token">` in the root layout via `src/lib/csrf.ts`.
- `priv/static/assets/` — Vite build output (gitignored). Populated by `mix assets.build` / `mix assets.deploy`. **No `assets/` directory** on the Phoenix side — Vite owns all CSS/JS.
- `priv/repo/migrations/` — Ecto migrations.
- HTTP server: Bandit (`Bandit.PhoenixAdapter` in `config/config.exs`).

## Dev flow

`mix phx.server` runs Phoenix on `:4000` and spawns Vite on `:4001`. The root layout (`lib/__OTP___web/components/layouts/root.html.heex`) conditionally injects either the dev `<script src="//host:4001/@vite/client">` tags or the prod digested `/assets/main.{js,css}` links, keyed off `Application.get_env(:__OTP__, :vite_dev_server)`. Prod build: `MIX_ENV=prod mix assets.deploy` → Vite builds + `phx.digest` cache-busts.

## Framework rules — see AGENTS.md

`AGENTS.md` is the source of truth for Phoenix 1.8 / LiveView / Ecto / HEEx / Elixir / forms / streams / test conventions. **Read it before writing code.** High-level reminders that come up constantly:

- **HTTP client is `Req` only** — never HTTPoison / Tesla / httpc.
- **Tailwind v4 import syntax** in `assets/css/app.css` is canonical; do not add a `tailwind.config.js`.
- **Never use daisyUI components** — hand-roll Tailwind for unique design.
- **Forms always via `Phoenix.Component.to_form/2`**; never pass a changeset directly to `<.form for=...>`.
- **No `live_redirect` / `live_patch`** — use `<.link navigate>` / `push_navigate`.
- **No `String.to_atom/1` on user input** (memory leak).
- **No `Phoenix.View`** (removed).

## Commit message conventions

- **Never add `Co-Authored-By: Claude ...` trailers** to commit messages. Author the commit normally; no AI attribution.
