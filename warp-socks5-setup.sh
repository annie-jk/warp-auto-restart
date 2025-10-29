#!/bin/bash
set -e

WARP_PORT=40000
WARP_SERVICE=warp-svc
SOCKS5_SERVICE=warp-socks5-autostart

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
    echo "请使用 root 运行脚本"
    exit 1
fi

echo "请选择操作：
1) 安装/配置 WARP SOCKS5 代理
2) 完整卸载 WARP 客户端及自启服务"
read -rp "(1/2): " choice

install_warp() {
    echo "开始安装/配置 WARP SOCKS5 代理..."

    # 安装依赖
    apt-get update
    apt-get install -y curl gnupg lsb-release

    # 添加 Cloudflare 公钥和仓库
    if [[ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]]; then
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor \
            --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    fi
    if [[ ! -f /etc/apt/sources.list.d/cloudflare-client.list ]]; then
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
            > /etc/apt/sources.list.d/cloudflare-client.list
    fi

    # 安装 WARP
    apt-get update
    apt-get install -y cloudflare-warp

    # 启动 WARP daemon
    systemctl enable $WARP_SERVICE
    systemctl start $WARP_SERVICE

    # 注册客户端
    if ! warp-cli status &>/dev/null; then
        warp-cli register
    fi

    warp-cli registration delete 2>/dev/null || true
    warp-cli registration new

    # 设置 SOCKS5 代理模式
    warp-cli mode proxy
    warp-cli proxy port $WARP_PORT
    warp-cli connect

    # 创建开机自启服务
    cat >/etc/systemd/system/$SOCKS5_SERVICE.service <<EOF
[Unit]
Description=Auto start WARP SOCKS5 proxy
After=network.target $WARP_SERVICE.service

[Service]
Type=oneshot
ExecStart=/usr/bin/warp-cli connect
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SOCKS5_SERVICE
    systemctl start $SOCKS5_SERVICE

    echo "WARP SOCKS5 代理已就绪，端口 $WARP_PORT 可用！"
    echo "系统开机后会自动启动 SOCKS5 代理。"
}

uninstall_warp() {
    echo "停止并卸载 WARP 客户端及自启服务..."
    systemctl stop $SOCKS5_SERVICE 2>/dev/null || true
    systemctl disable $SOCKS5_SERVICE 2>/dev/null || true
    rm -f /etc/systemd/system/$SOCKS5_SERVICE.service
    systemctl daemon-reload

    systemctl stop $WARP_SERVICE 2>/dev/null || true
    systemctl disable $WARP_SERVICE 2>/dev/null || true
    apt-get remove --purge -y cloudflare-warp
    apt-get autoremove -y

    echo "WARP 客户端及自启服务已完全卸载，仓库和公钥保留。"
}

case $choice in
    1)
        install_warp
        ;;
    2)
        uninstall_warp
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac
