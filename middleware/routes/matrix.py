from flask import Blueprint, jsonify, request
from pydantic import ValidationError
from models.schemas import MatrixInputRequest, MatrixComputeRequest
from services.matrix_service import (
    handle_matrix_input, handle_matrix_generate,
    handle_matrix_compute, handle_matrix_get
)

matrix_bp = Blueprint('matrix', __name__, url_prefix='/api/matrix')

@matrix_bp.route('/input', methods=['POST'])
def matrix_input():
    """接收手动输入的矩阵数据"""
    try:
        data = request.json or {}
        req = MatrixInputRequest(**data)  # type: ignore
        result = handle_matrix_input(req)
        return jsonify(result.model_dump(exclude_none=True))
    except ValidationError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@matrix_bp.route('/generate', methods=['POST'])
def matrix_generate():
    """接收批量生成的矩阵数据"""
    try:
        data = request.json or []
        requests = [MatrixInputRequest(**item) for item in data]  # type: ignore
        result = handle_matrix_generate(requests)
        return jsonify(result.model_dump(exclude_none=True))
    except ValidationError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@matrix_bp.route('/compute', methods=['POST'])
def matrix_compute():
    """执行矩阵运算"""
    try:
        data = request.json or {}
        req = MatrixComputeRequest(**data)  # type: ignore
        result = handle_matrix_compute(req)
        return jsonify(result.model_dump(exclude_none=True))
    except ValidationError as e:
        return jsonify({"success": False, "error": str(e)}), 400
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

@matrix_bp.route('/get/<matrix_id>', methods=['GET'])
def matrix_get(matrix_id: str):
    """获取指定矩阵的数据"""
    try:
        result = handle_matrix_get(matrix_id)
        return jsonify(result.model_dump(exclude_none=True))
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500