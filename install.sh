#!/usr/bin/env bash
# ==============================================================================
# WebSpeak 一键安装与管理脚本
# GitHub: https://github.com/muyan6/webspeak
# ==============================================================================

set -e

# 样式与色彩定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/muyan6/webspeak.git"
INSTALL_DIR="/opt/webspeak"
DEFAULT_PORT=3040
DEFAULT_UDP_RANGE="40000-40099"

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本必须以 root 权限运行。请使用 sudo 或切换至 root 用户。"
        exit 1
    fi
}

get_server_ip() {
    local ip
    ip=$(curl -s4 --max-time 3 ifconfig.me || curl -s4 --max-time 3 api.ipify.org || hostname -I | awk '{print $1}')
    if [[ -z "$ip" ]]; then
        ip="你的服务器公网IP"
    fi
    echo "$ip"
}

detect_install_dir() {
    if [[ -f "./docker-compose.yml" && -f "./package.json" ]]; then
        INSTALL_DIR="$(pwd)"
    fi
}

install_docker_if_needed() {
    if ! command -v docker &> /dev/null; then
        info "未检测到 Docker，正在自动安装 Docker..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
        success "Docker 安装完成！"
    fi

    if ! docker compose version &> /dev/null; then
        info "正在安装/配置 docker compose 插件..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y docker-compose-plugin
        elif command -v yum &> /dev/null; then
            yum install -y docker-compose-plugin
        fi
    fi
}

configure_firewall() {
    local port=$1
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        info "配置 UFW 防火墙放行端口：TCP ${port}，UDP ${DEFAULT_UDP_RANGE}..."
        ufw allow "${port}/tcp" comment "WebSpeak HTTP" > /dev/null 2>&1 || true
        ufw allow 40000:40099/udp comment "WebSpeak WebRTC" > /dev/null 2>&1 || true
    elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        info "配置 Firewalld 防火墙放行端口：TCP ${port}，UDP ${DEFAULT_UDP_RANGE}..."
        firewall-cmd --permanent --add-port="${port}/tcp" > /dev/null 2>&1 || true
        firewall-cmd --permanent --add-port=40000-40099/udp > /dev/null 2>&1 || true
        firewall-cmd --reload > /dev/null 2>&1 || true
    fi
}

