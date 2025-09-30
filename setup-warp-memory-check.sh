#!/bin/bash

# 1. 创建检测脚本
cat > /usr/local/bin/warp-memory-check.sh << 'EOF'
#!/bin/bash

LOGFILE="/var/log/warp-memory-check.log"
MAXSIZE=$((10*1024*1024)) # 10 MB

# 日志大小超过阈值时清空
if [ -f "$LOGFILE" ] && [ $(stat -c%s "$LOGFILE") -ge $MAXSIZE ]; then
    > "$LOGFILE"
fi

# 内存使用率阈值（百分比）
THRESHOLD=80

# 获取当前总内存使用率（去掉 swap）
MEM_USAGE=$(free | awk '/Mem:/ {printf("%.0f", $3/$2 * 100)}')

echo "$(date '+%F %T') Current memory usage: $MEM_USAGE%" >> "$LOGFILE"

if [ "$MEM_USAGE" -ge "$THRESHOLD" ]; then
    echo "$(date '+%F %T') Memory usage above $THRESHOLD%, restarting warp-svc..." >> "$LOGFILE"
    /bin/systemctl restart warp-svc
else
    echo "$(date '+%F %T') Memory usage below $THRESHOLD%, no action." >> "$LOGFILE"
fi
EOF

chmod +x /usr/local/bin/warp-memory-check.sh

# 2. 创建 systemd 服务
cat > /etc/systemd/system/warp-memory-check.service << 'EOF'
[Unit]
Description=Check system memory and restart warp-svc if needed

[Service]
Type=oneshot
ExecStart=/usr/local/bin/warp-memory-check.sh
EOF

# 3. 创建 systemd Timer
cat > /etc/systemd/system/warp-memory-check.timer << 'EOF'
[Unit]
Description=Timer to check system memory and restart warp-svc if needed every 10 minutes

[Timer]
# 每 10 分钟触发一次
OnCalendar=*:0/10
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 4. 重新加载 systemd 并启用 Timer
systemctl daemon-reload
systemctl enable --now warp-memory-check.timer

echo "Warp memory check setup completed. Logs with max 10MB size will be saved in /var/log/warp-memory-check.log"
