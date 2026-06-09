#!/usr/bin/env bash
# materialize.sh — convert this Phoenix template into a real project.
#
# Usage:
#   ./materialize.sh           # interactive prompt for project name
#   ./materialize.sh MyApp     # non-interactive
#
# Renames the OTP app (phoenix_vue_template), module prefixes (PhoenixVue,
# PhoenixVueWeb), directories, files, and DB names to match the given
# PascalCase project name. Re-inits git, fetches deps, creates the DB,
# then deletes itself.

set -euo pipefail

SCRIPT_PATH="$0"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
cd "$REPO_ROOT"

# ---------- Input ----------

if [ "$#" -ge 1 ]; then
  MODULE="$1"
else
  printf 'Project name (PascalCase, e.g. MyApp): '
  read -r MODULE
fi

if ! printf '%s' "$MODULE" | grep -qE '^[A-Z][A-Za-z0-9]*$'; then
  echo "Error: name must be PascalCase, matching ^[A-Z][A-Za-z0-9]*\$" >&2
  exit 1
fi

if [ "$MODULE" = "PhoenixVue" ] || [ "$MODULE" = "PhoenixVueWeb" ]; then
  echo "Error: cannot reuse the template's own module name ($MODULE)." >&2
  exit 1
fi

MODULE_WEB="${MODULE}Web"
OTP="$(printf '%s' "$MODULE" \
  | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g; s/([A-Z]+)([A-Z][a-z])/\1_\2/g' \
  | tr '[:upper:]' '[:lower:]')"

# Round-trip check: Elixir's `Macro.camelize(Macro.underscore(name))` must
# equal `name`, otherwise Mix's task discovery (and anything else that
# rebuilds the module name from the OTP atom) will look up the wrong
# module. Names with consecutive capitals like `A2UITest` fail this:
# underscore → `a2_ui_test`, camelize → `A2UiTest` ≠ `A2UITest`.
camelize_otp() {
  local input="$1"
  local out=""
  local part
  local IFS='_'
  set -- $input
  for part in "$@"; do
    out+="$(printf '%s' "${part:0:1}" | tr '[:lower:]' '[:upper:]')${part:1}"
  done
  printf '%s' "$out"
}

EXPECTED_MODULE="$(camelize_otp "$OTP")"
if [ "$EXPECTED_MODULE" != "$MODULE" ]; then
  cat >&2 <<EOF
Error: '$MODULE' does not survive Elixir's underscore/camelize round-trip:

  $MODULE  →  Macro.underscore  →  $OTP
            →  Macro.camelize    →  $EXPECTED_MODULE

This means Mix's task discovery and any code that rebuilds module names
from the OTP atom will look up a module that doesn't exist. Avoid runs
of consecutive capital letters in PascalCase. Try '$EXPECTED_MODULE'
instead.
EOF
  exit 1
fi

echo
echo "Materializing template with:"
echo "  Module (business): $MODULE"
echo "  Module (web):      $MODULE_WEB"
echo "  OTP app:           $OTP"
echo "  Dev DB:            ${OTP}_dev"
echo

if [ "$#" -lt 1 ] && [ -t 0 ]; then
  printf 'Continue? [y/N] '
  read -r ANSWER
  case "$ANSWER" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# ---------- File enumeration ----------

# Use git when available (auto-excludes deps/, _build/, etc. via .gitignore).
# Fall back to find when the repo has no .git (e.g. user wiped it).
if [ -d .git ] && command -v git >/dev/null 2>&1; then
  FILES="$(git ls-files -co --exclude-standard)"
else
  FILES="$(find . -type f \
    -not -path './.git/*' \
    -not -path './_build/*' \
    -not -path './deps/*' \
    -not -path './priv/static/*' \
    -not -path './assets/node_modules/*' \
    | sed 's|^\./||')"
fi

