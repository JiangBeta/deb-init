#!/bin/bash

# 设置日志文件路径
BASE_DIR="/tmp/deb-init"
LOG_FILE="$BASE_DIR/deb-init.log"

SCRIPT_DIR_DOCKER_MIGRATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common_functions.sh
source "$SCRIPT_DIR_DOCKER_MIGRATE/common_functions.sh"

# 确保日志输出到文件
exec 3>&1 4>&2
exec 1> >(tee -a "$LOG_FILE") 2>&1

log_info "阶段 1.2.5: Docker 数据目录迁移 (可选)..."

DEFAULT_DOCKER_DATA_ROOT="/var/lib/docker"
DAEMON_JSON_FILE="/etc/docker/daemon.json"

# 检查 Docker 是否已安装
if ! check_command_installed docker; then
    log_error "Docker 未安装. 请先完成 Docker 安装步骤."
    exit 1
fi
ensure_packages rsync # rsync用于数据迁移

# 获取当前 Docker 数据目录 (如果已配置)
CURRENT_DATA_ROOT=$($SUDO_CMD docker info -f '{{.DockerRootDir}}' 2>/dev/null || echo "$DEFAULT_DOCKER_DATA_ROOT")
if [ -z "$CURRENT_DATA_ROOT" ]; then
    log_warn "无法自动获取当前 Docker 数据目录，将使用默认值 $DEFAULT_DOCKER_DATA_ROOT"
    CURRENT_DATA_ROOT="$DEFAULT_DOCKER_DATA_ROOT"
fi
log_info "当前 Docker 数据目录: $CURRENT_DATA_ROOT"


