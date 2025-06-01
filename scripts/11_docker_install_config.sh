#!/bin/bash

SCRIPT_DIR_DOCKER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_DOCKER/common_functions.sh"

log_info "阶段 1.2.1 - 1.2.4: Docker 安装与配置开始..."

# 1.2.1 安装 Docker
log_info "1.2.1 检查并安装 Docker..."
if ! check_command_installed docker; then
    log_info "Docker 未安装. 使用 linuxmirrors.cn 脚本进行安装..."
    DOCKER_INSTALL_SCRIPT_URL="https://linuxmirrors.cn/docker.sh"
    # 确保 curl 已安装
    ensure_packages curl
    if bash <(curl -sSL "$DOCKER_INSTALL_SCRIPT_URL"); then
        log_info "Docker 安装脚本执行完毕."
        # 检查 Docker 是否真的安装成功
        if ! check_command_installed docker; then
            log_error "Docker 安装后仍然未找到 docker 命令. 请检查安装日志."
            exit 1
        fi
        log_info "Docker 安装成功. 版本信息:"
        execute_command_sudo "显示Docker版本" docker --version
        # 将当前用户添加到docker组（如果不是root）
        if [ "$(id -u)" -ne 0 ]; then
            log_info "将当前用户 $USER 添加到 docker 组..."
            execute_command_sudo "添加用户到docker组" usermod -aG docker "$USER"
            log_warn "用户 $USER 已添加到 docker 组. 您可能需要重新登录才能无sudo运行docker命令."
        fi
    else
        log_error "Docker 安装脚本执行失败."
        exit 1
    fi
else
    log_info "Docker 已安装. 版本信息:"
    # shellcheck disable=SC2086
    $SUDO_CMD docker --version
fi

# 1.2.2 安装 Docker Compose
log_info "1.2.2 检查并安装 Docker Compose (v2)..."
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose" # 或者 /usr/libexec/docker/cli-plugins/docker-compose for plugin

# 优先检查 Docker Compose V2 插件形式
DOCKER_CLI_PLUGINS_PATH="/usr/libexec/docker/cli-plugins"
DOCKER_COMPOSE_PLUGIN_PATH="$DOCKER_CLI_PLUGINS_PATH/docker-compose"

if $SUDO_CMD docker compose version > /dev/null 2>&1; then
    log_info "Docker Compose (V2 plugin) 已安装."
    # shellcheck disable=SC2086
    $SUDO_CMD docker compose version
elif [ -f "$DOCKER_COMPOSE_PATH" ] && $SUDO_CMD "$DOCKER_COMPOSE_PATH" version > /dev/null 2>&1; then
    log_info "Docker Compose (standalone V1/V2) 已安装在 $DOCKER_COMPOSE_PATH."
    # shellcheck disable=SC2086
    $SUDO_CMD "$DOCKER_COMPOSE_PATH" version
else
    log_info "Docker Compose 未安装或无法识别. 开始安装最新版 Docker Compose (standalone V2)..."
    ensure_packages jq # 用于解析GitHub API响应

    LATEST_COMPOSE_VERSION=""
    # GitHub API 限速问题，尝试直接访问 releases/latest 页面并解析
    # LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    # 如果API调用失败，可以尝试从网页解析
    # 这是一个备选方案，更健壮的方式是直接用API
    LATEST_COMPOSE_URL_REDIRECT=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/docker/compose/releases/latest)
    if [ -n "$LATEST_COMPOSE_URL_REDIRECT" ]; then
        LATEST_COMPOSE_VERSION=$(basename "$LATEST_COMPOSE_URL_REDIRECT")
    else
        log_warn "无法通过重定向获取最新 Docker Compose 版本号，尝试 API..."
        LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    fi


    if [ -z "$LATEST_COMPOSE_VERSION" ] || [ "$LATEST_COMPOSE_VERSION" == "null" ]; then
        log_warn "无法自动获取最新的 Docker Compose 版本号. 将尝试使用一个已知的较新版本 v2.20.2 (可能不是最新)."
        # 可以设置一个默认的已知良好版本
        LATEST_COMPOSE_VERSION="v2.20.2" # 请定期更新此默认值
    else
        log_info "获取到最新 Docker Compose 版本号: $LATEST_COMPOSE_VERSION"
    fi
    
    UNAME_S=$(uname -s)
    UNAME_M=$(uname -m)
    COMPOSE_DOWNLOAD_URL="https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-${UNAME_S}-${UNAME_M}"

    log_info "下载 Docker Compose 从: $COMPOSE_DOWNLOAD_URL"
    if $SUDO_CMD curl -L "$COMPOSE_DOWNLOAD_URL" -o "$DOCKER_COMPOSE_PATH"; then
        execute_command_sudo "设置 Docker Compose 执行权限" chmod +x "$DOCKER_COMPOSE_PATH"
        log_info "Docker Compose 下载并安装到 $DOCKER_COMPOSE_PATH 成功."
        log_info "Docker Compose 版本:"
        # shellcheck disable=SC2086
        $SUDO_CMD "$DOCKER_COMPOSE_PATH" version
    else
        log_error "下载 Docker Compose 失败. 请检查URL或网络."
        # 不退出，但 compose 可能不可用
    fi
