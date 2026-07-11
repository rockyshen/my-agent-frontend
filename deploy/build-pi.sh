#!/usr/bin/env bash
# 树莓派前端构建脚本（Jenkins 与手动部署共用）
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/opt/my-agent-frontend}"
NVM_DIR="${NVM_DIR:-/var/lib/jenkins/.nvm}"

git config --global --add safe.directory "$PROJECT_DIR"
cd "$PROJECT_DIR"
git fetch origin main
git reset --hard origin/main

export NVM_DIR
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm use 18
npm ci
npm run build

echo "Build complete: ${PROJECT_DIR}/dist"
