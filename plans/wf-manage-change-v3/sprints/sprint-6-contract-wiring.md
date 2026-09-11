# Sprint 6: SKILL.md + Contract + Cross-Skill Wiring

> **Estimate:** 1.5h
> **Phụ thuộc:** S3 (change-impact.json), S5 (phase updates)
> **Solves:** Cross-skill integration, _contract.json sync
> **PR Group:** PR #3

---

## Mục tiêu

Update SKILL.md, _contract.json, và `00-core.md` §4b để sync với tất cả thay đổi v3.0. Wire cross-skill contracts cho change-impact.json consumers.

## Deliverables

### 6.1 SKILL.md Update

| Section | Thay đổi |
|---------|----------|
| Version | `2.0.3` → `3.0.0` |
| Output Files table | Thêm `change-impact.json` (template: `templates/change-impact.json`) |
| Output Files table | Update `phase-summary.md` template: `null` → `templates/phase-summary.md` |
| Protocols | Thêm Protocol 16, 17, 18 |
| Related Skills | Thêm "consumes change-impact.json" note cho wf-verify-sync, wf-preflight |
| Design Rationale | Thêm "v3.0: Bash delegation, Lock/Heartbeat, change-impact.json" |

### 6.2 _contract.json Update

| Field | Thay đổi |
|-------|----------|
| `version` | `2.0.3` → `3.0.0` |
| `outputs.working[]` | Thêm entry cho `change-impact.json` (template: `templates/change-impact.json`) |
| `outputs.working[]` | Update `phase-summary.md` template: null → `templates/phase-summary.md` |
| `cross_skill_contracts.produces_for` | Thêm entries cho wf-verify-sync, wf-preflight, wf-implement-feature với `change-impact.json` path |
| `registry_scope.fields_owned` | Giữ nguyên (requirements, features, impl_status) |
| `changelog` | Thêm v3.0.0 entry |

### 6.3 00-core.md §4b Update

Thêm 3 entries vào Cross-Skill Output Path Contract table:

```markdown
| `/wf-manage-change` Phase 6 | `$SESSION_DIR/change-impact.json` (schema change-impact-v1: 8 base fields + verify_evidence + regression_check + audit_chain) | **WIRED CONSUMERS:** `/wf-verify-sync --from-manage-change[=<id>]` v2.1.0+ (Phase 0 load + Phase 5 cross-check `registry_changes[]` + Phase 6 section "Change Impact Cross-Reference"); `/wf-preflight` (inform — scope affected files); `/wf-implement-feature` v4.1.0+ (Phase 0 context priming — files_modified cross-check). Generator: `scripts/wf-manage-change/mc-change-impact-build.sh`. Backward compat: producer graceful degrade (builder fail → log WARN, KHÔNG block POST-GATE); consumer graceful (file missing → no-op). |
| `/wf-manage-change` Session | `_index/sessions.jsonl` (append-only JSONL — concurrent-safe session index) | Internal — session lookup, `--status` display. Dual-write với `index.json` cho human-readable display. |
| `/wf-manage-change` Session Lock | `$SESSION_DIR/.session.lock` + `.locks/registry.lock` (PID/host/user/heartbeat) | Internal — multi-developer safety. Stale detection 60min. Cross-host detection. |
```

### 6.4 evals.json Update

Thêm 3 evals mới:

**Eval #16: lock-acquire-release**
```json
{
  "id": 16,
  "name": "lock-acquire-release",
  "prompt": "Thay doi gia tri thue VAT tu 10% sang 8% cho module Hoa don.",
  "expected_output": "Skill acquire session lock o Phase 0 Step 0.0. Heartbeat running. Registry lock acquire truoc Phase 4a.5. Release sau write. Phase 6 release session lock.",
  "assertions": [
    {"type": "behavior", "text": "Phase 0 Step 0.0 acquire session lock — .session.lock file ton tai"},
    {"type": "behavior", "text": "Registry lock acquire truoc Phase 4a.5 — .locks/registry.lock ton tai trong khi update"},
    {"type": "behavior", "text": "Registry lock release sau Phase 4a.5 — .locks/registry.lock khong ton tai sau khi write xong"},
    {"type": "behavior", "text": "Phase 6 release session lock — .session.lock khong ton tai sau session complete"}
  ]
}
```

