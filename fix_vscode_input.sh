#!/bin/bash

# fix_vscode_input.sh
# 修复 VSCode 无法使用搜狗输入法的问题（Linux fcitx/fcitx5）
# Fix Sogou/fcitx input method not working in VSCode on Linux

set -e

echo "===== VSCode 搜狗输入法修复脚本 ====="
echo ""

# -------------------------------------------------------
# 1. 检查并安装 fcitx 相关依赖
# -------------------------------------------------------
install_fcitx_deps() {
    echo "[1/4] 检查 fcitx 依赖..."

    if command -v fcitx5 &>/dev/null; then
        FCITX_CMD="fcitx5"
        IM_MODULE="fcitx"
        echo "  检测到 fcitx5，继续..."
    elif command -v fcitx &>/dev/null; then
        FCITX_CMD="fcitx"
        IM_MODULE="fcitx"
        echo "  检测到 fcitx，继续..."
    else
        echo "  未检测到 fcitx / fcitx5，尝试安装..."
        if [[ -f /etc/debian_version ]]; then
            sudo apt-get update -qq
            sudo apt-get install -y fcitx fcitx-frontend-gtk3 fcitx-frontend-qt5 \
                fcitx-config-gtk3 2>/dev/null || \
            sudo apt-get install -y fcitx5 fcitx5-frontend-gtk3 fcitx5-frontend-qt5 \
                fcitx5-config-qt 2>/dev/null || true
        elif [[ -f /etc/redhat-release ]]; then
            sudo yum install -y fcitx fcitx-gtk3 fcitx-qt5 2>/dev/null || true
        elif [[ -f /etc/arch-release ]]; then
            sudo pacman -S --noconfirm fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool 2>/dev/null || true
        else
            echo "  警告：无法自动安装 fcitx，请手动安装后重新运行此脚本。"
        fi
        FCITX_CMD="fcitx"
        IM_MODULE="fcitx"
    fi
}

# -------------------------------------------------------
# 2. 写入输入法环境变量到 ~/.xprofile（图形登录）和 ~/.profile
# -------------------------------------------------------
setup_env_vars() {
    echo "[2/4] 配置输入法环境变量..."

    IM_MODULE="${IM_MODULE:-fcitx}"
    ENV_BLOCK="
# ---- 搜狗/fcitx 输入法支持（由 fix_vscode_input.sh 添加）----
export GTK_IM_MODULE=${IM_MODULE}
export QT_IM_MODULE=${IM_MODULE}
export XMODIFIERS=@im=${IM_MODULE}
"

    for RC_FILE in "$HOME/.xprofile" "$HOME/.profile"; do
        if grep -q "GTK_IM_MODULE=${IM_MODULE}" "$RC_FILE" 2>/dev/null; then
            echo "  $RC_FILE 中已存在输入法配置，跳过。"
        else
            echo "$ENV_BLOCK" >> "$RC_FILE"
            echo "  已将输入法环境变量写入 $RC_FILE"
        fi
    done

    # 立即在当前 shell 中生效，方便后续步骤使用
    export GTK_IM_MODULE="${IM_MODULE}"
    export QT_IM_MODULE="${IM_MODULE}"
    export XMODIFIERS="@im=${IM_MODULE}"
}

