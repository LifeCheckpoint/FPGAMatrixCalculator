from pydantic import BaseModel, Field
from typing import List, Optional, Literal

# 请求模型
class MatrixInputRequest(BaseModel):
    id: int = Field(..., ge=1, le=7, description="矩阵ID (1-7)")
    name: str = Field(..., max_length=8, description="矩阵名称")
    rows: int = Field(..., ge=1, le=32, description="行数")
    cols: int = Field(..., ge=1, le=32, description="列数")
    data: List[List[int]] = Field(..., description="矩阵数据")

class MatrixComputeRequest(BaseModel):
    operation: Literal["transpose", "add", "scalar", "multiply", "conv"]
    matrix_id: Optional[str] = None
    matrix_a: Optional[str] = None
    matrix_b: Optional[str] = None
    scalar: Optional[int] = None
    kernel: Optional[List[List[int]]] = None

# 响应模型
class MatrixData(BaseModel):
    id: str
    name: str
    rows: int
    cols: int
    data: List[List[int]]

class BaseResponse(BaseModel):
    success: bool
    message: Optional[str] = None
    error: Optional[str] = None

class MatrixInputResponse(BaseResponse):
    pass

class MatrixGenerateResponse(BaseResponse):
    count: Optional[int] = None

class MatrixComputeResponse(BaseResponse):
    result_id: Optional[str] = None

class MatrixGetResponse(BaseResponse):
    matrix: Optional[MatrixData] = None