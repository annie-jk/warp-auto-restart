#!/bin/bash
# warp-socks5-setup.sh - 安装/配置 & 卸载 WARP SOCKS5 代理

SOCKS_PORT=40000
AUTOSTART_SCRIPT=/usr/local/bin/warp-socks5-autostart.sh
SYSTEMD_SERVICE=/etc/systemd/system/warp-socks5-autostart.service

# 检查 root
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 或 sudo 运行此脚本"
    exit 1
fi

# -------------------------
# 卸载逻辑
# -------------------------
read -p "请选择操作：1) 安装/配置 WARP 2) 卸载 WARP 客户端及自启脚本 (1/2): " choice

if [[ "$choice" == "2" ]]; then
    echo "停止并卸载 WARP 客户端..."
    systemctl stop warp-svc >/dev/null 2>&1
    apt-get remove --purge cloudflare-warp -y

    echo "删除自动启动脚本和 systemd 服务..."
    systemctl disable warp-socks5-autostart.service >/dev/null 2>&1
    rm -f $SYSTEMD_SERVICE
    rm -f $AUTOSTART_SCRIPT
    systemctl daemon-reload

    echo "WARP 客户端及自动启动脚本已卸载完成，仓库和公钥保留。"
    exit 0
fi

# -------------------------
# 安装/配置逻辑
# -------------------------
echo "开始安装/配置 WARP SOCKS5 代理..."

# 安装前置条件：Cloudflare 仓库
if [ ! -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]; then
    echo "添加 Cloudflare GPG 公钥..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor \
        --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
fi

if [ ! -f /etc/apt/sources.list.d/cloudflare-client.list ]; then
    echo "添加 Cloudflare APT 仓库..."
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" \
        | tee /etc/apt/sources.list.d/cloudflare-client.list
fi

# 安装 Cloudflare WARP
if ! command -v warp-cli >/dev/null 2>&1; then
    echo "安装 Cloudflare WARP..."
    apt-get -o Acquire::ForceIPv4=true update
    apt-get install cloudflare-warp -y
fi

# 启动 WARP 服务
echo "启动 WARP 服务..."
systemctl enable warp-svc
systemctl start warp-svc
sleep 3

# 删除旧注册
warp-cli registration delete >/dev/null 2>&1

# 注册客户端
echo "注册 WARP 客户端..."
warp-cli registration new

# 设置 SOCKS5 模式和端口
echo "设置 SOCKS5 代理模式..."
warp-cli mode proxy
warp-cli proxy port $SOCKS_PORT

# 连接 WARP
echo "连接 WARP..."
warp-cli connect
sleep 3

# 验证 SOCKS5 代理
echo "验证 SOCKS5 代理..."
curl -x "socks5://127.0.0.1:$SOCKS_PORT" ipinfo.io

# 创建开机自启脚本
echo "创建开机自动启动 SOCKS5 代理的 systemd 服务..."
cat > $AUTOSTART_SCRIPT <<EOF
#!/bin/bash
warp-cli connect
warp-cli mode proxy
warp-cli proxy port $SOCKS_PORT
EOF
chmod +x $AUTOSTART_SCRIPT

# 创建 systemd 服务
cat > $SYSTEMD_SERVICE <<EOF
[Unit]
Description=WARP SOCKS5 Auto Start
After=network.target warp-svc.service

[Service]
Type=oneshot
ExecStart=$AUTOSTART_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 启用 systemd 服务
systemctl daemon-reload
systemctl enable warp-socks5-autostart.service

echo "WARP SOCKS5 代理已就绪，端口 $SOCKS_PORT 可用！"
echo "系统开机后会自动启动 SOCKS5 代理。"
