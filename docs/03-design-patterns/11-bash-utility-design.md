# 11 — Bash vs Python Utility Design ★

> **Mức độ ràng buộc:** Tham khảo (guideline) — **cải tiến kiến trúc** đưa thành chuẩn rõ ràng
> **Khi nào dùng:** Quyết định bash hay Python cho helper utility của skill

---

## 1. Vấn đề pattern giải quyết

Trước file này, MCV3 không có guideline rõ:
- `.claude/scripts/ci-detect.sh` — bash
- `.claude/skills/workflow/_shared/isg/` — Python package
- `.claude/skills/workflow/wf-add-scope/scripts/as-*.sh` — bash
- `.claude/skills/workflow/_shared/cdg/` — Python

**Hệ quả:**
- Skill author lúc viết bash, lúc Python — không nhất quán
- Bash script grow lên 500+ dòng (vd: legacy-scan-stage-3.sh) — khó maintain
- Python utility cho task đơn giản (1 dòng `jq`) — overkill

**Pattern giải quyết:** Decision tree rõ — task nào dùng bash, task nào Python.

---

## 2. Pattern definition

### 2.1. Decision tree

```
Task cần thực hiện:
│
├─ Filesystem ops (ls, mkdir, mv, test -f)?
│   ├─ YES → bash
│   └─ NO ↓
│
├─ Pipe commands (jq, grep, sed)?
│   ├─ Đơn giản (≤5 dòng) → bash
│   └─ Phức tạp ↓
│
├─ JSON manipulation phức tạp (build nested, validate schema)?
│   ├─ YES → Python (json/jsonschema)
│   └─ NO ↓
│
├─ Algorithm (graph traversal, dedup, partition)?
│   ├─ YES → Python
│   └─ NO ↓
│
├─ State machine với >5 states?
│   ├─ YES → Python (class-based)
│   └─ NO → bash
│
├─ Multi-threading / async?
│   ├─ YES → Python (asyncio, concurrent.futures)
│   └─ NO → bash
│
└─ Stateful logic (cache, lock, heartbeat)?
    ├─ Simple → bash (with file-based state)
    └─ Complex → Python
```

### 2.2. Decision matrix

| Task type | Recommended | Lý do |
|-----------|-------------|-------|
| File existence check | bash | `test -f` natural |
| JSON read 1 field | bash + jq | Concise |
| JSON build nested 5+ levels | Python | jq script unreadable |
| Git operations (diff, log) | bash | Native |
| HTTP request 1-shot | bash + curl | Simple |
| HTTP request với retry, parallel | Python (requests) | Better control |
| String regex transform | bash + sed/awk | Native |
| Multi-line parsing với state | Python | Easier to read |
| Atomic write JSON | bash (tmp + mv) | File ops bash strong |
| Graph algorithms (BFS, DFS) | Python | Data structures |
| ML/AI calls | Python (anthropic SDK) | Native |
| Schema validation | Python (jsonschema) | jq schema weak |
| Cross-platform (Windows + Linux) | Python | Bash trên Windows khó |
| Skill script ≤100 dòng | bash | Fine |
| Skill script >300 dòng | Python | Maintenance |

### 2.3. Location convention

```
.claude/scripts/                        # Global utility scripts (mostly bash)
  ├─ ci-detect.sh                       # bash — filesystem + jq
  ├─ ci-freshness-check.sh              # bash — git + jq
  └─ wf-{skill}/                        # Per-skill bash helpers
      └─ helper-*.sh

.claude/skills/workflow/_shared/        # Python package (cross-skill)
  ├─ isg/                               # Python — graph algorithms
  ├─ signal_bus/                        # Python — async + threading
  ├─ cdg/                               # Python — state machine
  ├─ cache/                             # Python — stateful cache
  ├─ partition/                         # Python — partition algorithms
  └─ workload_estimator/                # Python — heuristics

.claude/skills/workflow/{skill}/scripts/  # Per-skill bash (optional)
  └─ *.sh
```

**Quy tắc:**
- bash trong `scripts/` hoặc `{skill}/scripts/`
- Python trong `_shared/` (shared) hoặc `{skill}/_internal/` (private)

---

## 3. Case study

### 3.1. CI detection — bash (đúng chọn)

```bash
# .claude/scripts/ci-detect.sh — ~150 dòng bash
# Task: filesystem check + jq parse + lock acquire
# → bash phù hợp: file ops natural, jq inline OK
```

**Tại sao bash:**
- Filesystem heavy (lock files, cache)
- Single-purpose, no complex algorithm
- Run trên Linux/macOS/WSL bash đều OK

### 3.2. ISG (Impact Surface Graph) — Python (đúng chọn)

```python
# .claude/skills/workflow/_shared/isg/
#   ├─ graph.py        — graph data structure
#   ├─ builder.py      — build graph from code
#   ├─ ripple.py       — BFS ripple analysis
#   └─ tests/          — pytest
# Task: graph traversal, semantic analysis
# → Python phù hợp: data structures + algorithm
```

**Tại sao Python:**
- BFS/DFS traversal phức tạp
- Need test coverage (pytest)
- Cross-platform requirement
- Algorithm có thể evolve

### 3.3. wf-add-scope helpers — bash (đúng chọn)

