@echo off
chcp 65001 >nul
title WebSpeak 一键更新 (Windows)

echo ================================================================
echo           WebSpeak 一键更新程序
echo           仓库: https://github.com/muyan6/webspeak
echo ================================================================
echo.

where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 系统中未找到 Git 命令，请先安装 Git。
    pause
    exit /b 1
)

echo [1/3] 正在拉取远程仓库最新更新...
git pull origin main

echo [2/3] 正在检查运行环境...
where docker >nul 2>nul
if %errorlevel% equ 0 (
    echo [3/3] 正在重新构建 Docker 镜像并重启...
    docker compose build
    docker compose up -d
    echo.
    echo 🎉 Docker 容器更新完成并已启动！
    echo 访问地址: http://localhost:3040
) else (
    echo [3/3] 检测到本地环境，正在重新编译前端与后端...
    call npm run prepare:sdk
    call npm rebuild @discordjs/opus --foreground-scripts
    call npm --prefix web run build
    call npm run build
    echo.
    echo 🎉 本地更新编译完成！你可以运行 install.bat 启动服务。
)

echo.
pause
