# Engineering - Semantic Clustering & Hybrid Fingerprinting

> **Domain**: Engineering / Data Remediation
> **Last Updated**: 2026-03-22

---

## Semantic Clustering Compression

Giảm kích thước dataset bằng semantic deduplication thay vì exact matching:

```python
# REQ-ID: REQ-XXX - Semantic clustering pipeline
from sklearn.cluster import DBSCAN
from sentence_transformers import SentenceTransformer
import numpy as np

class SemanticDedup:
    """
    Semantic deduplication sử dụng embedding similarity.
    Giữ lại representative record cho mỗi cluster.
    """

    def __init__(self, model_name: str = "all-MiniLM-L6-v2", eps: float = 0.15):
        self.encoder = SentenceTransformer(model_name)
        self.eps = eps  # Ngưỡng similarity — càng nhỏ càng strict

    def deduplicate(self, texts: list[str]) -> dict:
        # 1. Encode tất cả texts thành vectors
        embeddings = self.encoder.encode(texts, normalize_embeddings=True)

        # 2. Clustering bằng DBSCAN trên cosine distance
        distances = 1 - np.dot(embeddings, embeddings.T)
        clusters = DBSCAN(eps=self.eps, min_samples=1, metric="precomputed").fit(distances)

        # 3. Chọn representative cho mỗi cluster (gần centroid nhất)
        representatives = {}
        for label in set(clusters.labels_):
            indices = np.where(clusters.labels_ == label)[0]
            centroid = embeddings[indices].mean(axis=0)
            closest = indices[np.argmin(np.linalg.norm(embeddings[indices] - centroid, axis=1))]
            representatives[label] = {
                "index": int(closest),
                "text": texts[closest],
                "cluster_size": len(indices)
            }

        return {
            "original_count": len(texts),
            "deduped_count": len(representatives),
            "compression_ratio": 1 - len(representatives) / len(texts),
            "representatives": representatives
        }
```

### Tham số quan trọng

| Tham số | Giá trị mặc định | Ý nghĩa |
|---------|-----------------|---------|
| `model_name` | `all-MiniLM-L6-v2` | Sentence transformer model — nhỏ gọn, phù hợp local |
| `eps` | `0.15` | Cosine distance threshold — càng nhỏ càng strict (ít cluster hơn) |
| `min_samples` | `1` | DBSCAN min_samples=1 → mọi point đều là core point |

### Output structure

```python
{
    "original_count": 10000,       # Số records ban đầu
    "deduped_count": 4200,         # Số records sau dedup
    "compression_ratio": 0.58,     # 58% records đã loại bỏ
    "representatives": {
        0: {"index": 42, "text": "...", "cluster_size": 5},
        1: {"index": 87, "text": "...", "cluster_size": 3},
        # ...
    }
}
```

---

## Hybrid Fingerprinting

Kết hợp nhiều kỹ thuật fingerprinting để phát hiện duplicate ở nhiều mức độ:

| Kỹ thuật | Phát hiện | Tốc độ | Accuracy |
|----------|-----------|--------|----------|
| **Exact hash** (MD5/SHA256) | Exact duplicates | Rất nhanh | 100% |
| **MinHash + LSH** | Near-duplicate documents | Nhanh | ~95% |
| **SimHash** | Similar content | Nhanh | ~90% |
| **Semantic embedding** | Semantically similar | Chậm | ~98% |

### Pipeline: Coarse-to-fine deduplication

```python
# Pipeline: Coarse-to-fine deduplication
def hybrid_dedup(records: list[dict]) -> list[dict]:
    # Stage 1: Exact hash — loại bỏ exact duplicates (O(n))
    seen_hashes = set()
    stage1 = []
    for r in records:
        h = hash_record(r)
        if h not in seen_hashes:
            seen_hashes.add(h)
            stage1.append(r)

    # Stage 2: MinHash LSH — loại bỏ near-duplicates (O(n))
    stage2 = minhash_dedup(stage1, threshold=0.8)

    # Stage 3: Semantic — loại bỏ semantic duplicates (O(n²) nhưng trên tập nhỏ hơn)
    stage3 = semantic_dedup(stage2, eps=0.15)

    return stage3
```

### Lý do dùng coarse-to-fine

- Stage 1 (exact hash) loại bỏ bulk duplicates với O(n) — rẻ nhất
- Stage 2 (MinHash LSH) xử lý near-duplicates còn lại, vẫn O(n) nhờ LSH indexing
- Stage 3 (semantic) chạy trên tập đã nhỏ hơn đáng kể, giảm chi phí O(n²)

### Chỉ số Semantic Dedup

| Chỉ số | Mục tiêu | Ghi chú |
|--------|----------|---------|
| Semantic dedup precision | ≥ 95% | Không loại nhầm records khác ý nghĩa |
| Processing throughput | ≥ 10K records/s | Cho batch pipeline (toàn bộ hybrid pipeline) |
