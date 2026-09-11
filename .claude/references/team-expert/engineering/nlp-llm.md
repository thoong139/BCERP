# NLP & LLM Patterns

> **Domain**: Engineering / AI-ML
> **Last Updated**: 2026-03-22

---

## 1. Năng lực NLP & LLM

- **Large Language Models**: Fine-tuning LLM, prompt engineering, xây dựng RAG system
- **Natural Language Processing**: Phân tích cảm xúc, trích xuất thực thể, sinh văn bản
- **LLM Integration**: OpenAI, Anthropic, Cohere, local models (Ollama, llama.cpp)
- **Vector Databases**: Pinecone, Weaviate, Chroma, FAISS, Qdrant

---

## 2. LLM - RAG System Pattern

```python
# REQ-ID: REQ-XXX - RAG pipeline chuẩn
class RAGPipeline:
    def __init__(self, embedder, vector_store, llm):
        self.embedder = embedder
        self.vector_store = vector_store
        self.llm = llm

    def query(self, question: str, top_k: int = 5) -> dict:
        # 1. Embed query
        query_embedding = self.embedder.encode(question)
        # 2. Retrieve relevant chunks
        chunks = self.vector_store.search(query_embedding, top_k=top_k)
        # 3. Build context-aware prompt
        context = "\n---\n".join([c.text for c in chunks])
        prompt = f"Dựa trên context sau:\n{context}\n\nTrả lời: {question}"
        # 4. Generate with grounding
        response = self.llm.generate(prompt)
        # 5. Return with source attribution
        return {
            "answer": response,
            "sources": [c.metadata for c in chunks],
            "confidence": min(c.score for c in chunks)
        }
```

---

## 3. Prompt Engineering Rigor

- Version control prompts như code — mỗi prompt thay đổi = commit + test
- Evaluation suite: đo quality trên test set cố định trước khi deploy prompt mới
- Structured output: dùng JSON mode hoặc function calling, không parse free-text
- Guard rails: content filtering, token limits, fallback responses
- Local model: Ollama / llama.cpp cho on-premise inference khi data sensitivity cao
