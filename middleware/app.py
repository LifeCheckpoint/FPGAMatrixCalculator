# python_backend/main.py

from flask import Flask, jsonify, request
from flask_cors import CORS
import time

app = Flask(__name__)
CORS(app) 

@app.route('/health', methods=['GET'])
def health_check():
    """
    心跳接口
    """
    return jsonify({"status": "ok", "timestamp": time.time()})

@app.route('/api/process_data', methods=['POST'])
def process_data():
    """
    接收前端 JSON 数据，处理后返回新的 JSON 数据。
    """
    try:
        data = request.json

        if not data:
            return jsonify({"error": "No data provided"}), 400

        name = data.get('name', 'Guest')

        response_message = f"Hello, {name}! Your request was processed by Python."
        
        response_data = {
            "message": response_message,
            "received_data": data
        }
        
        return jsonify(response_data)

    except Exception as e:
        return jsonify({"error": str(e)}), 400

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=11459)