```bash
# .claude/skills/workflow/wf-add-scope/scripts/
#   ├─ as-01-validate-args.sh
#   ├─ as-02-check-locks.sh
#   ├─ as-03-init-session.sh
#   ├─ ...
#   └─ as-12-finalize.sh
# 12 scripts, mỗi ~50-100 dòng
# Task: orchestration, validation, file ops
# → bash phù hợp: small, focused, file-heavy
```

### 3.4. wf-fix-bugs CDG state machine — Python (đúng chọn)

```python
# .claude/skills/workflow/_shared/cdg/
#   ├─ gate.py         — CDG state machine
#   ├─ registry.py     — decision registry CRUD
#   └─ templates/      — question templates
# Task: state management, registry CRUD
# → Python phù hợp: class-based, schema validation
```

### 3.5. wf-legacy-scan stage-3.sh — REFACTOR CANDIDATE

```bash
# .claude/scripts/legacy-scan-stage-3.sh — 500+ dòng bash
# Task: classify files + build domain hints + multi-pass
# 500 dòng bash → khó maintain
# → Recommend refactor sang Python (Stage 3 v6.0?)
```

**Lesson:** Khi bash >300 dòng → reconsider Python.

---

## 4. Variations / Edge cases

### 4.1. Hybrid — bash gọi Python

```bash
# bash script orchestrate, Python compute
result=$(python3 -m mcv3._shared.isg.ripple --input "$SCOPE")
echo "$result" | jq '.affected_files[]'
```

**OK khi:**
- bash là orchestration layer (file ops)
- Python compute heavy lifting
- Tách trách nhiệm rõ

### 4.2. PowerShell wrapper

```
.claude/scripts/run-devkit-bash.ps1 — wrapper Windows
```

Cho phép Windows users chạy bash scripts qua PowerShell.

### 4.3. Embedded Python trong bash (anti-pattern)

```bash
# ❌ Anti-pattern:
python3 -c "import json; data = json.load(open('x.json')); print(data['key'])"
```

Nếu cần Python logic → tách file `.py` riêng, KHÔNG inline.

### 4.4. Embedded bash trong Python (acceptable)

```python
import subprocess

# Call bash helper for filesystem heavy task
result = subprocess.run(['bash', '.claude/scripts/ci-detect.sh'],
                        capture_output=True, text=True)
data = json.loads(result.stdout)
```

OK — Python gọi bash cho file ops.

---

## 5. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| bash script >500 dòng | Reconsider Python |
| Python utility cho 1 dòng jq | Inline jq trong bash |
| Inline Python multi-line trong bash (`python -c "..."`) | Tách file `.py` |
| 2 implementations cùng task (bash + Python) | Chọn 1, link sang nó |
| bash trên Windows native (không WSL/Git Bash) | Dùng Python hoặc PowerShell wrapper |
| Python script cho task filesystem đơn giản | bash đủ |
| Bash test framework (BATS) cho Python logic | pytest cho Python |
| Stateful logic trong bash (in-memory hash table) | Python hoặc Redis |
| Helper script không có shebang | `#!/usr/bin/env bash` hoặc `#!/usr/bin/env python3` |
| Bash script không có `set -e` (continue on error) | Bắt buộc `set -euo pipefail` |
| Python script không có `if __name__ == "__main__"` | Bắt buộc cho CLI |

---

## 6. Checklist áp dụng

**Trước khi viết utility:**

- [ ] Apply decision tree §2.1
- [ ] Estimate LOC — nếu >300 → Python
- [ ] Cross-platform requirement → Python
- [ ] Algorithm/data structure → Python
- [ ] Filesystem-heavy → bash
- [ ] Cần unit test → Python (pytest)
- [ ] Sẽ run nhiều — performance critical → Python
- [ ] One-off helper → bash

**bash script structure:**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source shared utilities
source "$(dirname "$0")/../_utils.sh"

main() {
  # Logic
}

main "$@"
```

**Python script structure:**

```python
#!/usr/bin/env python3
"""Module docstring."""
import argparse
import json
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    args = parser.parse_args()
    # Logic

if __name__ == "__main__":
    main()
```

**Naming:**
- bash: `kebab-case.sh` (vd: `ci-detect.sh`)
- Python: `snake_case.py` (vd: `impact_graph_builder.py`)

---

## 7. Compliance audit

```bash
# Tìm bash scripts >300 dòng (refactor candidate):
find .claude/scripts .claude/skills -name "*.sh" -exec wc -l {} \; \
  | awk '$1 > 300 { print $0 }'

# Tìm Python utility <30 dòng (overkill?):
find .claude/skills/workflow/_shared -name "*.py" -exec wc -l {} \; \
  | awk '$1 < 30 && $1 > 0 { print $0 }'

# Check shebang:
find .claude/scripts -name "*.sh" -exec head -1 {} \; | sort | uniq -c

# Check set -euo pipefail:
grep -L "set -euo" .claude/scripts/*.sh
```

---

## 8. Liên kết

- **Architecture overview:** [`../01-architecture/`](../01-architecture/)
- **Case study Python:** `.claude/skills/workflow/_shared/`
- **Case study bash:** `.claude/scripts/`
- **Run tests Python:** `.claude/skills/workflow/_shared/run-tests.sh`
- **PowerShell wrapper:** `.claude/scripts/run-devkit-bash.ps1`
- **Related patterns:**
  - [`01-lazy-load-procedures.md`](01-lazy-load-procedures.md) — KHÔNG nhúng bash >10 dòng inline trong procedure
