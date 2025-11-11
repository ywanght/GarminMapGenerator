#!/bin/bash
cd /opt/GarminMapGenerator || exit 1

echo "========== $(date '+%Y-%m-%d %H:%M:%S') Pulling latest from GitHub =========="
git pull origin main

# （可选）复制 widecn.TYP 到你的目标 styles 目录
# cp widecn.TYP /opt/map-factory/styles/

# （可选）如需重启服务，可补充 systemctl 或 nohup 相关命令

echo "========== Done =========="

