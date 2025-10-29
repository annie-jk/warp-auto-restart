#!/bin/bash
set -e

# 配置 SOCKS5 端口
SOCKS5_PORT=40000

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户运行此脚本！"
  exit 1
fi

echo "请选择操作："
echo "1) 安装/配置 WARP SOCKS5 代理"
echo "2) 卸载 WARP 客户端及自启服务"
read -rp "(1/2): " ACTION

if [ "$ACTION" == "2" ]; then
    echo "停止并卸载 WARP 客户端及自启服务..."
    systemctl stop warp-svc 2>/dev/null || true
    systemctl stop warp-socks5-autostart.service 2>/dev/null || true

    systemctl disable warp-svc 2>/dev/null || true
    systemctl disable warp-socks5-autostart.service 2>/dev/null || true

    apt-get remove --purge cloudflare-warp -y

    rm -f /etc/systemd/system/warp-svc.service
    rm -f /etc/systemd/system/warp-socks5-autostart.service
    rm -f /usr/local/bin/warp-socks5-autostart.sh
    rm -rf /var/lib/cloudflare-warp/
    rm -rf /var/cache/cloudflare-warp/

    systemctl daemon-reload
    echo "WARP 客户端及自启服务已完全卸载。"
    exit 0
fi

echo "开始安装/配置 WARP SOCKS5 代理..."

# 添加 Cloudflare 仓库及公钥（如果不存在）
if [ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]; then
    echo "添加 Cloudflare 公钥..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor \
        --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
fi

if [ ! -f /etc/apt/sources.list.d/cloudflare-client.list ]; then
    echo "添加 Cloudflare 仓库..."
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/cloudflare-client.list
fi

# 更新索引并安装
apt-get update
apt-get install cloudflare-warp -y

# 启动 WARP daemon
systemctl enable warp-svc
systemctl start warp-svc

# 注册客户端
if ! warp-cli status | grep -q "Registered"; then
    echo "注册 WARP 客户端..."
    warp-cli registration delete 2>/dev/null || true
    warp-cli registration new
fi

# 设置 SOCKS5 代理
warp-cli mode proxy
warp-cli proxy port $SOCKS5_PORT
warp-cli connect

# 验证代理
sleep 2
if ss -ntl | grep -q "$SOCKS5_PORT"; then
    echo "WARP SOCKS5 代理已就绪，端口 $SOCKS5_PORT 可用！"
else
    echo "警告：SOCKS5 代理未启动，请检查 warp-cli 状态。"
fi

# 创建开机自启脚本
cat > /usr/local/bin/warp-socks5-autostart.sh <<EOF
#!/bin/bash
warp-cli connect
warp-cli mode proxy
warp-cli proxy port $SOCKS5_PORT
EOF
chmod +x /usr/local/bin/warp-socks5-autostart.sh

# 创建 systemd 服务
cat > /etc/systemd/system/warp-socks5-autostart.service <<EOF
[Unit]
Description=WARP SOCKS5 Auto Start
After=network.target warp-svc.service
Wants=warp-svc.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/warp-socks5-autostart.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable warp-socks5-autostart.service

echo "系统开机后会自动启动 SOCKS5 代理。"
echo "安装配置完成！"
