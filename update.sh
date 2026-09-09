#!/usr/bin/env bash
# ==============================================================================
# WebSpeak 快捷更新脚本
# 用法: bash update.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/install.sh" ]]; then
    exec bash "${SCRIPT_DIR}/install.sh" --update "$@"
else
    echo "未找到主安装脚本，正在尝试 git pull..."
    git pull origin main
    if [[ -f "docker-compose.yml" ]]; then
        docker compose build
        docker compose up -d
    fi
fi