should_skip_path() {
  case "$1" in
    materialize.sh) return 0 ;;
    templates/*) return 0 ;;
    # Generator infrastructure ships with stable, project-name-agnostic
    # identifiers — `mix phoenix_vue.gen.auth` stays the same command on
    # every materialized project, and EEx templates stay parameterized
    # via `<%= @base_string %>` etc. (resolved at generator-run time
    # from the target app's identifiers). Rewriting them would (a) break
    # the task's module name, (b) corrupt the EEx placeholders.
    lib/mix/tasks/*) return 0 ;;
    priv/templates/*) return 0 ;;
  esac
  return 1
}

is_binary() {
  # file --mime-encoding prints "binary" for binary files; treat missing tool as text.
  if ! command -v file >/dev/null 2>&1; then
    return 1
  fi
  enc="$(file --mime-encoding -b "$1" 2>/dev/null || echo unknown)"
  [ "$enc" = "binary" ]
}

# ---------- Token replacement (longest-prefix first) ----------

echo "Rewriting tokens in source files..."
echo "$FILES" | while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ ! -f "$f" ] && continue
  if should_skip_path "$f"; then continue; fi
  if is_binary "$f"; then continue; fi
  sed -i.bak \
    -e "s/PhoenixVueWeb/${MODULE_WEB}/g" \
    -e "s/PhoenixVue/${MODULE}/g" \
    -e "s/phoenix_vue_template/${OTP}/g" \
    "$f"
  rm -f "${f}.bak"
done

# ---------- Directory + file renames ----------

echo "Renaming directories and files..."
[ -f "lib/phoenix_vue_template.ex" ]     && mv "lib/phoenix_vue_template.ex"     "lib/${OTP}.ex"
[ -f "lib/phoenix_vue_template_web.ex" ] && mv "lib/phoenix_vue_template_web.ex" "lib/${OTP}_web.ex"
[ -d "lib/phoenix_vue_template" ]        && mv "lib/phoenix_vue_template"        "lib/${OTP}"
[ -d "lib/phoenix_vue_template_web" ]    && mv "lib/phoenix_vue_template_web"    "lib/${OTP}_web"
[ -d "test/phoenix_vue_template_web" ]   && mv "test/phoenix_vue_template_web"   "test/${OTP}_web"

# ---------- Templated file install ----------

# Every file under templates/ uses __MODULE__ / __MODULE_WEB__ / __OTP__
# placeholders and gets installed at the repo root (overwriting any
# same-named template-dev file).
echo "Installing templated files from templates/..."
if [ -d templates ]; then
  for tmpl in templates/*; do
    [ -f "$tmpl" ] || continue
    target="$(basename "$tmpl")"
    sed \
      -e "s/__MODULE_WEB__/${MODULE_WEB}/g" \
      -e "s/__MODULE__/${MODULE}/g" \
      -e "s/__OTP__/${OTP}/g" \
      "$tmpl" > "$target"
  done
  rm -rf templates
fi

# ---------- Git re-init ----------

echo "Re-initializing git..."
rm -rf .git
git init -b main >/dev/null

# ---------- Bootstrap ----------

echo "Fetching deps..."
if command -v mix >/dev/null 2>&1; then
  mix deps.get
  # Pull the frontend deps too so the node watcher can boot when the project
  # is first run with `mix phx.server`. DB setup is left to the operator —
  # spin up docker-compose, then run mix ecto.create + ecto.migrate.
  mix assets.setup
else
  echo "Warning: 'mix' not found on PATH — skipping deps.get and assets.setup."
fi

cat <<EOF

Materialization complete.

Next steps:
  docker compose up -d
  mix ecto.create
  mix ecto.migrate
  git add . && git commit -m "Initial commit"
  mix phx.server

Want authentication? Drop in the full stack (users, sessions, organizations,
JSON API, Vue auth pages) with the generator:

  mix phoenix_vue.gen.auth --mode multi    # users can belong to N orgs (default)
  mix phoenix_vue.gen.auth --mode single   # one org per user, auto-created
  mix deps.get && mix ecto.migrate         # picks up argon2_elixir + applies new migrations

The generator is single-shot. See the "Adding authentication" section in
README.md for the full scope.

EOF

# ---------- Self-delete ----------

rm -- "$SCRIPT_PATH"
