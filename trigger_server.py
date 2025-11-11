# 最终修复版 trigger_server.py
from flask import Flask, request, abort, render_template_string, Response
import subprocess
import os
import threading
import time

app = Flask(__name__)

# --- 安全配置 ---
SECRET_KEY = "QUw8gCDd9gN8JBA!noDw"

# --- 脚本路径 ---
BUILD_SCRIPT_PATH = "/opt/map-factory/build_map.sh"
LOCK_FILE = "/tmp/map_factory_trigger.lock"

# --- 确认页面的 HTML 模板 (浏览器使用) ---
CONFIRM_PAGE_TEMPLATE = """
<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>确认操作</title><style>body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background-color:#f0f2f5;text-align:center}.container{background:white;padding:40px;border-radius:12px;box-shadow:0 4px 12px rgba(0,0,0,0.1)}h2{margin-top:0;color:#333}.button{background-color:#007aff;color:white;border:none;padding:15px 30px;font-size:18px;border-radius:8px;cursor:pointer;transition:background-color .2s}.button:hover{background-color:#0056b3}</style></head><body><div class="container"><h2>确认要启动地图生成任务吗？</h2><form method="post" action="/trigger-task"><input type="hidden" name="key" value="{{ key }}"><button type="submit" class="button">是的，开始生成</button></form></div></body></html>
"""

def acquire_lock():
    if os.path.exists(LOCK_FILE):
        try:
            with open(LOCK_FILE, 'r') as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            print(f"任务正在运行 (PID: {old_pid})，无法获取锁。")
            return False
        except (ProcessLookupError, ValueError, FileNotFoundError):
            print("发现残留的锁文件，正在清理...")
            os.remove(LOCK_FILE)
    
    with open(LOCK_FILE, 'w') as f:
        f.write("")
    return True

def release_lock():
    try:
        if os.path.exists(LOCK_FILE):
            os.remove(LOCK_FILE)
            print("任务完成，锁已释放。")
    except Exception as e:
        print(f"释放锁时出错: {e}")

def task_monitor(process):
    print(f"后台监控线程已启动，监控 build_map.sh 进程 (PID: {process.pid})")
    process.wait()
    print(f"脚本 build_map.sh (PID: {process.pid}) 已执行完毕。")
    release_lock()

def execute_build_task():
    """封装的执行任务的核心逻辑"""
    if not acquire_lock():
        return Response("地图生成任务正在进行中，请稍后再试！", mimetype="text/plain", status=429)

    print(f"Webhook 确认后触发成功，开始执行脚本: {BUILD_SCRIPT_PATH}")
    
    try:
        process = subprocess.Popen(['sudo', BUILD_SCRIPT_PATH],
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  text=True)
        
        with open(LOCK_FILE, 'w') as f:
            f.write(str(process.pid))
        
        monitor_thread = threading.Thread(target=task_monitor, args=(process,))
        monitor_thread.daemon = True
        monitor_thread.start()
        
        return Response("地图生成任务已成功触发！请留意手机通知查看后续结果。", mimetype="text/plain", status=200)
        
    except Exception as e:
        print(f"执行脚本出错: {e}")
        release_lock()
        return Response(f"任务触发失败: {str(e)}", mimetype="text/plain", status=500)

# --- Webhook 路由 ---

def invalid_key_response():
    return Response("密钥无效！", mimetype="text/plain", status=403)

@app.route('/start-build', methods=['GET'])
def show_confirmation_page_for_browser():
    submitted_key = request.args.get('key')
    if submitted_key != SECRET_KEY:
        return invalid_key_response()
    return render_template_string(CONFIRM_PAGE_TEMPLATE, key=submitted_key)

@app.route('/trigger-task', methods=['POST'])
def execute_task_from_browser():
    submitted_key = request.form.get('key')
    if submitted_key != SECRET_KEY:
        return invalid_key_response()
    return execute_build_task()

@app.route('/shortcut-trigger', methods=['POST'])
def execute_task_from_shortcut():
    submitted_key = request.form.get('key')
    if submitted_key != SECRET_KEY:
        return invalid_key_response()
    return execute_build_task()


if __name__ == '__main__':
    print("Flask Trigger Server 启动...")
    app.run(host='0.0.0.0', port=9090)
