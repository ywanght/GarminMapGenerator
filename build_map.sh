#!/bin/bash

# ==============================================================================
# Garmin 地图自动生成脚本
# ==============================================================================

# --- 1. 配置区 (可根据需要修改) ---

# 工作目录，所有操作都在这里进行
WORKDIR="/opt/map-factory"

# OSM 源数据下载地址
SOURCE_URL="https://download.geofabrik.de/asia/china/yunnan-latest.osm.pbf"

# 成品地图的交付目录 (这是我们之前为 download.wanght.cc 配置的目录)
DELIVERY_DIR="/opt/downloads"

# ntfy.sh 推送通知的主题 (请确保与您手机 App 上订阅的一致)
NTFY_TOPIC="wanght_garmin_map_builds"

# mkgmap 配置
MAP_FAMILY_ID="9432"
MAP_PRODUCT_ID="4"
# 地图名称使用当天的日期，例如 20250929
MAP_NAME=$(date +%Y%m%d)

# --- 2. 工具和文件路径 (脚本会自动使用我们创建的软链接) ---
SPLITTER_JAR="$WORKDIR/splitter/splitter.jar"
MKGMAP_JAR="$WORKDIR/mkgmap/mkgmap.jar"
# 注意：我们假设您的 .typ 文件就在 style 目录的根下
CUSTOM_TYP_FILE="$WORKDIR/style/widecn.TYP"
# 注意：您的命令中包含了 template.args，我们也把它定义出来

# --- 3. 通知函数 ---
# 使用 curl 命令通过 ntfy.sh 发送推送通知
function send_notification() {
    # $1: 标题, $2: 消息内容, $3: 图标标签
    curl -s -H "Title: $1" -H "Tags: $3" -d "$2" "https://ntfy.sh/$NTFY_TOPIC"
}

# --- 4. 主执行流程 ---

# 切换到工作目录，确保后续命令在正确的路径下执行
cd "$WORKDIR" || exit 1

# 发送任务开始通知
send_notification "地图任务启动" "已开始为您生成最新的云南省 Garmin 地图..." "rocket"

# 创建一个日志文件，记录本次任务的所有输出
LOG_FILE="build_log_$(date +%Y%m%d-%H%M%S).txt"
{ # <--- 大括号开始：将所有标准输出和错误都重定向到日志文件

    echo "===== 开始执行地图生成任务 @ $(date) ====="

    # 步骤 1: 清理旧的地图数据
    echo "--> 步骤 1: 清理旧的临时文件..."
    rm -f yunnan-latest.osm.pbf
    rm -rf splitter-output
    mkdir splitter-output

    # 步骤 2: 下载最新的 OSM 源文件
    echo "--> 步骤 2: 下载最新的云南省 OSM 数据 (来自 $SOURCE_URL)..."
    wget -O yunnan-latest.osm.pbf "$SOURCE_URL"
    if [ $? -ne 0 ]; then
        echo "!!! 下载失败，任务中止。"
        # 发送失败通知并退出
        send_notification "地图生成失败" "下载 OSM 源文件时出错！" "x"
        exit 1
    fi

    # 步骤 3: 使用 splitter 分割文件
    echo "--> 步骤 3: 使用 splitter 分割 PBF 文件..."
    java -Xmx10G -jar "$SPLITTER_JAR" yunnan-latest.osm.pbf --output-dir=splitter-output --mapid=68880001

    # 步骤 4: 使用 mkgmap 生成 Garmin 地图
    echo "--> 步骤 4: 使用 mkgmap 生成 gmapsupp.img..."
    java -Xmx10G -jar "$MKGMAP_JAR" \
        --mapname="$MAP_NAME" \
        --description="yunnan" \
        --family-id="$MAP_FAMILY_ID" \
        --product-id="$MAP_PRODUCT_ID" \
        --remove-short-arcs \
        --route \
        --location-autofill=is_in,nearest \
        --index \
        --show-profiles=1 \
        --make-opposite-cycleways \
        --housenumbers \
        --add-pois-to-areas \
        --add-pois-to-lines \
        --code-page=936 \
        --gmapsupp \
        "$CUSTOM_TYP_FILE" \
        splitter-output/*.osm.pbf
        # 注意：脚本默认包含了 template.args。如果您不用它，可以删除 "-c "$TEMPLATE_ARGS_FILE"" 这一行

    # 步骤 5: 交付成品
    echo "--> 步骤 5: 将成品地图移动到下载目录..."
    # 为了方便区分，我们在文件名后加上日期
    if [ -f gmapsupp.img ]; then
        FINAL_MAP_NAME="gmapsupp.img"
        mv gmapsupp.img "$DELIVERY_DIR/$FINAL_MAP_NAME"
        echo "成品地图已生成: $FINAL_MAP_NAME"
    else
        echo "!!! 错误: 未找到生成的 gmapsupp.img 文件！"
        # 发送失败通知并退出
        send_notification "地图生成失败" "Mkgmap 未能成功生成 gmapsupp.img 文件！请检查日志。" "x"
        exit 1
    fi

    echo "===== 地图生成成功！任务结束 @ $(date) ====="

} > "$LOG_FILE" 2>&1 # <--- 大括号结束：所有输出到此为止

# --- 5. 最终结果通知 ---

# 再次检查最终的退出码
if [ $? -eq 0 ]; then
    send_notification "✅ 地图生成成功" "任务已完成！最新的云南地图 '$FINAL_MAP_NAME' 已生成。请访问 https://download.wanght.cc/ 查看。" "tada"
else
    FAILURE_LOG=$(tail -n 20 "$LOG_FILE")
    send_notification "❌ 地图生成失败" "任务执行失败！请检查服务器上的日志文件 '$LOG_FILE'。错误摘要：\n\n$FAILURE_LOG" "x"
fi

exit 0
