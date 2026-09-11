"""chunk_planner — Chia source files thanh chunks ≤ max_tokens (Phase C v8).

Strategy:
1. Estimate tokens per file (rough: 4 chars ≈ 1 token).
2. Group files into chunks targeting ~max_tokens_per_chunk.
3. Files exceeding chunk size — split by line ranges.
4. Output Chunk[] with file content embedded for direct prompt injection.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

# Rough estimate: 4 chars ≈ 1 token (close enough for chunking purposes).
# Real tokenizer (tiktoken) is more accurate but adds dependency.
CHARS_PER_TOKEN = 4.0


@dataclass
class FileScope:
    """1 file in scope cho LLM probe."""
    path: str           # relative path within source_dir
    content: str        # file content (utf-8)
    line_start: int = 1
    line_end: int = 0   # 0 means "end of file"
    purpose: str = ""   # optional hint cho agent


@dataclass
class Chunk:
    """1 chunk de feed LLM agent."""
    files: List[FileScope] = field(default_factory=list)
    estimated_tokens: int = 0
    chunk_index: int = 0

    def to_prompt_section(self) -> str:
        """Render content section cho prompt."""
        parts: List[str] = []
        for i, fs in enumerate(self.files, 1):
            line_info = ""
            if fs.line_end > 0 and (fs.line_start > 1 or fs.line_end < self._count_lines(fs.content)):
                line_info = f" (lines {fs.line_start}-{fs.line_end})"
            purpose = f" — {fs.purpose}" if fs.purpose else ""
            parts.append(f"### File {i}: `{fs.path}`{line_info}{purpose}\n\n```\n{fs.content}\n```\n")
        return "\n".join(parts)

    @staticmethod
    def _count_lines(content: str) -> int:
        return content.count("\n") + 1


def estimate_tokens(text: str) -> int:
    """Rough token estimate."""
    return int(len(text) / CHARS_PER_TOKEN)


def _split_large_file(path: str, content: str, max_tokens: int) -> List[FileScope]:
    """Split large file thanh nhieu FileScope theo line ranges."""
    lines = content.split("\n")
    total_lines = len(lines)
    estimated_total = estimate_tokens(content)
    if estimated_total <= max_tokens:
        return [FileScope(path=path, content=content, line_start=1, line_end=total_lines)]

    # Compute lines per chunk
    avg_chars_per_line = max(1, len(content) / total_lines)
    lines_per_chunk = int(max_tokens * CHARS_PER_TOKEN / avg_chars_per_line)
    if lines_per_chunk < 50:
        lines_per_chunk = 50  # Floor

    scopes: List[FileScope] = []
    start = 0
    while start < total_lines:
        end = min(start + lines_per_chunk, total_lines)
        chunk_content = "\n".join(lines[start:end])
        scopes.append(FileScope(
            path=path, content=chunk_content,
            line_start=start + 1, line_end=end,
        ))
        start = end
    return scopes


def plan_chunks(
    file_paths: List[str],
    source_dir: Path,
    *,
    max_tokens_per_chunk: int = 40_000,
    max_chunks: int = 0,
    purposes: Optional[dict[str, str]] = None,
    skip_missing: bool = True,
) -> List[Chunk]:
    """Plan chunks tu danh sach file paths.

    Args:
        file_paths: relative paths from source_dir.
        source_dir: root.
        max_tokens_per_chunk: budget per chunk.
        max_chunks: hard cap (truncate beyond this). 0 = unlimited (quality-first).
        purposes: optional {path: hint} for agent.
        skip_missing: skip files not on disk (default True).

    Returns:
        Chunks sized ≤ max_tokens_per_chunk. When max_chunks > 0, total ≤ max_chunks;
        otherwise unlimited (no truncation).
    """
    if max_tokens_per_chunk <= 0:
        raise ValueError("max_tokens_per_chunk must be positive")
    purposes = purposes or {}

    # 1. Read all files, compute token counts
    file_scopes: List[FileScope] = []
    for rel_path in file_paths:
        abs_path = source_dir / rel_path
        if not abs_path.is_file():
            if skip_missing:
                continue
            raise FileNotFoundError(f"file not found: {abs_path}")
        try:
            content = abs_path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            if skip_missing:
                continue
            raise

        # Split if too big
        scopes = _split_large_file(rel_path, content, max_tokens_per_chunk)
        for s in scopes:
            s.purpose = purposes.get(rel_path, "")
            file_scopes.append(s)

    # 2. Pack scopes into chunks (greedy bin-packing).
    # max_chunks == 0 → unlimited (quality-first default).
    chunks: List[Chunk] = []
    current = Chunk(chunk_index=0)
    for fs in file_scopes:
        fs_tokens = estimate_tokens(fs.content)
        if current.estimated_tokens + fs_tokens > max_tokens_per_chunk and current.files:
            chunks.append(current)
            if max_chunks > 0 and len(chunks) >= max_chunks:
                break
            current = Chunk(chunk_index=len(chunks))
        current.files.append(fs)
        current.estimated_tokens += fs_tokens

    if current.files and (max_chunks == 0 or len(chunks) < max_chunks):
        chunks.append(current)

    return chunks
