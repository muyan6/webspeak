@echo off
chcp 65001 >nul
title WebSpeak 一键管理程序 (muyan6/webspeak)

:menu
cls
echo ================================================================
echo           WebSpeak 一键安装与管理程序 (Windows)
echo           仓库: https://github.com/muyan6/webspeak
echo ================================================================
echo.
echo  默认启动端口: 3040
echo  网页客户端:   http://localhost:3040
echo  管理员后台:   http://localhost:3040/admin
echo.
echo ================================================================
echo  1. [推荐] 使用 Docker Compose 一键构建并启动
echo  2. 使用本地 Node.js 安装依赖并启动开发/生产环境
echo  3. 一键更新项目 (拉取 GitHub 最新代码并重构)
echo  4. 停止运行中的 Docker 容器
echo  5. 查看服务日志 (Docker)
echo  0. 退出
echo ================================================================
echo.
set /p choice=请输入选项 [0-5]: 

if "%choice%"=="1" goto docker_start
if "%choice%"=="2" goto node_start
if "%choice%"=="3" goto update_app
if "%choice%"=="4" goto docker_stop
if "%choice%"=="5" goto docker_logs
if "%choice%"=="0" exit
goto menu

:docker_start
cls
echo 正在检查 Docker 环境...
where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Docker，请先安装 Docker Desktop 或选择选项 2 使用 Node.js 本地运行。
    pause
    goto menu
)
echo 正在构建并启动 WebSpeak Docker 容器...
docker compose up -d --build
echo.
echo WebSpeak 容器启动成功！
echo 正在打开网页: http://localhost:3040
start http://localhost:3040
pause
goto menu

:node_start
cls
echo 正在检查 Node.js 环境...
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Node.js，请先从 https://nodejs.org 安装 Node.js (推荐 v22+)。
    pause
    goto menu
)
echo 正在安装项目依赖并构建...
call npm ci --ignore-scripts
call npm run prepare:sdk
call npm rebuild @discordjs/opus --foreground-scripts
call npm --prefix web ci
call npm --prefix web run build
call npm run build
echo.
echo 构建完成，正在启动 WebSpeak 服务...
start http://localhost:3040
npm start
pause
goto menu

:update_app
cls
echo 正在检查 Git 环境...
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未检测到 Git，请先安装 Git。
    pause
    goto menu
)
echo 正在拉取远程最新代码...
git pull origin main
echo.
echo 代码更新完成！如果使用 Docker，请返回主菜单执行选项 1 重新启动。
pause
goto menu

:docker_stop
cls
echo 正在停止 WebSpeak 容器...
docker compose stop
echo 服务已停止。
pause
goto menu

:docker_logs
cls
docker compose logs -f --tail=100
pause
goto menu
