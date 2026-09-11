# Shared Protocols — audit-devkit-scan

> Cross-cutting protocols dùng bởi nhiều phase (Phase 0–3) và 5 waves trong Phase 1.
> KHÔNG load file này standalone — chỉ load section cụ thể khi cần.

## Sections

- [Auditor Prompt Template](#auditor-prompt-template)
- [Criteria Catalog](#criteria-catalog) — S1–S15 cho skill scan, A1–A6 cho agent scan
- [Severity Mapping](#severity-mapping)
- [Batching Strategy](#batching-strategy)
- [Fix Rules (skill-specific)](#fix-rules-skill-specific)
- [Error Handling Codes (E001–E011)](#error-handling-codes)
- [Findings JSON Build Helper](#findings-json-build-helper)
- [Dedup Rules (2-tier)](#dedup-rules-2-tier)
- [Session Lock & Heartbeat](#session-lock--heartbeat)

---

## Auditor Prompt Template

> Mọi agent batch (Wave 1, 2, 3 templates+rules) PHẢI nhận prompt theo format chuẩn dưới đây để output đồng nhất schema `audit-findings-v1`.

```
Bạn là [auditor-type — agent-auditor | skill-auditor | template-auditor].
Audit các files sau:
[danh sách file paths từ audit-index.json, ≤20 files]

Kiểm tra theo criteria: [criteria list — VD: A1-A6 cho agents | S1-S15 cho skills | T1-T5 cho templates]

OUTPUT FORMAT (BẮT BUỘC — JSON):
Trả về KẾT QUẢ dạng JSON array. Mỗi finding là 1 object:
{
  "id": "F-[TYPE]-[NNN]",        // F-AGT-001, F-SKL-001, F-TPL-001
  "severity": "CRITICAL|MAJOR|MINOR",
  "component": "agent|skill|template|rule|hook|script|reference",
  "file": "[path]",
  "line": [number or null],
  "criterion": "[criterion ID — VD A6 hoặc S2]",
  "category": "functional|structural",
  "criterion_group": "[group — VD: frontmatter, contract, phase, crossref, path-alignment, quality]",
  "issue": "[mô tả cụ thể]",
  "fix_type": "AUTO|MANUAL",
  "fix_proposal": "[đề xuất fix cụ thể]",
  "evidence": "[bằng chứng — Glob/Grep result]"
}

QUY TẮC:
- KHÔNG trả kết quả text. CHỈ JSON array.
- Chỉ report items có issues. Items PASS không cần report.
- Nếu không có issue nào → trả `[]` (array rỗng).
- Tuân theo Severity Mapping bên dưới.
```

---

## Criteria Catalog

### Skill Criteria (S1–S15) — dùng bởi `skill-auditor` (Wave 2)

| ID | Mô tả | Category | criterion_group |
|----|-------|----------|-----------------|
| S1 | Frontmatter completeness: name, version, description, argument-hint, allowed-tools, TRIGGER/KHÔNG TRIGGER | structural | frontmatter |
| S2 | _contract.json sync: tồn tại, $schema đúng, fields khớp SKILL.md | functional | contract |
| S3 | Phase structure: PRE-GATE + EXECUTION + POST-GATE | functional | phase |
| S4 | Shared protocols reference (workflow skills) | structural | phase |
| S5 | Registry Safe-Write nếu skill update registry | functional | contract |
| S6 | Cross-skill referenced paths tồn tại | functional | crossref |
| S7 | evals/ directory với ≥3 test cases | structural | quality |
| S8 | Template references tồn tại | functional | crossref |
| S9 | POST-GATE có T1 check minimum | functional | phase |
| S10 | Error handling section/codes | structural | quality |
| S11 | Cross-skill contract completeness: `cross_skill_contracts.produces_for/consumes_from` phản ánh đúng relationship | functional | contract |
| S12 | Output path alignment: paths trong SKILL.md xuất hiện trong `00-core.md §4b` | functional | path-alignment |
| S13 | LEGACY_MODE handling: CORE-021 detection pattern (`project-context.md > 500 bytes`) + CORE-022 legacy-decisions.json enforcement + graceful degradation khi file không tồn tại | functional | contract |
| S14 | Procedure field pattern: `_contract.json` có `procedures` field với canonical format (flat array hoặc object với `shared` + `phases` keys), path resolve được, entry file tồn tại trên disk | functional | contract |
| S15 | Template resolution: `outputs.working[].template` path tồn tại trong `doc-framework/` hoặc skill-local `templates/`, hoặc `null` với `notes` giải thích lý do không có template | functional | crossref |

### Agent Criteria (A1–A6) — dùng bởi `agent-auditor` (Wave 1)

| ID | Mô tả | Category | criterion_group |
|----|-------|----------|-----------------|
| A1 | Frontmatter: name, description, allowed-tools | structural | frontmatter |
| A2 | Knowledge sections: domain expertise đầy đủ | structural | quality |
| A3 | Procedures references: `.claude/agents/procedures/[name]/*.md` tồn tại nếu được link | functional | crossref |
| A4 | Knowledge file references: `.claude/references/team-expert/[domain]/*.md` tồn tại | functional | crossref |
| A5 | Output format definition rõ ràng | structural | quality |
| A6 | Cross-references đến skills/agents khác hợp lệ | functional | crossref |

### Template Criteria (T1–T5) — dùng bởi `template-auditor` (Wave 3)

| ID | Mô tả | Category | criterion_group |
|----|-------|----------|-----------------|
| T1 | Heading structure đúng phase convention | structural | quality |
| T2 | Required placeholders `{{...}}` documented | structural | quality |
| T3 | Cross-references đến rules/skills hợp lệ | functional | crossref |
| T4 | Phase folder đúng convention `phaseN-name/PN-NN-...md` | structural | path-alignment |
| T5 | Đồng bộ với `_contract.json` của producer skill | functional | contract |

---

## Severity Mapping

| Severity | Khi nào dùng |
|----------|--------------|
| **CRITICAL** | Functional broken: missing required field, broken cross-ref, contract mismatch khiến downstream skill fail. |
| **MAJOR** | Functional incomplete: criteria fail nhưng không block downstream (VD: thiếu evals, missing optional field). |
| **MINOR** | Structural/cosmetic: naming convention, formatting, optional field warning. |

> Quy tắc: nếu issue làm `audit-devkit-fix` không thể auto-fix → severity ít nhất là MAJOR.

---

## Batching Strategy

| Batch size | Checks/batch | Context usage | Accuracy |
|------------|--------------|---------------|----------|
| 58 (cũ) | 580 checks | ~80% | Thấp — findings cuối shallow |
| 30 | 300 checks | ~50% | Trung bình |
| **20** | **200 checks** | **~35%** | **Cao — đủ context cho deep analysis** |
| 10 | 100 checks | ~20% | Rất cao nhưng quá nhiều spawns |

**Chọn ≤20 files/batch:** cân bằng accuracy vs số agent spawns.

**Auto-split rule (E005):** nếu batch > 20 files → chia thành 2 sub-batches ≤10 mỗi nửa.

---

## Fix Rules (Skill-specific)

| Error Type | Auto-Fix Strategy | Escalate If |
|------------|-------------------|-------------|
| Findings JSON parse fail | Fallback parse text → JSON | Parse fail sau 2 lần thử |
| Agent timeout/không trả output | Re-spawn agent 1 lần | Fail lần 2 |
| Agent context overflow | Auto-split: chia batch thành 2 sub-batches ≤10, retry mỗi nửa. Ghi `metrics.split_events += 1` | Cả 2 nửa đều fail → report PARTIAL |
| Batch output > context limit | Giảm batch size xuống 10 | Vẫn overflow |
| Ground truth index invalid | Re-glob và rebuild | Counts vẫn = 0 |
| >3 batches fail liên tiếp | **Circuit breaker:** PAUSE → set `metrics.circuit_breaker_triggered = true` → hỏi user "Tiếp tục với partial results hay STOP?" | User chọn STOP |
| `--skill=<name>` không tồn tại | Glob `.claude/skills/**/[name]/SKILL.md` + suggest closest match | Không tìm thấy match nào |
| `--since=<commit>` returns 0 files | INFO: "Không có files thay đổi từ <commit>" → tạo empty scan result + skip Phase 1 | User muốn force full scan |

---

## Error Handling Codes

> **Error code prefix:** SCAN- (VD: SCAN-E001, SCAN-E002). Dùng khi log/display để phân biệt với errors từ verify/fix/orchestrator.

| Code | Situation | Action |
|------|-----------|--------|
| E001 | PRE-GATE fail (`.claude/` không tồn tại) | STOP — không phải DEVKIT project |
| E002 | POST-GATE fail (JSON invalid) | Retry: rebuild JSON (tối đa 3 lần) |
| E003 | Agent timeout / không trả output | Re-spawn agent 1 lần, sau đó skip batch + WARNING |
| E004 | Agent trả text thay vì JSON | Fallback parse: extract JSON từ text. Nếu fail → log raw text + MANUAL review |
| E005 | Batch > 20 files | Split batch thành 2 sub-batches ≤10 |
| E006 | Ground truth counts = 0 | Re-glob với expanded patterns. Nếu vẫn 0 → STOP (DEVKIT structure invalid) |
| E007 | File write fail (permission/disk) | Retry 3 lần, sau đó escalate to user |
| E008 | findings-*.json missing sau Phase 1 | Re-run missing batch. Nếu vẫn fail → partial merge với WARNING |
| E009 | Dedup conflict (không rõ giữ finding nào) | Giữ finding có severity cao hơn. Nếu cùng severity → giữ finding có evidence cụ thể hơn |
| E010 | Resume: scan-status.json corrupt | Rebuild status từ existing findings-*.json files |
| E011 | Post-write hook reject findings JSON (validate-contract-sync.sh trigger) | Findings trong `.mc-data/work/audit-devkit-scan/[session]/` không phải project code — hook không nên validate. Workaround: write lại với dummy REQ-ID comment, hoặc whitelist path |
| ARGUMENT_CONFLICT | Cả `--component=X` và `--agents/--skills/...` đều cung cấp | `--component=X` higher priority. Log WARNING. |

---

## Findings JSON Build Helper

> Sau khi auditor agent trả JSON array → SKILL/procedure WRAP vào schema `audit-findings-v1`:

```
1. READ template `templates/findings.json`
2. SET source = "[auditor-type]"
3. SET batch = "[batch-id]" (VD: "agents-business-a")
4. SET scanned_at = NOW (ISO 8601)
5. SET files_scanned = len(file paths được pass cho agent)
6. SET findings[] = JSON array agent trả về
7. COMPUTE summary.{critical, major, minor, total} từ findings[]
8. WRITE `$SESSION_DIR/findings-[batch-id].json`
9. VALIDATE: node -e "JSON.parse(require('fs').readFileSync('...'))"
```

> **Quy tắc CORE-031:** PHẢI READ template trước, KHÔNG generate JSON ad-hoc.

---

## Dedup Rules (2-tier)

> Áp dụng tại Phase 2 sau khi merge tất cả findings-*.json.

**Tier 1 — Same file + same line + same issue type:**
- Detector: cùng `file` + cùng `line` + similar `issue` text (string match >80%)
- Rule: giữ finding có `severity` cao hơn (CRITICAL > MAJOR > MINOR)
- Tie-break: giữ finding có `evidence` dài hơn (cụ thể hơn)

**Tier 2 — Same file + same criterion_group:**
- Detector: cùng `file` + cùng `criterion_group` nhưng khác `criterion` ID, VÀ `issue` text similarity >60% (shared keywords hoặc cùng root cause)
- Rule: giữ finding có `severity` cao hơn
- Tie-break: nếu cùng severity → giữ finding có `category=functional` (vs `structural`)
- Note: Nếu issue text similarity <60% → KHÔNG dedup (khác root cause, giữ cả hai)

**Log format:**
```json
{
  "kept": "F-AGT-001",
  "removed": "F-XRF-015",
  "tier": "tier1",
  "reason": "Same file:line, criterion_group=crossref, both detected by agent-auditor and template-auditor"
}
```

---

## Session Lock & Heartbeat

Để tránh 2 sessions ghi đè cùng folder:

1. **Lock acquire** (Phase 0): tạo `$SESSION_DIR/.lock` chứa `{pid, started_at, heartbeat_at}`
2. **Heartbeat update**: mỗi POST-GATE write `scan-status.json` cũng cập nhật `heartbeat_at = NOW`
3. **Stale detection**: nếu `now - heartbeat_at > 30 min` → coi là stale, có thể overwrite (nhưng cảnh báo user)
4. **Lock release** (Phase 3): xóa `.lock` khi `status = "completed"`

---

## Cross-references

- Schema cho status tracking: `templates/scan-status.json`
- Schema cho findings: `templates/findings.json`
- Schema cho master index: `templates/audit-index.json`
- Schema cho merged result: `templates/audit-scan-result.json`
- Workflow: SKILL.md `Execution Summary` section