fi

# 1.2.3 添加国内源 和 1.2.4 设置Docker日志
# 这两部分都修改 /etc/docker/daemon.json
DAEMON_JSON_FILE="/etc/docker/daemon.json"
log_info "1.2.3 & 1.2.4 配置 Docker daemon.json (镜像加速和日志)..."
execute_command_sudo "创建 /etc/docker 目录 (如果不存在)" mkdir -p /etc/docker

# 准备要写入的JSON内容
# 使用 jq 来安全地创建或更新 JSON
# 基础结构
NEW_DAEMON_JSON_CONTENT='{}'

# 添加 registry-mirrors
MIRRORS='[
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://dockerhub.cokvr.com",
    "https://ghcr.cokvr.com",
    "https://kfwkfulq.mirror.aliyuncs.com",
    "https://2lqq34jg.mirror.aliyuncs.com",
    "https://pee6w651.mirror.aliyuncs.com",
    "https://registry.docker-cn.com",
    "http://hub-mirror.c.163.com"
]'
NEW_DAEMON_JSON_CONTENT=$(echo "$NEW_DAEMON_JSON_CONTENT" | jq --argjson mirrors "$MIRRORS" '. + {"registry-mirrors": $mirrors}')

# 添加日志配置
LOG_CONFIG='{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}'
NEW_DAEMON_JSON_CONTENT=$(echo "$NEW_DAEMON_JSON_CONTENT" | jq --argjson logs "$LOG_CONFIG" '. + $logs')

# 如果 daemon.json 已存在，尝试合并，否则直接写入
# 为简单起见，这里采用覆盖方式，如果需要保留用户其他配置，需要用 jq 合并
# current_json=$($SUDO_CMD cat "$DAEMON_JSON_FILE" 2>/dev/null || echo "{}")
# combined_json=$(echo "$current_json" | jq --argjson new_conf "$NEW_DAEMON_JSON_CONTENT" '. * $new_conf') # 深度合并
# echo "$combined_json" | $SUDO_CMD tee "$DAEMON_JSON_FILE" > /dev/null

log_info "写入以下内容到 $DAEMON_JSON_FILE:"
echo "$NEW_DAEMON_JSON_CONTENT" | jq . # 显示给用户
if echo "$NEW_DAEMON_JSON_CONTENT" | $SUDO_CMD tee "$DAEMON_JSON_FILE" > /dev/null; then
    log_info "$DAEMON_JSON_FILE 配置成功."
else
    log_error "写入 $DAEMON_JSON_FILE 失败."
    # 不退出，但Docker配置可能不生效
fi

# 更新生效
log_info "重新加载 Docker daemon 配置并重启 Docker 服务..."
execute_command_sudo "重新加载 systemd daemon" systemctl daemon-reload
execute_command_sudo "重启 Docker 服务" systemctl restart docker

log_info "Docker 安装与配置完成."