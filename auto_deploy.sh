#!/bin/bash

# 步骤1 —— 拉取GitHub上的最新源码
cd /opt/GarminMapGenerator || exit 1
git pull origin main

echo "覆盖核心脚本及配置到 /opt/map-factory ..."

# 步骤2 —— 批量覆盖关键脚本和资源到老生产目录
cp -v /opt/GarminMapGenerator/build_map.sh /opt/map-factory/
cp -v /opt/GarminMapGenerator/trigger_server.py /opt/map-factory/
cp -v /opt/GarminMapGenerator/widecn.TYP /opt/map-factory/style/

# 如有 splitter、mkgmap 目录等依赖，也可整体覆盖（视实际需求手动放行）
# cp -av /opt/GarminMapGenerator/splitter-r654 /opt/map-factory/
# cp -av /opt/GarminMapGenerator/mkgmap-r4923 /opt/map-factory/

# 步骤3 —— （可选）自动重启服务流程
sudo systemctl restart garmin-trigger

echo "同步流程已完成。"
