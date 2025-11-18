from flask import Flask, jsonify
from flask_cors import CORS
import time
import os
import signal
import logging
import threading

app = Flask(__name__)
CORS(app)

# 禁用Flask的访问日志，避免在生产环境中输出大量无用日志
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)  # 只显示错误级别的日志

# 注册蓝图
from routes.matrix import matrix_bp
app.register_blueprint(matrix_bp)

@app.route('/health', methods=['GET'])
def health_check():
    """心跳接口"""
    return jsonify({"status": "ok", "timestamp": time.time()})

@app.route('/shutdown', methods=['POST'])
def shutdown():
    """关闭服务器"""
    print("收到关闭请求，正在关闭服务器...")
    
    response = jsonify({"status": "shutting down"})
    
    def delayed_shutdown():
        time.sleep(0.5)
        print("服务器已关闭")
        os.kill(os.getpid(), signal.SIGTERM)
    
    threading.Thread(target=delayed_shutdown).start()
    return response

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=11459)

