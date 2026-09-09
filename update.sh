#!/usr/bin/env bash
# ==============================================================================
# WebSpeak 快捷更新脚本
# 用法: bash update.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[INFO] 正在拉取最新代码..."
git pull origin main || true

if command -v docker &>/dev/null && [[ -f "docker-compose.yml" ]]; then
    echo "[INFO] 正在拉取最新预构建镜像并重启服务..."
    docker compose pull && docker compose up -d
    echo "[SUCCESS] WebSpeak 已成功更新至最新版本！"
elif [[ -f "${SCRIPT_DIR}/install.sh" ]]; then
    exec bash "${SCRIPT_DIR}/install.sh" --update "$@"
fi
