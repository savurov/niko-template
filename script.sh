#!/usr/bin/env bash
set -euo pipefail

# ---------- pretty logging ----------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_BOLD=$'\033[1m'
else
  C_RESET="" C_DIM="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_BOLD=""
fi

ts() { date +"%H:%M:%S"; }

log()  { echo "${C_DIM}[$(ts)]${C_RESET} $*"; }
info() { echo "${C_BLUE}${C_BOLD}==>${C_RESET} $*"; }
ok()   { echo "${C_GREEN}✓${C_RESET} $*"; }
warn() { echo "${C_YELLOW}!${C_RESET} $*"; }
die()  { echo "${C_RED}ERROR:${C_RESET} $*" >&2; exit 1; }

on_err() {
  local exit_code=$?
  local line_no=$1
  echo "${C_RED}ERROR:${C_RESET} failed on line ${C_BOLD}${line_no}${C_RESET} (exit ${exit_code})" >&2
  exit "$exit_code"
}
trap 'on_err $LINENO' ERR

need() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not installed"
}

# ---------- inputs ----------
PROJECT_NAME="${1:-}"
BASE_DIR="$HOME/Drochka"

[[ -n "$PROJECT_NAME" ]] || die "project name is empty (usage: $0 <name>)"

# allow only a-z, 0-9 and hyphen
SANITIZED="$(echo "$PROJECT_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"

[[ -n "$SANITIZED" ]] || die "invalid project name after sanitize"

PROJECT_DIR="$BASE_DIR/$SANITIZED"

# ---------- steps ----------
TOTAL_STEPS=9
STEP_NO=0
step() {
  STEP_NO=$((STEP_NO + 1))
  info "[$STEP_NO/$TOTAL_STEPS] $1"
}

# ---------- run ----------
step "Checking requirements"
need git
need npm
need gh
need vercel
need code
ok "git/npm/gh/vercel/code found"

# Auth sanity checks (very common failure)
gh auth status >/dev/null 2>&1 || die "gh not logged in. Run: gh auth login"
vercel whoami >/dev/null 2>&1 || die "vercel not logged in. Run: vercel login"
ok "gh + vercel authenticated"

step "Preparing folder"
mkdir -p "$BASE_DIR"
[[ ! -e "$PROJECT_DIR" ]] || die "folder already exists: $PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
ok "created $PROJECT_DIR"

step "Cloning niko-template and applying app name"
log "Cloning template into: $PROJECT_DIR"
git clone "https://github.com/savurov/niko-template" "$PROJECT_DIR" >/dev/null 2>&1 || die "git clone failed"
cd "$PROJECT_DIR"

[[ -d ".git" ]] || die ".git not found in template folder (unexpected state)"
rm -rf .git
ok "template cloned, removed template .git"

ESCAPED_NAME="$(printf '%s' "$SANITIZED" | sed -e 's/[\\/&]/\\&/g')"
CHANGED=0
while IFS= read -r file; do
  sed -i '' "s/CHANGE_ME/$ESCAPED_NAME/g" "$file"
  CHANGED=$((CHANGED + 1))
done < <(grep -RIl --exclude-dir=.git 'CHANGE_ME' . || true)

ok "replaced CHANGE_ME in ${CHANGED} file(s)"

step "Installing dependencies"
npm install >/dev/null 2>&1
ok "npm install done"

step "Initializing git repo"
git init -q
git add .
git commit -m "chore: init vite app" -q
ok "initial commit created"

step "Creating private GitHub repo and pushing"
# NOTE: if you want to force owner, add: --owner savurov
gh repo create "$SANITIZED" --private --source . --remote origin --push >/dev/null 2>&1
ok "github repo created + pushed"

step "Deploying to Vercel (production) and capturing alias URL"
# One deploy is enough. It will also create/link the Vercel project if not linked yet.
DEPLOY_OUT="$(vercel --prod --yes 2>&1)"

# Prefer the stable production alias line ("Aliased: ...")
APP_URL="$(printf '%s\n' "$DEPLOY_OUT" \
  | grep 'Aliased:' \
  | grep -Eo 'https://[^ ]+(\.vercel\.app|\.vercel\.link)' \
  | head -n 1 || true)"

# Fallback: last vercel.app/vercel.link URL in output
if [[ -z "$APP_URL" ]]; then
  warn "Could not find 'Aliased:' URL; trying fallback parse"
  APP_URL="$(printf '%s\n' "$DEPLOY_OUT" \
    | grep -Eo 'https://[^ ]+(\.vercel\.app|\.vercel\.link)' \
    | tail -n 1 || true)"
fi

if [[ -n "$APP_URL" ]]; then
  ok "app url: $APP_URL"
else
  warn "Vercel URL not detected automatically"
fi

step "Updating README and pushing"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"

{
  echo "# $SANITIZED"
  echo
  echo "## App"
  echo
  if [[ -n "$APP_URL" ]]; then
    echo '```'
    echo "$APP_URL"
    echo '```'
  else
    echo "_Vercel URL not detected automatically._"
  fi
  echo
  echo "## Repository"
  echo
  if [[ -n "$ORIGIN_URL" ]]; then
    echo '```'
    echo "$ORIGIN_URL"
    echo '```'
  else
    echo "_No git remote detected._"
  fi
} > README.md

git add README.md
git commit -m "docs: update README" -q
git push -q
ok "README updated + pushed"

step "Opening VSCode"
code "$PROJECT_DIR" "$PROJECT_DIR/README.md" >/dev/null 2>&1 &
ok "VSCode opened"

echo
info "RESULT"
echo "PROJECT_DIR=$PROJECT_DIR"
[[ -n "$APP_URL" ]] && echo "APP_URL=$APP_URL"
[[ -n "$ORIGIN_URL" ]] && echo "REPO_URL=$ORIGIN_URL"
