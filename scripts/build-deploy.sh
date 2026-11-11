#!/usr/bin/env bash
# Builds levelwise-netlify.zip: just the files the live site serves.
# Usage: scripts/build-deploy.sh [output.zip]   (default: ../levelwise-netlify.zip)
# Normally not needed: Netlify deploys from GitHub on every push (netlify.toml). Kept as a manual fallback.
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-../levelwise-netlify.zip}"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac

npm test --silent

node scripts/stage-site.js >/dev/null
stage="dist"
rm -f "$out"
(cd "$stage" && zip -qr "$out" . -x '.*')
echo "Built $out ($(unzip -l "$out" | tail -1 | awk '{print $2}') files)"
