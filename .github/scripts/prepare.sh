#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/akuity/kargo"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Clone (skip if already exists) ---
if [ ! -d "$REPO_DIR" ]; then
    git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Node version ---
# netlify.toml specifies Node 22.11.0; Docusaurus 3.8.1 requires Node >= 18
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
fi

node --version

# --- Package manager: pnpm (pinned to 9.0.3 via packageManager field) ---
if ! command -v pnpm &>/dev/null; then
    npm install -g pnpm@9.0.3
fi

pnpm --version

# --- Install dependencies in docs/ ---
cd docs
pnpm install --frozen-lockfile

# --- Apply fixes.json if present ---
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

# --- Pre-build: build the custom gtag plugin (needed for docusaurus commands) ---
cd plugins/gtag
pnpm install --frozen-lockfile
pnpm build
cd ../..

# --- Pre-build: copy swagger files to static/ ---
# swagger.yaml and swagger.json are committed at the repo root
pnpm copy-swagger

echo "[DONE] Repository is ready for docusaurus commands."