# -------------------------------------------------------
# 3. 修改 VSCode 桌面启动项（Exec 行注入环境变量）
# -------------------------------------------------------
patch_vscode_desktop() {
    echo "[3/4] 修改 VSCode 桌面启动项..."

    IM_MODULE="${IM_MODULE:-fcitx}"
    ENV_PREFIX="env GTK_IM_MODULE=${IM_MODULE} QT_IM_MODULE=${IM_MODULE} XMODIFIERS=@im=${IM_MODULE}"

    # VSCode 可能安装在多个位置
    DESKTOP_FILES=(
        "/usr/share/applications/code.desktop"
        "/usr/share/applications/code-oss.desktop"
        "$HOME/.local/share/applications/code.desktop"
        "$HOME/.local/share/applications/code-oss.desktop"
    )

    patched=0
    for DESKTOP in "${DESKTOP_FILES[@]}"; do
        if [[ ! -f "$DESKTOP" ]]; then
            continue
        fi

        # 检查是否已经打过补丁
        if grep -q "GTK_IM_MODULE=${IM_MODULE}" "$DESKTOP" 2>/dev/null; then
            echo "  $DESKTOP 已包含输入法配置，跳过。"
            patched=1
            continue
        fi

        # 备份原始文件
        if [[ "$DESKTOP" == /usr/share/* ]]; then
            # 系统目录需要 sudo；先复制到用户目录再修改
            USER_DESKTOP="$HOME/.local/share/applications/$(basename "$DESKTOP")"
            mkdir -p "$HOME/.local/share/applications"
            cp "$DESKTOP" "$USER_DESKTOP"
            DESKTOP="$USER_DESKTOP"
        fi

        BACKUP="${DESKTOP}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$DESKTOP" "$BACKUP"
        # 仅修改 Exec= 行（排除 TryExec=），将 Exec=<cmd> 替换为 Exec=env <vars> <cmd>
        sed -i "s|^\(Exec=\)\(.*\)|\1${ENV_PREFIX} \2|g" "$DESKTOP"
        echo "  已修改：$DESKTOP（备份：$BACKUP）"
        patched=1
    done

    if [[ $patched -eq 0 ]]; then
        echo "  未找到 VSCode 桌面启动项文件，将通过环境变量方式生效。"
    fi
}

# -------------------------------------------------------
# 4. 创建带有输入法支持的 VSCode 启动包装脚本
# -------------------------------------------------------
create_wrapper_script() {
    echo "[4/4] 创建 VSCode 输入法包装启动脚本..."

    IM_MODULE="${IM_MODULE:-fcitx}"
    WRAPPER="$HOME/.local/bin/code-im"
    mkdir -p "$HOME/.local/bin"

    cat > "$WRAPPER" <<EOF
#!/bin/bash
# VSCode 搜狗输入法启动脚本（由 fix_vscode_input.sh 生成）
export GTK_IM_MODULE=${IM_MODULE}
export QT_IM_MODULE=${IM_MODULE}
export XMODIFIERS=@im=${IM_MODULE}

# 根据实际安装路径选择 VSCode 可执行文件
if command -v code &>/dev/null; then
    exec code "\$@"
elif command -v code-oss &>/dev/null; then
    exec code-oss "\$@"
else
    echo "未找到 VSCode 可执行文件，请确认 VSCode 已正确安装。"
    exit 1
fi
EOF
    chmod +x "$WRAPPER"
    echo "  已创建包装脚本：$WRAPPER"
    echo "  您可以使用 'code-im' 命令启动 VSCode 以立即生效（无需重新登录）。"
    echo "  如需在终端中直接使用，请确保 ~/.local/bin 在 PATH 中："
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
}

# -------------------------------------------------------
# 主流程
# -------------------------------------------------------
install_fcitx_deps
setup_env_vars
patch_vscode_desktop
create_wrapper_script

echo ""
echo "===== 修复完成 ====="
echo ""
echo "请按以下步骤完成配置："
echo "  1. 重新登录系统（或重启）以使环境变量全局生效。"
echo "  2. 重新登录后启动搜狗输入法。"
echo "  3. 从桌面启动器或终端运行 'code-im' 打开 VSCode。"
echo "  4. 在 VSCode 中切换到中文输入法后即可正常输入中文。"
echo ""
echo "如仍有问题，请检查："
echo "  - 搜狗输入法是否已正确安装并在系统输入法列表中启用。"
echo "  - 运行 'fcitx-diagnose'（fcitx）或 'fcitx5-diagnose'（fcitx5）查看诊断信息。"
