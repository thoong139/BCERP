"""stack_detection — Detect tech stack(s) cua target project.

Phase B cua wf-fix-bugs Coverage Improvement v8.

Cung cap detection logic dua tren config files:
- package.json (TS/JS, React/Vue/Next/Express/NestJS)
- *.csproj (C# .NET)
- pyproject.toml / requirements.txt (Python — FastAPI/Django)
- go.mod (Go)
- pom.xml / build.gradle (Java Spring)
- Cargo.toml (Rust)

Output: stack-info.json schema `stack-info-v1`.

Registry role: NONE — read-only.
"""
from __future__ import annotations

from .stack_detector import (
    StackDetectionResult,
    detect_stack,
    detect_stack_from_dir,
)

__version__ = "1.0.0"

__all__ = [
    "StackDetectionResult",
    "detect_stack",
    "detect_stack_from_dir",
]
