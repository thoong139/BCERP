# Finding Summary — {FEAT-ID}: {Feature Name}

> Generated: {date} | Session: {SESSION_ID} | wf-e2e-finding v1.0.0 | Status: completed

## Trạng thái 8 Findings

| Finding | File | Size | Key Stats | Status |
|---------|------|------|-----------|--------|
| Business Understanding | `findings/business-understanding.md` | {size} bytes | {N} actors, {N} flow steps | OK / WARN |
| Business Rule Catalog | `findings/business-rule-catalog.md` | {size} bytes | {N} BRs, {N} CFVs | OK / WARN |
| State Machine | `findings/state-machine.md` | {size} bytes | {N} states, {N} transitions / N/A | OK |
| Cross-Module Map | `findings/cross-module-map.md` | {size} bytes | {N} deps, {N} events / N/A | OK / WARN |
| DB Mapping | `findings/db-mapping.md` | {size} bytes | {N} tables, {N} migrations | OK / WARN |
| DB Seed Data | `findings/db-seed-data.md` | {size} bytes | {N} INSERT records | OK |
| API Mapping | `findings/api-mapping.md` | {size} bytes | {N} endpoints | OK / WARN |
| UI Mapping | `findings/ui-mapping.md` | {size} bytes | {N} pages, {N} hooks / N/A | OK |

---

## CDG-NEW-02: Cross-Module Dependency Warnings

{Danh sách deps chưa implement — hoặc "Không có warnings"}

| Dependency FEAT-ID | Module | impl_status | Risk |
|-------------------|--------|-------------|------|
| {FEAT-DEP-NNN} | {module} | not_started / in_progress | HIGH / MEDIUM |

---

## SSOT JSONs Khởi Tạo (rỗng — F1 sẽ APPEND)

| File | Trạng thái | Consume bởi |
|------|-----------|-------------|
| `issues.json` | Rỗng (`signals: []`) | F1 APPEND, F6 UPDATE |
| `block-test.json` | Rỗng (`blocked_tests: []`) | F1 APPEND, F3 UPDATE |
| `implement-required.json` | Rỗng (`entries: []`) | F1 APPEND, F4 UPDATE |
| `manual.json` | Rỗng (`entries: []`) | F1 APPEND, report-only |

---

## Tóm Tắt Business

**Feature:** {FEAT-NAME}
**Module:** {MODULE_ID}
**System:** {SYSTEM_ID}
**Business Rules:** {N} BRs
**State Machine:** {N states / N/A}
**Cross-Module:** {N events / N/A}
**DB Tables:** {N}
**API Endpoints:** {N}
**UI Pages:** {N / N/A}

---

## Sẵn Sàng Cho wf-e2e-test (F1)

F0a đã hoàn tất phân tích. wf-e2e-test (F1) consume findings này làm context cho:
- **Phase 2 DB**: consume `db-mapping.md` + `db-seed-data.md` → LIVE-TEST DB
- **Phase 3 API**: consume `api-mapping.md` → LIVE-TEST API
- **Phase 4 UI**: consume `ui-mapping.md` → static UI analysis
- **Phase 5 Integration**: consume `cross-module-map.md` → integration test

Lệnh tiếp theo: `/wf-e2e-test {FEAT-ID} --session={SESSION_ID}`
