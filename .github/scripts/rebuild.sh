#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for akuity/kargo
# Runs on existing source tree (files are at current directory, not inside source-repo/).
# The docusaurus root is docs/, so this script should be run from the repo root
# or it can be invoked from docs/ directly — we normalize below.

REPO_URL="https://github.com/akuity/kargo"

# Determine if we're at the repo root or inside docs/
if [ -f "docusaurus.config.js" ]; then
    # Already in docs/
    DOCS_DIR="."
    REPO_ROOT=".."
elif [ -d "docs" ] && [ -f "docs/docusaurus.config.js" ]; then
    # At repo root
    DOCS_DIR="docs"
    REPO_ROOT="."
else
    echo "[ERROR] Cannot find docusaurus.config.js. Run from repo root or docs/ directory."
    exit 1
fi

# --- Node version ---
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    nvm install 22
    nvm use 22
fi

node --version

# --- Package manager: pnpm ---
if ! command -v pnpm &>/dev/null; then
    npm install -g pnpm@9.0.3
fi

pnpm --version

# --- Install dependencies ---
cd "$DOCS_DIR"

pnpm install --frozen-lockfile

# --- Ensure swagger files exist in static/ ---
# swagger.yaml and swagger.json live at the repo root; copy them to static/
# In rebuild context, source repo root is at REPO_ROOT relative to docs
if [ -f "$REPO_ROOT/swagger.yaml" ] && [ -f "$REPO_ROOT/swagger.json" ]; then
    cp "$REPO_ROOT/swagger.yaml" "$REPO_ROOT/swagger.json" static/
else
    echo "[INFO] swagger files not found at $REPO_ROOT — cloning source to get them"
    TMP_SOURCE="/tmp/kargo-swagger-source"
    if [ ! -d "$TMP_SOURCE" ]; then
        git clone --depth 1 "$REPO_URL" "$TMP_SOURCE"
    fi
    cp "$TMP_SOURCE/swagger.yaml" "$TMP_SOURCE/swagger.json" static/
fi

# --- Build gtag plugin ---
cd plugins/gtag
pnpm install --frozen-lockfile
pnpm build
cd ../..

# --- Build Docusaurus site ---
npx docusaurus build

echo "[DONE] Build complete."
