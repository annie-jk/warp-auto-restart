#!/bin/bash

# 一键安装/卸载 Cloudflare WARP SOCKS5 代理
# 适用于 apt 系 Linux（Ubuntu/Debian）

SOCKS_PORT=40000

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 或 sudo 运行此脚本"
    exit 1
fi

# 检查是否已安装 cloudflare-warp
if command -v warp-cli >/dev/null 2>&1; then
    echo "检测到 Cloudflare WARP 已安装。"
    read -p "是否卸载已安装的 WARP？(y/n): " uninstall_choice
    if [[ "$uninstall_choice" =~ ^[Yy]$ ]]; then
        echo "停止 WARP 服务..."
        warp-cli disconnect
        systemctl stop warp-svc
        echo "卸载 WARP..."
        apt remove --purge -y cloudflare-warp
        apt autoremove -y
        echo "WARP 已卸载完成！"
        exit 0
    fi
else
    echo "Cloudflare WARP 未安装，开始安装..."
    apt update && apt install cloudflare-warp -y
fi

# 注册 WARP 客户端
echo "注册 WARP 客户端..."
warp-cli registration new

# 设置 SOCKS5 代理模式
echo "设置 WARP 为 SOCKS5 代理模式..."
warp-cli mode proxy

# 设置 SOCKS5 代理端口
warp-cli proxy port $SOCKS_PORT
echo "SOCKS5 代理端口设置为 $SOCKS_PORT"

# 连接 WARP
echo "正在连接 WARP..."
warp-cli connect

# 验证代理是否工作
echo "验证 SOCKS5 代理是否正常工作..."
curl -x "socks5://127.0.0.1:$SOCKS_PORT" ipinfo.io

echo "WARP SOCKS5 代理安装与配置完成！"