**Eval #17: change-impact-json-output**
```json
{
  "id": 17,
  "name": "change-impact-json-output",
  "prompt": "Thay doi cach tinh phi don hang — them phi van chuyen theo khoang cach.",
  "expected_output": "change-impact.json duoc tao o Phase 6. Co day du 8 base fields. Co audit_chain checksum.",
  "assertions": [
    {"type": "file_exists", "text": "File $SESSION_DIR/change-impact.json duoc tao"},
    {"type": "content_check", "text": "change-impact.json co $schema = change-impact-v1"},
    {"type": "content_check", "text": "change-impact.json co change_id khop voi session"},
    {"type": "content_check", "text": "change-impact.json co audit_chain.checksum_pre va checksum_post"},
    {"type": "content_check", "text": "change-impact.json co registry_changes section"},
    {"type": "content_check", "text": "change-impact.json co files_modified array"}
  ]
}
```

**Eval #18: sessions-jsonl-append**
```json
{
  "id": 18,
  "name": "sessions-jsonl-append",
  "prompt": "Bo sung thong tin cho REQ-INVENTORY-002 — ap dung cho kho mien Bac.",
  "expected_output": "sessions.jsonl co entry khi session bat dau. Co entry completed khi session ket thuc.",
  "assertions": [
    {"type": "behavior", "text": "_index/sessions.jsonl co entry voi change_id cua session"},
    {"type": "content_check", "text": "Entry trong sessions.jsonl co status=in_progress khi session bat dau"},
    {"type": "content_check", "text": "Entry completed duoc append khi session ket thuc thanh cong"},
    {"type": "behavior", "text": "index.json dong bo voi sessions.jsonl (dual-write)"}
  ]
}
```

## Acceptance Criteria

| # | Criteria | Verify bằng |
|---|----------|-------------|
| AC1 | SKILL.md version = 3.0.0 | `grep "version:" SKILL.md` (frontmatter) |
| AC2 | _contract.json version = 3.0.0 | `jq '.version' _contract.json` |
| AC3 | _contract.json có change-impact.json trong outputs.working | `jq '.outputs.working[] \| select(.path \| contains("change-impact"))' _contract.json` |
| AC4 | _contract.json phase-summary.md template != null | `jq '.outputs.working[] \| select(.path \| contains("phase-summary")) \| .template' _contract.json` |
| AC5 | 00-core.md §4b có 3 entries mới cho wf-manage-change | `grep "wf-manage-change.*change-impact" 00-core.md` |
| AC6 | evals.json có 18 entries (15 cũ + 3 mới) | `jq '.evals \| length' evals.json` |
| AC7 | skill-compliance-audit.sh wf-manage-change PASS | `./.claude/scripts/skill-compliance-audit.sh wf-manage-change` |
| AC8 | validate-schema-sync.sh wf-manage-change PASS | `./.claude/scripts/validate-schema-sync.sh wf-manage-change` |

## Risks

| Risk | Mitigation |
|------|------------|
| 00-core.md §4b thay đổi ảnh hưởng skills khác | Thêm entries mới (additive) — không modify existing entries |
| _contract.json schema thay đổi → audit fail | Chạy validate-schema-sync.sh ngay sau update |

## Definition of Done

- [ ] SKILL.md bump 3.0.0 + updates
- [ ] _contract.json bump 3.0.0 + 2 new output entries + produces_for update
- [ ] 00-core.md §4b có 3 entries mới
- [ ] evals.json có 18 entries
- [ ] skill-compliance-audit.sh PASS
- [ ] validate-schema-sync.sh PASS
- [ ] AC1-AC8 pass
