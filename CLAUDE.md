# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`phoenix-vue-template` is a personal starter template for the owner's go-to stack: **Phoenix 1.8 + Vue 3 + Postgres + Oban**. The intent is to clone this repo from GitHub and immediately begin shipping a new project without re-doing the same wiring every time.

**Current state:** stock `mix phx.new` scaffold — Phoenix 1.8.5 + LiveView 1.1 + Bandit + Postgres + Tailwind v4 + esbuild. Nothing has been committed yet; no migrations, no Vue, no Oban.


## Template Goal & Reference Implementation

The canonical reference for what this template should grow into is `/Users/dipayan/work/doqo/doqo-workspace/doqo-server` — a mature production app on the exact same stack. When adding any major piece (Vue SPA, Oban, auth, query modules, two-release topology, storage façade, etc.), open `doqo-server/CLAUDE.md` and the relevant source files and **mirror the patterns** rather than inventing new ones. The user's preferences are codified there; this template exists to make them reusable.

## Current State vs. Template Goal

| Area | Status | Plan (mirror from doqo-server) |
|---|---|---|
| Phoenix 1.8 + LiveView 1.1 + Bandit + Postgres + Tailwind v4 + esbuild + Heroicons + Req + Swoosh | ✓ in place | — |
| Vue 3 SPA | ✗ | Vite-served in dev, digested in prod; `root.html.heex` shell with single `<div id="app">`; catch-all route last (see doqo `lib/doqo_web/components/layouts/root.html.heex` and `frontend/vite.config.ts`) |
| Oban | ✗ | Two-release topology (`web` queues `default`/`mailer`; `processors` for heavy work); queues set in `config/runtime.exs` from `RELEASE_NAME` |
| Authentication | ✗ | Three-module split: `PhoenixVue.Accounts` (identity), `PhoenixVue.Organizations` (tenancy), `PhoenixVue.Auth` (plugs/tokens/mailers) |
| Query modules | ✗ | Every schema `lib/.../<thing>.ex` gets a sibling `<thing>_queries.ex`; schemas never call `Repo` |
| Migrations / schemas / API routes / OAuth / storage façade | ✗ | Add as features land; follow doqo conventions |
| `package.json` / pnpm / frontend tooling | ✗ | Added with Vue integration |

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
mix assets.build                       # tailwind + esbuild (one-shot)
mix assets.deploy                      # minify + phx.digest for prod
mix precommit                          # compile --warnings-as-errors + deps.unlock --unused + format + test
```

Run `mix precommit` before every commit (also called out in `AGENTS.md`).

## Architecture Notes (current scaffold)

- `lib/phoenix_vue_template/` — business logic root: `application.ex`, `repo.ex`, `mailer.ex`. New contexts (`PhoenixVue.Accounts`, etc.) go here.
- `lib/phoenix_vue_template_web/` — web layer: `endpoint.ex`, `router.ex`, `telemetry.ex`, `components/`, `controllers/`, `gettext.ex`.
- `assets/` — `js/app.js` + `css/app.css`. Tailwind v4 uses the new `@import "tailwindcss"` syntax inside `app.css` (no `tailwind.config.js`). Vendored: `heroicons.js`, `daisyui.js`, `topbar.js`. **No `package.json` yet** — Vue integration will introduce one and a `frontend/` directory.
- `priv/repo/migrations/` — empty.
- Dev DB: `phoenix_vue_template_dev` (Postgres, default `postgres`/`postgres` from `config/dev.exs`).
- HTTP server: Bandit (`Bandit.PhoenixAdapter` in `config/config.exs`).

## Framework Rules — see AGENTS.md

`AGENTS.md` is the source of truth for Phoenix 1.8 / LiveView / Ecto / HEEx / Elixir / forms / streams / test conventions. **Read it before writing code.** Do not duplicate its rules here. High-level reminders that come up constantly:

- **HTTP client is `Req` only** — never HTTPoison / Tesla / httpc.
- **Tailwind v4 import syntax** in `assets/css/app.css` is canonical; do not add a `tailwind.config.js`.
- **Never use daisyUI components** — hand-roll Tailwind for unique design.
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