read -r -p "您想更改 Docker 数据目录吗? (当前: $CURRENT_DATA_ROOT) [y/N]: " choice
case "$choice" in
    [yY][eE][sS]|[yY])
        read -r -p "请输入新的 Docker 数据目录绝对路径 (例如 /data/docker): " NEW_DOCKER_DATA_ROOT

        if [ -z "$NEW_DOCKER_DATA_ROOT" ]; then
            log_error "未输入新的数据目录. 操作取消."
            exit 1
        fi

        if [ "$NEW_DOCKER_DATA_ROOT" == "$CURRENT_DATA_ROOT" ]; then
            log_info "新的数据目录与当前目录相同. 无需操作."
            exit 0
        fi

        log_info "新的 Docker 数据目录将设置为: $NEW_DOCKER_DATA_ROOT"

        # 1. 检查新目录是否存在，不存在则创建
        if [ ! -d "$NEW_DOCKER_DATA_ROOT" ]; then
            log_info "目录 $NEW_DOCKER_DATA_ROOT 不存在, 尝试创建..."
            execute_command_sudo "创建新数据目录 $NEW_DOCKER_DATA_ROOT" mkdir -p "$NEW_DOCKER_DATA_ROOT"
        else
            # 检查目录是否为空，如果不为空则警告
            if [ -n "$(ls -A "$NEW_DOCKER_DATA_ROOT")" ]; then
                log_warn "警告: 目录 $NEW_DOCKER_DATA_ROOT 非空. 如果继续，原有内容可能被覆盖或混合。"
                read -r -p "是否继续? [y/N]: " continue_choice
                if [[ ! "$continue_choice" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                    log_info "操作已取消."
                    exit 0
                fi
            fi
        fi
        
        # 2. 停止 Docker 服务
        log_info "停止 Docker 服务..."
        execute_command_sudo "停止 Docker 服务" systemctl stop docker docker.socket containerd # 确保相关服务都停了

        # 3. 备份并迁移数据
        log_info "开始迁移数据从 $CURRENT_DATA_ROOT 到 $NEW_DOCKER_DATA_ROOT ..."
        # 使用 rsync -aHhiq --progress (或者 -av)
        # -a: 归档模式
        # -H: 保留硬链接
        # -X: 保留扩展属性
        # -A: 保留ACLs
        # --numeric-ids: 不将uid/gid值映射到名称
        if $SUDO_CMD rsync -aHXA --numeric-ids --info=progress2 "$CURRENT_DATA_ROOT/" "$NEW_DOCKER_DATA_ROOT/"; then
             log_info "数据迁移完成."
        else
            log_error "使用 rsync 迁移数据失败. 请检查错误信息. Docker 服务未启动."
            # 可以考虑回滚或提示用户手动处理
            log_info "建议检查 $NEW_DOCKER_DATA_ROOT 的内容并手动恢复 $CURRENT_DATA_ROOT (如果需要)."
            log_info "或者尝试修复rsync问题后重新运行此脚本的迁移部分。"
            log_info "尝试重新启动Docker服务（使用旧目录）..."
            $SUDO_CMD systemctl start docker
            exit 1
        fi
        
        # 4. 修改 daemon.json
        log_info "更新 $DAEMON_JSON_FILE 以指定新的数据目录..."
        execute_command_sudo "创建 /etc/docker 目录 (如果不存在)" mkdir -p /etc/docker
        
        # 使用 jq 添加或更新 "data-root"
        # 读取现有配置（如果有）
        if $SUDO_CMD [ -f "$DAEMON_JSON_FILE" ]; then
            TEMP_DAEMON_JSON=$($SUDO_CMD cat "$DAEMON_JSON_FILE")
        else
            TEMP_DAEMON_JSON="{}"
        fi

        # 添加或更新 data-root
        # shellcheck disable=SC2086 # $SUDO_CMD
        UPDATED_DAEMON_JSON=$(echo "$TEMP_DAEMON_JSON" | jq --arg new_root "$NEW_DOCKER_DATA_ROOT" '. + {"data-root": $new_root}')

        log_info "新的 $DAEMON_JSON_FILE 内容将是:"
        echo "$UPDATED_DAEMON_JSON" | jq .
        
        if echo "$UPDATED_DAEMON_JSON" | $SUDO_CMD tee "$DAEMON_JSON_FILE" > /dev/null; then
            log_info "$DAEMON_JSON_FILE 更新成功."
        else
            log_error "写入 $DAEMON_JSON_FILE 失败. Docker 服务未启动. 请手动配置data-root."
            log_info "尝试重新启动Docker服务（使用旧目录）..."
            $SUDO_CMD systemctl start docker
            exit 1
        fi
        
        # 5. （可选）重命名旧目录作为备份
        OLD_DOCKER_BACKUP_PATH="${CURRENT_DATA_ROOT}.backup_$(date +%Y%m%d%H%M%S)"
        log_info "将旧数据目录 $CURRENT_DATA_ROOT 重命名为 $OLD_DOCKER_BACKUP_PATH (作为备份)..."
        if $SUDO_CMD mv "$CURRENT_DATA_ROOT" "$OLD_DOCKER_BACKUP_PATH"; then
            log_info "旧目录已备份到 $OLD_DOCKER_BACKUP_PATH."
            log_warn "您可以稍后在确认一切正常后手动删除此备份目录: $SUDO_CMD rm -rf $OLD_DOCKER_BACKUP_PATH"
        else
            log_warn "重命名旧数据目录 $CURRENT_DATA_ROOT 失败. 请手动处理."
        fi

        # 6. 重启服务
        log_info "重新加载 Docker daemon 配置并启动 Docker 服务..."
        execute_command_sudo "重新加载 systemd daemon" systemctl daemon-reload
        execute_command_sudo "启动 Docker 服务" systemctl start docker

        # 验证
        NEW_ACTUAL_DATA_ROOT=$($SUDO_CMD docker info -f '{{.DockerRootDir}}' 2>/dev/null)
        if [ "$NEW_ACTUAL_DATA_ROOT" == "$NEW_DOCKER_DATA_ROOT" ]; then
            log_info "Docker 数据目录已成功迁移到 $NEW_DOCKER_DATA_ROOT."
        else
            log_error "Docker 数据目录迁移后验证失败. 当前目录仍为 $NEW_ACTUAL_DATA_ROOT. 请检查 $DAEMON_JSON_FILE 和 Docker 日志."
            log_warn "旧数据目录可能已被重命名，您可能需要手动恢复或调整。"
        fi
        ;;
    *)
        log_info "跳过 Docker 数据目录迁移."
        ;;
esac

log_info "Docker 数据目录迁移步骤完成."

# 恢复标准输出
exec 1>&3 2>&4