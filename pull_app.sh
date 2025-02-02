#!/bin/bash

# 1. 检查是否安装 Git
if ! command -v git &> /dev/null; then
    echo "Git 未安装，正在安装 Git..."
    # 检查操作系统并安装 Git
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS 使用 Homebrew 安装 Git
        brew install git
    elif [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu 系统
        sudo apt update && sudo apt install -y git
    elif [[ -f /etc/redhat-release ]]; then
        # RHEL/CentOS 系统
        sudo yum install -y git
    elif [[ -f /etc/arch-release ]]; then
        # Arch 系统
        sudo pacman -S git --noconfirm
    else
        echo "不支持的操作系统。请手动安装 Git。"
        exit 1
    fi
else
    echo "Git 已安装"
fi

# 2. 检查当前目录是否是一个 Git 仓库
if [ ! -d ".git" ]; then
    echo "当前目录不是一个 Git 仓库，正在克隆仓库..."
    rm -rf *
    # 克隆仓库
    git clone https://github.com/KeyingWei/Oven_Release.git .
else
    echo "当前目录是一个 Git 仓库"
    
    # 3. 检查是否是最新提交
    echo "检查是否是最新提交..."
    git fetch origin
    LOCAL_COMMIT=$(git rev-parse HEAD)
    REMOTE_COMMIT=$(git rev-parse origin/main)

    if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
        echo "当前仓库不是最新提交，正在拉取最新的提交..."
        git pull origin main
	sudo systemctl reboot
    else
        echo "当前仓库已经是最新提交"
    fi
fi
./Oven_V1App