install_docker() {
    check_root
    install_docker_if_needed

    detect_install_dir

    if [[ "$INSTALL_DIR" == "/opt/webspeak" && ! -d "$INSTALL_DIR" ]]; then
        info "正在克隆 WebSpeak 仓库到 ${INSTALL_DIR}..."
        mkdir -p /opt
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"

    read -p "请输入 Web 访问端口 [默认 ${DEFAULT_PORT}]: " user_port
    PORT=${user_port:-$DEFAULT_PORT}

    # 写入 .env 文件
    echo "PORT=${PORT}" > .env
    success "端口已设置为: ${PORT}"

    configure_firewall "$PORT"

    info "正在拉取依赖并构建 WebSpeak Docker 镜像..."
    docker compose build

    info "正在启动 WebSpeak 服务..."
    docker compose up -d

    info "正在验证服务运行状态..."
    sleep 3

    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${BOLD}🎉 WebSpeak 一键安装与启动成功！${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "网页语音客户端:   ${CYAN}http://${SERVER_IP}:${PORT}${NC}"
    echo -e "管理员控制台:     ${CYAN}http://${SERVER_IP}:${PORT}/admin${NC}"
    echo -e "WebRTC 语音端口:  UDP ${DEFAULT_UDP_RANGE}"
    echo -e "项目所在目录:     ${INSTALL_DIR}"
    echo -e "查看实时运行日志: ${YELLOW}docker compose -f ${INSTALL_DIR}/docker-compose.yml logs -f${NC}"
    echo -e "${GREEN}================================================================${NC}"
}

update_app() {
    check_root
    detect_install_dir

    if [[ ! -d "$INSTALL_DIR" ]]; then
        error "未找到 WebSpeak 安装目录 (${INSTALL_DIR})，请先进行安装。"
        exit 1
    fi

    cd "$INSTALL_DIR"
    info "开始一键更新 WebSpeak..."

    # 备份数据库
    if [[ -f "data/webspeak.db" ]]; then
        mkdir -p "data/backups"
        cp "data/webspeak.db" "data/backups/webspeak_$(date +%Y%m%d_%H%M%S).db"
        info "数据库已自动备份至 data/backups/"
    fi

    info "正在从 GitHub 拉取最新代码..."
    git fetch --all
    git reset --hard origin/main || git pull origin main

    if [[ -f "docker-compose.yml" ]] && docker compose ps &> /dev/null; then
        info "检测到 Docker 部署环境，正在重新构建并重启容器..."
        docker compose build
        docker compose up -d
        success "Docker 容器已平滑更新并重启！"
    elif systemctl is-active --quiet webspeak; then
        info "检测到 Systemd 服务环境，正在重新编译并重启服务..."
        npm install
        npm run prepare:sdk
        npm rebuild @discordjs/opus
        npm --prefix web install
        npm --prefix web run build
        npm run build
        systemctl restart webspeak
        success "WebSpeak 服务已更新并重启！"
    else
        warn "未检测到运行中的服务，代码已拉取至最新。"
    fi

    local PORT=${DEFAULT_PORT}
    if [[ -f ".env" ]]; then
        source .env || true
    fi
    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo ""
    echo -e "${GREEN}================================================================${NC}"
    echo -e "${BOLD} WebSpeak 一键更新完成！${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "访问地址: ${CYAN}http://${SERVER_IP}:${PORT}${NC}"
    echo -e "${GREEN}================================================================${NC}"
}

start_service() {
    detect_install_dir
    cd "$INSTALL_DIR"
    if [[ -f "docker-compose.yml" ]]; then
        docker compose up -d
        success "服务已启动 (Docker)"
    elif systemctl is-active --quiet webspeak || [[ -f "/etc/systemd/system/webspeak.service" ]]; then
        systemctl start webspeak
        success "服务已启动 (Systemd)"
    else
        error "未找到已配置的服务。"
    fi
}

stop_service() {
    detect_install_dir
    cd "$INSTALL_DIR"
    if [[ -f "docker-compose.yml" ]]; then
        docker compose stop
        success "服务已停止 (Docker)"
    elif [[ -f "/etc/systemd/system/webspeak.service" ]]; then
        systemctl stop webspeak
        success "服务已停止 (Systemd)"
    fi
}

restart_service() {
    detect_install_dir
    cd "$INSTALL_DIR"
    if [[ -f "docker-compose.yml" ]]; then
        docker compose restart
        success "服务已重启 (Docker)"
    elif [[ -f "/etc/systemd/system/webspeak.service" ]]; then
        systemctl restart webspeak
        success "服务已重启 (Systemd)"
    fi
}

view_status() {
    detect_install_dir
    cd "$INSTALL_DIR"
    echo -e "\n${BOLD}--- 服务状态 ---${NC}"
    if [[ -f "docker-compose.yml" ]]; then
        docker compose ps
    fi
    if [[ -f "/etc/systemd/system/webspeak.service" ]]; then
        systemctl status webspeak --no-pager || true
    fi

    local PORT=${DEFAULT_PORT}
    if [[ -f ".env" ]]; then
        source .env 2>/dev/null || true
    fi
    echo -e "\n当前配置端口: ${CYAN}${PORT}${NC}"
    local SERVER_IP
    SERVER_IP=$(get_server_ip)
    echo -e "访问地址:     ${CYAN}http://${SERVER_IP}:${PORT}${NC}\n"
}

view_logs() {
    detect_install_dir
    cd "$INSTALL_DIR"
    if [[ -f "docker-compose.yml" ]]; then
        docker compose logs -f --tail=100
    elif [[ -f "/etc/systemd/system/webspeak.service" ]]; then
        journalctl -u webspeak -f -n 100
    fi
}

change_port() {
    check_root
    detect_install_dir
    cd "$INSTALL_DIR"

    read -p "请输入新的 Web 访问端口: " new_port
    if [[ -n "$new_port" && "$new_port" =~ ^[0-9]+$ ]]; then
        echo "PORT=${new_port}" > .env
        configure_firewall "$new_port"
        info "正在以新端口重启服务..."
        if [[ -f "docker-compose.yml" ]]; then
            docker compose down
            docker compose up -d
        fi
        success "端口已修改为: ${new_port}，服务已重新启动！"
    else
        error "端口输入无效。"
    fi
}

uninstall_app() {
    check_root
    detect_install_dir
    warn "警告: 确定要卸载 WebSpeak 吗？"
    read -p "如确定请在键盘输入 'YES' (不含引号): " confirm
    if [[ "$confirm" != "YES" ]]; then
        info "已取消卸载。"
        return
    fi

    cd "$INSTALL_DIR"
    if [[ -f "docker-compose.yml" ]]; then
        docker compose down
    fi
    if [[ -f "/etc/systemd/system/webspeak.service" ]]; then
        systemctl stop webspeak || true
        systemctl disable webspeak || true
        rm -f /etc/systemd/system/webspeak.service
        systemctl daemon-reload
    fi

    read -p "是否删除数据目录与数据库？(y/N): " del_data
    if [[ "$del_data" == "y" || "$del_data" == "Y" ]]; then
        rm -rf "$INSTALL_DIR"
        success "WebSpeak 已彻底删除。"
    else
        info "已保留安装目录与数据：${INSTALL_DIR}"
    fi
}

show_menu() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${BOLD}          WebSpeak 一键安装与管理脚本 (muyan6/webspeak)         ${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e " 1. ${GREEN}一键安装 / 启动 WebSpeak (Docker 方式 - 推荐)${NC}"
    echo -e " 2. ${CYAN}一键更新 WebSpeak (保留全部数据与配置)${NC}"
    echo -e " 3. 启动服务"
    echo -e " 4. 停止服务"
    echo -e " 5. 重启服务"
    echo -e " 6. 查看服务运行状态与端口"
    echo -e " 7. 查看实时日志"
    echo -e " 8. 修改运行端口"
    echo -e " 9. ${RED}卸载 WebSpeak${NC}"
    echo -e " 0. 退出脚本"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
    read -p "请输入选项 [0-9]: " choice
    case "$choice" in
        1) install_docker ;;
        2) update_app ;;
        3) start_service ;;
        4) stop_service ;;
        5) restart_service ;;
        6) view_status ;;
        7) view_logs ;;
        8) change_port ;;
        9) uninstall_app ;;
        0) exit 0 ;;
        *) error "无效选项，请重新选择。" ;;
    esac
}

# 命令行参数支持，例如: ./install.sh --update
if [[ "$1" == "--install" ]]; then
    install_docker
elif [[ "$1" == "--update" ]]; then
    update_app
elif [[ "$1" == "--start" ]]; then
    start_service
elif [[ "$1" == "--stop" ]]; then
    stop_service
elif [[ "$1" == "--restart" ]]; then
    restart_service
elif [[ "$1" == "--status" ]]; then
    view_status
elif [[ "$1" == "--logs" ]]; then
    view_logs
elif [[ "$1" == "--port" ]]; then
    change_port
else
    show_menu
fi
