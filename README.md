warp-auto-restart
=================

版本: 1.0.0

自动监控系统总内存，并在高内存时自动重启 WARP 服务，同时带日志管理功能。

功能
----

- 每 10 分钟检查系统总内存占用率
- 当内存占用 ≥ 80% 时，自动重启 warp-svc
- 日志记录每次检查和重启操作
- 日志超过 10MB 自动清空，不保留历史
- 全部操作自动化，无需手动干预

安装与使用
-----------

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/annie-jk/warp-auto-restart/main/setup-warp-memory-check.sh

# 赋予执行权限
chmod +x setup-warp-memory-check.sh

# 运行脚本
./setup-warp-memory-check.sh

# 查看 Timer 状态：
systemctl list-timers | grep warp-memory-check

# 查看日志：
tail -f /var/log/warp-memory-check.log
```
日志说明
--------

- 默认日志路径：/var/log/warp-memory-check.log
- 日志记录每次内存检查和是否触发 warp-svc 重启
- 当日志大小超过 10MB 时自动清空

注意事项
--------

- 脚本需以 root 用户运行
- 再次执行脚本会覆盖现有 warp 内存检查设置
- IP 会在重启 warp-svc 时更新，如果应用依赖固定 IP 请注意

更新日志
--------

- v1.0.0 – 初始版本
  - 自动内存监控
  - 高内存自动重启 warp-svc
  - 日志记录并自动清理

示例输出
--------
```text
2025-09-29 22:33:29 Current memory usage: 20%
2025-09-29 22:33:29 Memory usage below 80%, no action.
2025-09-29 22:40:00 Current memory usage: 85%
2025-09-29 22:40:00 Memory usage above 80%, restarting warp-svc...
```
