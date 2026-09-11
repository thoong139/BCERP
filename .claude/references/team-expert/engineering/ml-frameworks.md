# ML Frameworks & Kiến trúc

> **Domain**: Engineering / AI-ML
> **Last Updated**: 2026-03-22

---

## 1. ML Frameworks và Công cụ

| Category | Tools |
|----------|-------|
| **ML Frameworks** | TensorFlow, PyTorch, Scikit-learn, Hugging Face Transformers |
| **Ngôn ngữ** | Python, R, JavaScript (TensorFlow.js) |
| **Cloud AI Services** | OpenAI API, Google Cloud AI, AWS SageMaker, Azure Cognitive Services |
| **Xử lý dữ liệu** | Pandas, NumPy, Apache Spark, Dask, Apache Airflow |
| **Model Serving** | FastAPI, Flask, TensorFlow Serving, MLflow, Kubeflow |
| **Vector Databases** | Pinecone, Weaviate, Chroma, FAISS, Qdrant |
| **LLM Integration** | OpenAI, Anthropic, Cohere, local models (Ollama, llama.cpp) |

---

## 2. Code Template: ModelService

```python
# REQ-ID: REQ-XXX - Mô tả tính năng AI
# Module: [Tên Module]
# Feature: [Tên tính năng]

from typing import Optional
import numpy as np

class ModelService:
    """
    Dịch vụ inference cho [tên mô hình].
    Xử lý dự đoán real-time và batch processing.
    """

    def __init__(self, model_path: str, config: dict):
        self.model = self._load_model(model_path)
        self.config = config

    def predict(self, input_data: np.ndarray) -> dict:
        """
        Chạy inference và trả về kết quả dự đoán.

        Args:
            input_data: Dữ liệu đầu vào đã được tiền xử lý

        Returns:
            dict chứa prediction và confidence score
        """
        processed = self._preprocess(input_data)
        prediction = self.model.predict(processed)
        return self._postprocess(prediction)
```

---

## 3. Kiến trúc ML Nâng cao

- Distributed training cho tập dữ liệu lớn với multi-GPU/multi-node
- Transfer learning và few-shot learning cho tình huống dữ liệu hạn chế
- Ensemble methods và model stacking để cải thiện hiệu năng
- Online learning và incremental model updates
- MLOps: automated model lifecycle management
- Multi-model serving và canary deployment strategies
- Tối ưu chi phí qua model compression và efficient inference
