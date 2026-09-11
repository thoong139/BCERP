# Phase 2: Merge & Deduplicate

> Gộp tất cả `findings-*.json` từ Phase 1 thành 1 master result, áp dụng dedup 2-tier.

**PRE-GATE:** Tất cả findings-*.json từ Phase 1 tồn tại + valid (xem POST-GATE từng wave)

**📤 OUTPUT:** `$SESSION_DIR/audit-scan-result.json` (template: `templates/audit-scan-result.json`)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 2.1 | Glob `$SESSION_DIR/findings-*.json` → list tất cả input files | Glob | files listed |
| 2.2 | Đọc từng file, tích lũy `findings[]` arrays vào 1 list `merged_findings` | Read | merged created |
| 2.3 | **Tier 1 dedup:** cùng `file` + cùng `line` + similar `issue` text → giữ severity cao hơn. Ghi entry vào `dedup_log[]` với `tier="tier1"`. Xem `_shared.md` §Dedup Rules. | - | tier1 deduped |
| 2.4 | **Tier 2 dedup:** cùng `file` + cùng `criterion_group` (khác `criterion` ID) → giữ severity cao hơn (tie-break: `category=functional`). Ghi `tier="tier2"`. | - | tier2 deduped |
| 2.5 | Sort findings: CRITICAL → MAJOR → MINOR (within each: by file path) | - | sorted |
| 2.6 | Classify: confirm `fix_type` (AUTO|MANUAL) cho mỗi finding dựa trên `fix_proposal` text (heuristic: "thêm", "sửa thành", "đổi" → AUTO; "cần review", "manual" → MANUAL) | - | classified |
| 2.7 | Compute summary: count `critical`, `major`, `minor`, `auto_fixable`, `manual`, `total` | - | summary done |
| 2.8 | **Build audit-scan-result.json từ template:** READ `templates/audit-scan-result.json` → REPLACE `{{SESSION_ID}}`, `{{TIMESTAMP_ISO}}`, `{{SCOPE}}` → SET `source_files = [tên các findings-*.json đã merge]` → SET `findings = sorted_deduped_list` → SET `dedup_log = [...]` → SET `summary = {...}`. WRITE `$SESSION_DIR/audit-scan-result.json` | Read+Write | file created |
| 2.9 | Validate JSON: `node -e "JSON.parse(...)"` | Bash | OK |
| 2.10 | Verify: `summary.total == findings.length`. Verify: `source_files[]` count khớp số findings-*.json files trong session | Read | counts match |
| 2.11 | UPDATE `scan-status.json`: `phase_2_merge.status = "completed"`, `metrics.total_findings = summary.total` | Edit | status updated |

---

## Dedup Examples

**Tier 1 — same file, same line:**
```
F-AGT-001: agents/business/sales-expert.md:15, criterion=A4, severity=CRITICAL, "Knowledge path missing"
F-XRF-015: agents/business/sales-expert.md:15, criterion=XREF-1, severity=MAJOR, "Reference broken"
→ KEEP F-AGT-001 (higher severity), REMOVE F-XRF-015. Log tier1.
```

**Tier 2 — same file, same criterion_group:**
```
F-SKL-001: skills/wf-design/SKILL.md, criterion=S2, group=contract, severity=MAJOR, "_contract.json out of sync"
F-XRF-022: skills/wf-design/SKILL.md, criterion=S11, group=contract, severity=MAJOR, "cross_skill_contracts incomplete"
→ Both same group "contract", same severity. KEEP S2 (functional category) > S11. Log tier2.
```

---

## Edge Cases

- **No findings ở bất kỳ file nào (PASS hoàn hảo):** `merged_findings = []`, `summary.total = 0`, `dedup_log = []`. WRITE file vẫn cần thiết.
- **1 file invalid JSON:** Skip file đó, log E008 WARNING vào status, continue merge các file khác.
- **Focused mode (`--skill=<name>`):** chỉ có 1 input file `findings-skills-focused.json` → skip dedup (không có conflict), chỉ wrap vào schema.

---

## POST-GATE

- `$SESSION_DIR/audit-scan-result.json` tồn tại + JSON valid
- `dedup_log[]` present (có thể empty)
- `summary.total == length(findings[])`
- `source_files[]` liệt kê đúng tất cả input files có trong session
- `scan-status.json.phases.phase_2_merge.status == "completed"`

---

## Cross-references

- Dedup rules: `_shared.md` §Dedup Rules (2-tier)
- Schema: `templates/audit-scan-result.json`
- Next phase: `phase3-summary.md`
