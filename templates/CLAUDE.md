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
- `lib/__OTP___web/` — web layer: `endpoint.ex`, `router.ex`, `telemetry.ex`, `components/`, `controllers/`, `gettext.ex`.
- `assets/` — `js/app.js` + `css/app.css`. Tailwind v4 uses the `@import "tailwindcss"` syntax inside `app.css` (no `tailwind.config.js`).
- `priv/repo/migrations/` — Ecto migrations.
- HTTP server: Bandit (`Bandit.PhoenixAdapter` in `config/config.exs`).

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
