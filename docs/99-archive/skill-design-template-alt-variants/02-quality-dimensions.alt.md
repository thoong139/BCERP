<!--
_template_notes:
  purpose: VARIANT cho Lane/Probe skill — thay thế 02-arguments.md.
  populate:
    - §1 Bảng quality dimensions: ID, tên, scope, severity threshold
    - §2 Probe definitions: 1 row/probe với input, detection logic, output schema
    - §3 Probe activation per profile (quick/standard/deep/exhaustive)
    - §4 Cross-dimension dependencies (probe X cần output probe Y)
    - §5 Severity scoring + thresholds
  Áp dụng: Lane/probe skills (wf-fix-functional, wf-fix-security, wf-fix-performance, ...)
  KHÔNG dùng cho: orchestrator skills (wf-fix-bugs)
  độ dài tham khảo: 200-400 dòng
  Khi dùng file này, ĐỔI TÊN thành 02-quality-dimensions.md (xóa .alt)
-->

# 02 — Quality Dimensions (Lane/Probe Variant)

> **Mục đích file:** Đặc tả các chiều chất lượng (quality dimensions) skill `{skill-name}` kiểm tra. Mỗi dimension thể hiện qua 1+ probes có logic phát hiện riêng.

---

## 1. Quality dimensions overview

| QD ID | Tên dimension | Scope | Severity threshold | Probes count |
|-------|--------------|-------|---------------------|--------------|
| QD{X}.1 | {Dimension 1} | Code-level | CRITICAL/HIGH/MEDIUM/LOW | {N} probes |
| QD{X}.2 | {Dimension 2} | Module-level | HIGH/MEDIUM | {N} probes |
| QD{X}.3 | {Dimension 3} | System-level | CRITICAL | {N} probes |

**Owner:** {role} (e.g. `frontend-developer + qa-lead`)
**Lane ID:** QD{X} (khớp với lane ID trong wf-fix-bugs orchestrator)

---

## 2. Probe definitions

### Probe QD{X}.1.1 — {Tên probe}

| Trường | Giá trị |
|--------|---------|
| **Mục đích** | {1 câu mô tả phát hiện gì} |
| **Input** | {file/state cần đọc} |
| **Detection logic** | {mô tả ngắn — Grep pattern, AST parse, runtime check, ...} |
| **Output schema** | `{schema-vN}` |
| **Output path** | `$SESSION_DIR/lane-QD{X}/probes/QD{X}.1.1.json` |
| **CI tool route** | Primary: GitNexus impact / Serena find_refs / Playwright runtime — Fallback: Grep |
| **Severity mapping** | CRITICAL nếu {condition}, HIGH nếu {...}, MEDIUM nếu {...} |
| **Auto-fix capable** | YES/NO. Nếu YES, fix strategy: {description} |
| **Time estimate** | {seconds} per file scanned |

**Output schema chi tiết:**
```json
{
  "$schema": "QD{X}-1-1-v1",
  "probe_id": "QD{X}.1.1",
  "findings": [
    {
      "severity": "CRITICAL|HIGH|MEDIUM|LOW",
      "file": "path/to/file.ts",
      "line": 42,
      "rule": "rule-id",
      "message": "Mô tả vấn đề tiếng Việt",
      "evidence": "snippet code/state",
      "fix_hint": "Cách sửa gợi ý"
    }
  ],
  "summary": {
    "total_findings": 0,
    "by_severity": {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
  }
}
```

### Probe QD{X}.1.2 — {Tên probe khác}

{... lặp cho mỗi probe ...}

---

## 3. Probe activation per profile

| Probe | quick | standard | deep | exhaustive |
|-------|-------|----------|------|-----------|
| QD{X}.1.1 | ✅ | ✅ | ✅ | ✅ |
| QD{X}.1.2 | ❌ | ✅ | ✅ | ✅ |
| QD{X}.2.1 | ❌ | ❌ | ✅ | ✅ |
| QD{X}.3.1 | ❌ | ❌ | ❌ | ✅ |

**Quy tắc:**
- `quick`: chỉ probe critical-fast (<5s)
- `standard`: + probes business-relevant
- `deep`: + LLM-assisted probes
- `exhaustive`: + runtime/Playwright probes (chậm nhưng comprehensive)

---

## 4. Cross-dimension dependencies

| Probe | Depends on probe | Reason |
|-------|------------------|--------|
| QD{X}.2.1 | QD{X}.1.1 output | Cần list files có vấn đề từ probe trước |
| QD{X}.3.1 | QD{X}.1.1 + QD{X}.2.1 | Aggregated severity across modules |

**Topology:** Probes chạy theo topological sort — dependencies trước, dependents sau. Trong cùng level: parallel.

---

## 5. Severity scoring & thresholds

### Severity definitions

| Severity | Khi nào | Action recommended |
|----------|---------|---------------------|
| **CRITICAL** | Bug ảnh hưởng prod / data loss / security breach | Block deployment, fix ngay |
| **HIGH** | Functional issue, UX degradation rõ rệt | Fix trước release |
| **MEDIUM** | Improvement opportunity | Fix trong sprint |
| **LOW** | Nice-to-have, code smell | Backlog |

### Lane PASS/FAIL threshold

| Threshold | Profile quick | Profile standard | Profile deep |
|-----------|---------------|------------------|--------------|
| Lane PASS nếu | 0 CRITICAL | 0 CRITICAL + ≤2 HIGH | 0 CRITICAL + 0 HIGH |
| Lane WARN nếu | 0 CRITICAL + ≤3 HIGH | ≤1 HIGH | ≤2 MEDIUM |
| Lane FAIL nếu | ≥1 CRITICAL hoặc ≥4 HIGH | ≥1 CRITICAL hoặc ≥3 HIGH | ≥1 CRITICAL hoặc ≥1 HIGH |

---

## 6. Cross-skill consumer (orchestrator)

Skill này được spawn bởi **wf-fix-bugs** ở Phase 1 (Lane Dispatch). Output tổng hợp:

```json
{
  "$schema": "lane-QD{X}-summary-v1",
  "lane_id": "QD{X}",
  "lane_status": "PASS|WARN|FAIL",
  "probes_run": ["QD{X}.1.1", "QD{X}.1.2", ...],
  "total_findings": {N},
  "by_severity": {"CRITICAL": 0, "HIGH": 0, ...},
  "audit_chain": {
    "source": "$SESSION_DIR/lane-QD{X}/...",
    "checksum": "sha256"
  }
}
```

Orchestrator dùng output này để aggregate signals + dispatch wf-fix-triage.

---

## 7. Liên kết

- Orchestrator design: [`../wf-fix-bugs/03-architecture.md`](../wf-fix-bugs/03-architecture.md) — lane dispatch logic
- Pattern: [`../../03-design-patterns/04-parallel-lane-dispatch.md`](../../03-design-patterns/04-parallel-lane-dispatch.md)
- Standard probe schema: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md)
- Real example: [`../wf-fix-bugs/02-quality-dimensions.md`](../wf-fix-bugs/02-quality-dimensions.md) — 11 dimensions QD1-QD11
