# phoenix-vue-template

A personal Phoenix + Vue starter. Clone the repo, run `./materialize.sh`, and
get a new project pre-wired with the stack I reach for every time, without
re-doing the same plumbing.

## What's in the box

**Backend**
- Phoenix 1.8.5 + LiveView 1.1 + Bandit
- Postgres + Ecto (TimescaleDB image via `docker-compose.yml`)
- Oban (OSS 2.22) — two-release topology (`<app>_server` for web/light jobs,
  `<app>_processors` for heavy work)
- Swoosh (mailer) + Req (HTTP client)
- Credo (`--strict`) and Dialyzer wired into `mix precommit`

**Frontend**
- Vue 3.5 + Vue Router 5 + Pinia 3, bundled by Vite 8
- Tailwind v4 via `@tailwindcss/vite` (no `tailwind.config.js`)
- **Meldui** (Reka UI–based) design system + `@meldui/tabler-vue` icons
- Geist + Bricolage Grotesque variable fonts (fontsource)
- OXC toolchain — `oxlint` + `oxfmt` + `eslint-plugin-oxlint`
- `phoenix` npm + `@types/phoenix` pre-installed (Channels-ready)
- TypeScript 6, vue-tsc, pnpm

**Wiring**
- Vite dev server runs on `:4001` inside a Phoenix watcher; `root.html.heex`
  conditionally injects the dev script tags or the prod digested assets
- SPA catch-all route at the end of `router.ex` so vue-router survives
  deep-link refreshes
- CSRF token in `<meta name="csrf-token">`, read by `src/lib/csrf.ts`
- `materialize.sh` rewrites every `PhoenixVue` / `PhoenixVueWeb` /
  `phoenix_vue_template` reference, renames files and directories, installs
  fresh template-versions of `CLAUDE.md` / `README.md` / `docker-compose.yml`,
  fetches Elixir + node deps, re-inits git, and removes itself

## Requirements

- Elixir 1.15+ (built on 1.19 here)
- Erlang/OTP 26+ (built on 28 here)
- Node 20.19+ or 22.12+
- pnpm
- Docker (for the bundled Postgres compose file)
- Postgres if you'd rather use a local install

## Setup — turning the template into a new project

```sh
git clone git@github.com:dipayanb/phoenix-vue-template.git my-app
cd my-app
./materialize.sh MyApp        # pass a PascalCase project name
```

`materialize.sh` will:

1. Rewrite every `PhoenixVue` / `PhoenixVueWeb` / `phoenix_vue_template` token
2. Rename `lib/phoenix_vue_template{,_web}/` and the matching test dir
3. Swap `templates/{CLAUDE,README,docker-compose}.md|.yml` into the repo root
   with placeholders substituted
4. Re-init git on `main`
5. Run `mix deps.get` + `mix assets.setup` (= `pnpm install` in `frontend/`)
6. Delete itself

Then bring up the database, migrate, and start the server:

```sh
docker compose up -d         # Postgres on :5432
mix ecto.create
mix ecto.migrate             # creates the oban_jobs schema
mix phx.server               # also spawns vite-dev on :4001
```

Open <http://localhost:4000>, and you're shipping.

## Adding authentication

The template ships a single-shot generator that drops in a complete auth stack
— User / PasswordCredential / Session / Organization / Member schemas,
migrations, a three-module split (`<App>.Accounts` / `<App>.Organizations` /
`<App>.Auth`), JSON API (`/api/auth/register`, `/api/sessions`, `/api/me`,
`/api/me/password-reset`, etc.), HttpOnly auth cookie + CSRF wiring, Argon2id
password hashing, session-sweeper Oban cron, Swoosh mailer with Oban delivery
worker, Vue SPA pages (Login / Register / Forgot / Reset / VerifyEmail /
Onboarding), Pinia auth store, and a CSRF-aware fetch wrapper.

```sh
mix phoenix_vue.gen.auth --mode multi    # users can belong to N organizations (default)
mix phoenix_vue.gen.auth --mode single   # one organization per user, auto-created at signup
mix deps.get                             # picks up argon2_elixir + plug_crypto
mix ecto.migrate                         # applies the new auth migrations
mix phx.server
```

The generator is **single-shot** and refuses to re-run. The data model is
identical between modes — flipping `single → multi` later is one constant
change in `frontend/src/lib/auth-mode.ts` plus a migration dropping the
`members_single_tenant_user_id_index`.

When it lands, the generator rewrites the `phoenix_vue:gen.auth:claude_anchor`
block in your project's `CLAUDE.md` so the AI-facing project guide reflects
the wired-up state (which modules live where, what's in vs out).

What's **not** included by design: OAuth, invite UI (columns and changesets
ship though, so adding it later is just a controller + view), rate limiting,
app chrome (`NavRail` / `UserProfileMenu` / `SecurityView` / members list —
you wire your own), 2FA / WebAuthn / magic links.

## Day-to-day commands

```
mix setup                     # deps.get + ecto.setup + assets.setup + assets.build
mix phx.server                # :4000 (Phoenix) + :4001 (Vite via watcher)
iex -S mix phx.server         # same, with IEx attached
mix test                      # creates test DB, runs ExUnit
mix ecto.reset                # drop + create + migrate + seed
mix credo --strict            # static analysis
mix dialyzer                  # type analysis (PLT cached in priv/plts/)
mix precommit                 # compile + format + credo + dialyzer + test
mix assets.deploy             # prod bundle + phx.digest
```

From `frontend/`:

```
pnpm dev / build / preview / type-check / lint / format
```

## Repo layout

```
.
├── CLAUDE.md                  AI-facing project guide (read for full context)
├── AGENTS.md                  Phoenix 1.8 / LiveView / Ecto / HEEx rules
├── materialize.sh             one-shot template → project converter
├── templates/                 files installed at repo root on materialize
│   ├── CLAUDE.md              minimal CLAUDE.md for the new project
│   ├── README.md              minimal README for the new project
│   └── docker-compose.yml     Postgres compose with __OTP__ placeholder
├── docker-compose.yml         working Postgres for template-dev itself
├── lib/phoenix_vue_template/      business logic (renamed on materialize)
├── lib/phoenix_vue_template_web/  web layer (renamed on materialize)
├── config/                    config.exs / dev / test / prod / runtime
├── priv/repo/migrations/      add_oban initial migration
├── frontend/                  Vue SPA (see CLAUDE.md "Frontend" section)
├── mix.exs / mix.lock
└── .credo.exs / .formatter.exs / .gitignore
```

## Further reading

- **`CLAUDE.md`** — full architecture notes, conventions, and the
  "Current State vs. Template Goal" tracking table. Read this before
  extending the template.
- **`AGENTS.md`** — Phoenix 1.8 / LiveView / Ecto / HEEx / forms / streams
  rules. The source of truth for framework-level conventions.

## License

Personal template — no license declared. Fork freely; pin specific versions
in your derived project.
