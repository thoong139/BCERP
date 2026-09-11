# Phase 3: Knowledge Audit (K0-K3 + KG + KP1-7)

> Kiểm tra knowledge files theo TC-K0 đến TC-K3, TC-KG (general), TC-KP (anti-patterns).

## PRE-GATE

- Phase 0 completed (`$SPEC` + `$KNOWLEDGE_TEMPLATE` loaded)
- `$KNOWLEDGE_DIRS[]` và `$KNOWLEDGE_FILES[]` không rỗng
- Scope ∈ {`references`, `full`}

## Steps

### 3.1 — Classify domains (main thread)

| Step | Action | Tool | Output |
|------|-------|------|--------|
| 3.1.1 | Với mỗi domain dir, đếm số agents tham chiếu | Grep `references/team-expert/[domain]` | domain_type mapping |
| 3.1.2 | Classify: Business (1:1), Engineering (N:1), Cross-domain | — | `$DOMAIN_TYPES{}` |

Domain type quyết định audit depth:
- **Business**: Full K0-K3 + KG + KP
- **Engineering/Cross-domain**: chỉ KG + KP (theo `_shared.md §Criteria Detail Tables — Non-business domains`)

### 3.2 — Direct structural checks (K0)

| Step | Check | Tool | Output |
|------|-------|------|--------|
| 3.2.1 | K0.1: personas.md tồn tại trong mỗi business domain | Glob | MAJOR finding nếu thiếu (KP-5) |
| 3.2.2 | K0.2: operations.md HOẶC processes.md | Glob | MAJOR nếu cả 2 đều thiếu |
| 3.2.3 | K0.3: controls.md | Glob | MAJOR nếu thiếu |
| 3.2.4 | TC-KG: Header `Domain:` + `Last Updated:` | Grep | MINOR nếu thiếu (KP-2) |
| 3.2.5 | TC-KG: Kích thước ≤400 dòng | `wc -l` | MAJOR nếu vượt (KP-3) |

### 3.3 — Spawn `agent-auditor` cho content checks (K1-K3, KP)

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.3.a | Chia files thành batches theo domain (1 batch = 1 domain) | — | — |
| 3.3.b | Spawn agent-auditor với Template Phase 3 (xem `_shared.md §Auditor Prompt Templates`) | Agent | JSON response |
| 3.3.c | Checks: K1 (personas content), K2 (operations content), K3 (controls content), KP-1 (behavioral language), KP-6 (abstract facts), KP-7 (mixed topics) | — | — |
| 3.3.d | Parse JSON → append `$SESSION_DIR/findings-knowledge.json` | Write | jq valid |

### 3.4 — KP-1 Behavioral language scan (main thread, song song)

| Step | Action | Tool | Output |
|------|--------|------|--------|
| 3.4.1 | Grep tất cả knowledge files cho behavioral keywords: "bạn nên", "bạn phải", "luôn luôn", "không bao giờ", "PHẢI", "CẤM", "LUÔN" | Grep | MAJOR finding per file with matches (KP-1) |

### 3.5 — KP-4 Orphan detection (deferred cho Phase 4)

Orphan detection cần cross-reference agents ↔ knowledge → deferred cho Phase 4 (cross-ref). Phase 3 chỉ ghi chú danh sách files cần check, không tạo finding.

## POST-GATE

- `findings-knowledge.json` tồn tại và valid JSON array
- Tất cả knowledge domains trong scope đã check
- Files >400 dòng đã flag
- Behavioral language violations identified
- Orphans deferred (Phase 4 sẽ xử lý)
- Append `phase3-knowledge` vào `completed_phases[]`

## Routing sau Phase 3

Đọc `pending_phases[0]`:

| Next | Load |
|------|------|
| `phase4-crossref` | `procedures/phase4-crossref.md` |
| `phase5-report` | `procedures/phase5-report.md` |

## Errors liên quan

- **E006** — Sub-agent timeout → Retry ×3
- **E009** — Knowledge domain không map 1:1 với agent → Log MINOR (multi-agent domain), continue
- **E011** — Agent trả text thay JSON → Fallback parse

Chi tiết: `_shared.md §Error Handling Reference`.
