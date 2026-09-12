# Procedure: Phase 1 ANALYZE — wf-test-business-workflow

## PRE-GATE

`test -f $SESSION_DIR/test-status.json && WF analysis_status=pending`

## Step 1.1 — Parse WF Spec

```
1. Đọc .mc-data/docs/phase1-business/workflows/{WF-id}-*.md (16 sections §1-§16)
2. Chạy: python -X utf8 scripts/parse-workflow-spec.py "{WF-id}-*.md path" \
         "$SESSION_DIR/workflows/{WF-id}-analysis-raw.json"
   Parser trích sections §1-§16 + fields chính:
   - §3 Actors (bảng actor → vai → quyền)
   - §7 Steps (bảng bước → hệ thống → hành động → expected)
   - §8 State machine (valid transitions)
   - §9 Business rules (BR-WF{xx}-{NN})
   - §11 SLA (timing constraints)
   - §15 E2E test scenarios (Happy / Edge / Negative, TC-NN)
   NẾU script fail (encoding/structure lạ) → manual parse fallback, ghi chú trong analysis.
3. Cross-ref naming-alignment-matrix.md (nếu tồn tại) → check endpoint aliases
```

## Step 1.2 — Resolve Test Accounts

```
Actor từ §3 → map sang test account (đọc $TEST_ACCOUNTS_PATH nếu có để override):
  Sales/CRM actor   → sales.manager@<domain> / config trong test accounts
  Finance actor     → finance.manager@<domain>
  Warehouse actor   → warehouse.manager@<domain>
  Admin actor       → company.admin@<domain>
  System Admin      → sysadmin@<domain>
  Customer          → customer test account (nếu có endpoint customer-facing)

⚠ MCV3/BCERP: credentials THẬT nằm trong test accounts file hoặc machine config —
KHÔNG hardcode password trong analysis file (giữ placehold {ACCOUNT}/{PASSWORD}).
```

## Step 1.3 — Naming Gap Check

```
NẾU naming-alignment-matrix.md tồn tại:
  - Đọc MAJOR gaps liên quan WF này
  - NẾU WF dùng endpoint có MAJOR gap → E005: log warning, hỏi user có muốn test không
  - MINOR gaps: log, continue (test sẽ reveal actual state)
```

## Step 1.4 — Sinh Workflow Analysis

```
Sinh SESSION_DIR/workflows/{WF-id}-analysis.md từ templates/workflow-analysis.template.md:
  - Actors + test accounts
  - Test plan (Happy / Edge / Negative từ §15)
  - Systems & endpoints (cross-validated)
  - State machine transitions
  - Business rules → assertions
  - SLA → timing checks
```

## POST-GATE

`test -f $SESSION_DIR/workflows/{WF-id}-analysis.md && size > 100 bytes`
→ Update test-status.json: `workflows.{WF-id}.analysis_status = "done"`, `next_action = "test_pending"`
