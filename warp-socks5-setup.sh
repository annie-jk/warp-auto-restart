#!/bin/bash
set -e

# 默认 SOCKS5 端口
WARP_PORT=40000

echo "请选择操作："
echo "1) 安装/配置 WARP SOCKS5 代理"
echo "2) 卸载 WARP 客户端及自启服务"
read -p "(1/2): " choice

if [[ "$choice" == "2" ]]; then
    echo "停止并卸载 WARP 客户端及自启服务..."
    systemctl stop warp-svc 2>/dev/null || true
    systemctl disable warp-svc 2>/dev/null || true
    systemctl stop warp-socks5-autostart 2>/dev/null || true
    systemctl disable warp-socks5-autostart 2>/dev/null || true
    apt-get remove --purge -y cloudflare-warp || true
    rm -f /etc/systemd/system/warp-socks5-autostart.service
    systemctl daemon-reload
    echo "WARP 客户端及自启服务已完全卸载。"
    exit 0
fi

echo "开始安装/配置 WARP SOCKS5 代理..."

# 安装前置条件：GPG 公钥 + 仓库
if [[ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]]; then
    echo "添加 Cloudflare WARP GPG 公钥..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor \
        --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
fi

if [[ ! -f /etc/apt/sources.list.d/cloudflare-client.list ]]; then
    echo "添加 Cloudflare WARP APT 仓库..."
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/cloudflare-client.list
fi

echo "更新软件源并安装 Cloudflare WARP..."
apt-get update
apt-get install -y cloudflare-warp

echo "启动 WARP 服务..."
systemctl enable warp-svc
systemctl start warp-svc

# 等待 daemon 启动
sleep 2

# 删除旧注册（防止冲突）
warp-cli registration delete 2>/dev/null || true

echo "注册 WARP 客户端..."
warp-cli registration new

echo "设置 SOCKS5 代理模式..."
warp-cli mode proxy
warp-cli proxy port $WARP_PORT
warp-cli connect
sleep 3
# 检查代理端口
echo "===== 调试: ss -ntlp 输出 ====="
ss -ntlp

echo "===== 调试: grep 匹配尝试 ====="
if ss -ntlp | grep -E "127\.0\.0\.1:$WARP_PORT|:$WARP_PORT" >/dev/null; then
    echo "WARP SOCKS5 代理已就绪，端口 $WARP_PORT 可用！"
else
    echo "警告：SOCKS5 端口未监听，请检查 warp-cli 状态！"
fi


# 创建开机自动启动 SOCKS5 代理的 systemd 服务
SERVICE_FILE="/etc/systemd/system/warp-socks5-autostart.service"
if [[ ! -f "$SERVICE_FILE" ]]; then
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=WARP SOCKS5 AutoStart
After=network.target warp-svc.service

[Service]
Type=oneshot
ExecStart=/usr/bin/warp-cli connect
ExecStartPost=/usr/bin/warp-cli mode proxy
ExecStartPost=/usr/bin/warp-cli proxy port $WARP_PORT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable warp-socks5-autostart
fi

echo "系统开机后会自动启动 SOCKS5 代理。"
echo "安装配置完成！"
