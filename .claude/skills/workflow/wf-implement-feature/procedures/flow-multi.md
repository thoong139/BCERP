# /wf-implement-feature: Multi-Feature & Micro-Task Flows

File này chứa:
1. **Multi-Feature Orchestration** (`--features` flag) — implement nhiều features với scheduling tối ưu
2. **Micro-Task Support** (`--micro-task` flag) — implement từng micro-task của feature phức tạp

Được load bởi SKILL.md khi có `--features` flag.
Được tham chiếu bởi các phase files (phase1-feature-context.md, phase2-planning.md, phase3-tdd.md) cho `--micro-task` logic.

---

## PHẦN 1: Multi-Feature Orchestration (--features flag)

### Mục đích

Khi user muốn implement nhiều features cùng lúc với tối ưu song song:

```bash
/wf-implement-feature --features=FEAT-CRM-CUST-001,FEAT-CRM-ORD-001,FEAT-CRM-DASH-001
```

### Dependency Analysis

**Cách xác định dependencies:**

Đọc task file tương ứng (`.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md`):
- Section A7-EXT: dependencies → xác định feature nào cần output từ feature nào
- Nếu FEAT-002 cần type/entity từ FEAT-001 → FEAT-002 phụ thuộc FEAT-001
- KHÔNG phụ thuộc = independent

**Ví dụ dependency graph:**
```
FEAT-CRM-CUST-001 (Customer CRUD):  Dependencies: []        → Independent
FEAT-CRM-ORD-001  (Order Management): Dependencies: [CUST]  → Phụ thuộc Customer
FEAT-CRM-DASH-001 (Dashboard):      Dependencies: [CUST, ORD] → Phụ thuộc cả hai
```

### Parallel Scheduling

**Quy trình orchestration:**

```
Phase 0: Dependency Analysis
  ├── Parse --features flag → extract FEAT-ID list
  ├── Load specs từ req-registry.json + task files cho từng FEAT-ID
  ├── Build dependency graph (đọc A7-EXT section mỗi task file)
  └── Topological sort → identify parallel batches

Phase 1: Batch Execution
  Với mỗi Batch N (thực hiện song song):
    ├── Session A: /wf-implement-feature FEAT-A [flags]
    ├── Session B: /wf-implement-feature FEAT-B [flags]
    └── Wait: đợi tất cả sessions trong batch hoàn thành

  Batch N+1 (chạy sau Batch N):
    └── Features phụ thuộc Batch N → tiếp tục

Phase 2: Merge & Integration
  ├── Merge code từ tất cả sessions vào develop branch
  ├── Run integration test suite (TOÀN BỘ — không chỉ unit tests)
  ├── Verify cross-feature consistency (types, exports, no circular deps)
  └── Update registry — **ORCHESTRATOR-ONLY SEQUENTIAL WRITE (A3-M5 fix)**:
      Parallel sessions KHÔNG được tự update registry (race condition → lost writes).
      Orchestrator TẬP TRUNG update registry sau khi tất cả sessions hoàn thành:

      ```bash
      for FEAT_ID in "${COMPLETED_FEATURES[@]}"; do
        TMP="$(mktemp .mc-data/docs/_meta/.reg.tmp.XXXXXX)"
        # Narrow per-field update, atomic write per feature
        jq --arg fid "$FEAT_ID" \
          '(.features[] | select(.feat_id == $fid) | .impl_status) = "done"
           | (.requirements[] | select(.req_id | inside([$fid])) | .impl_status) = "done"' \
          .mc-data/docs/_meta/req-registry.json > "$TMP" \
          && mv "$TMP" .mc-data/docs/_meta/req-registry.json \
          || { rm -f "$TMP"; echo "FAIL registry update for $FEAT_ID"; exit 1; }
      done
      # Final validate
      jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
      ```

      Per-session sub-processes CHỈ update `impl-status.json` (per-session file, no conflict).
      Skip Phase 6 registry write trong mỗi session khi chạy multi-feature mode.

Phase 3: Report
  ├── Consolidate impl-report.md từ tất cả sessions
  ├── Ghi parallel timing metrics
  └── Tổng hợp findings → multi-feature-report-$TIMESTAMP.md
```

### Safety Rules (BẮT BUỘC)

**Rule 1: KHÔNG parallel 2 features cùng sửa 1 file**
- Trước khi spawn parallel session, scan scope files của mỗi feature
- Nếu Feature A và B sửa cùng 1 file → sequential, không parallel
- Ví dụ: `src/entities/customer.entity.ts` — nếu 2 features sửa → conflict → sequential

**Rule 2: Dependencies PHẢI khớp reality**
- Task file nói FEAT-B phụ thuộc FEAT-A → FEAT-A PHẢI hoàn thành trước khi FEAT-B submit
- Nếu mismatch (VD: B xong nhưng A vẫn pending) → escalate error

**Rule 3: Integration test MANDATORY**
- Sau merge tất cả sessions → chạy toàn bộ test suite (not just unit tests)
- Verify: types khớp, exports khớp, không có circular deps
- Nếu integration fail → rollback + report detailed findings

**Rule 4: Context isolation per session**
- Mỗi feature implement trong session riêng → không share in-memory state
- Checkpoints per feature, không cross-feature
- Carry-over context CHỈ giữa micro-tasks của CÙNG feature, KHÔNG cross-feature

### Feature-Level Scheduling Examples

**Ví dụ 1: 2 independent features**
```
/wf-implement-feature --features=FEAT-A,FEAT-B
Graph: A → [] | B → []
Execution:
  Session A: FEAT-A (t=0-20 min)   ← song song
  Session B: FEAT-B (t=0-15 min)   ← song song
  Merge + Integration: t=20-25 min
  Total: 25 min (vs 35 min sequential → tiết kiệm 29%)
```

**Ví dụ 2: 3 features, linear dependency**
```
/wf-implement-feature --features=FEAT-A,FEAT-B,FEAT-C
Graph: A → [] | B → [A] | C → [B]
Execution:
  Batch 1: FEAT-A (t=0-20)
  Batch 2: FEAT-B (t=20-35) ← phụ thuộc A
  Batch 3: FEAT-C (t=35-50) ← phụ thuộc B
  Total: 55 min (no parallelism possible)
```

**Ví dụ 3: 4 features, diamond dependency**
```
/wf-implement-feature --features=FEAT-CUST,FEAT-ORD,FEAT-PAY,FEAT-DASH
Graph: CUST → [] | ORD → [CUST] | PAY → [CUST] | DASH → [ORD, PAY]
Execution:
  Batch 1: CUST (t=0-20)
  Batch 2: ORD + PAY (t=20-40)  ← song song (cùng phụ CUST)
  Batch 3: DASH (t=40-55)       ← phụ ORD+PAY
  Merge + Integration: t=55-60
  Total: 60 min (vs 80 sequential → tiết kiệm 25%)
```

### Backward Compatibility

- Nếu `--features` KHÔNG được dùng → Skill hoạt động như bình thường (single feature, load các phase files phase0-* → phase6-finalize.md)
- Nếu `--features` dùng với 1 feature duy nhất → Hoạt động như single, no overhead
- **Default:** Single feature — không cần `--features` flag

### Output Files

Mỗi feature produce output như single-feature flow (xem các phase files phase0-* → phase6-finalize.md):
- `$SESSION_DIR/impl-report.md`
- `$SESSION_DIR/impl-status.json`
- Code files trong `src/` hoặc `apps/`

**Additional:** `.mc-data/work/wf-implement-feature/multi-feature-report-$TIMESTAMP.md`
- Summarize tất cả features
- Timing metrics: individual session times + parallel efficiency
- Merge conflicts: (hopefully 0)
- Integration test results

---

## PHẦN 2: Micro-Task Support (--micro-task flag)

### Mục đích

Khi feature có A7-EXT section (micro-task breakdown) trong task file và user dùng:

```bash
/wf-implement-feature FEAT-CRM-CUST-001 --micro-task=MT-CUST-001
```

### Micro-Task Workflow

```
/wf-implement-feature FEAT-CRM-CUST-001 --micro-task=MT-CUST-001
  ↓
  Phase 0-micro: Load task file, extract MT-CUST-001 spec từ A7-EXT
  ↓
  Phase 1-5: Implement CHỈ micro-task đó (input/output từ MT spec)
  ↓
  Checkpoint lưu per-micro-task

/wf-implement-feature FEAT-CRM-CUST-001 --micro-task=MT-CUST-002 --resume
  ↓
  Load context_digest từ MT-CUST-001 checkpoint → Inject vào Phase 1
  ↓
  Implement MT-CUST-002 (có context từ MT-CUST-001)
```

### Phase 0-micro: Micro-Task Setup

**Trigger:** `--micro-task` flag có giá trị

| Step | Action | Verify |
|------|--------|--------|
| 0m.1 | Parse `--micro-task=MT-[FEAT]-[NNN]` → Validate format | Regex match: `MT-[A-Z]{3,4}-\d{3}` |
| 0m.2 | Load task file: `.mc-data/docs/phase5-implementation/tasks/[sys]/[mod]/[feat]-impl.md` | File exists, size > 0 |
| 0m.3 | Search A7-EXT section trong task file → Find MT specification | MT found trong A7-EXT |
| 0m.4 | Extract MT spec: name, estimated_time, input files, output files, dependencies, context_from_previous | Spec loaded vào `$MICRO_TASK` |
| 0m.5 | **Check dependencies:** Mỗi dependency trong MT phải đã hoàn thành (file exists, non-empty). Nếu chưa xong → WARN: "MT-CUST-001 phải xong trước. Chạy `--micro-task=MT-CUST-001` trước." | Dependencies satisfied hoặc user override |
| 0m.6 | **Load context_digest từ dependency MT:** Nếu MT phụ thuộc MT khác, load checkpoint của MT đó → Extract `context_digest` (Protocol 3.4) → Lưu vào `$CARRY_OVER_CONTEXT` | Digest loaded (hoặc N/A nếu first MT) |
| 0m.7 | Set `$FEATURE_MICRO_TASK = [MT-FEAT-NNN]`, `$MICRO_TASK_SCOPE = "ONLY_THIS_MT"` | Env set |

**POST-GATE:** MT specification loaded, dependencies satisfied, carry-over context ready (hoặc N/A)

### Micro-Task Checkpoint (per-micro-task)

**File:** `$SESSION_DIR/micro-task-$MT_ID.json`

**Format:**

```json
{
  "micro_task_id": "MT-CUST-001",
  "feature_id": "FEAT-CRM-CUST-001",
  "status": "in_progress | completed",
  "completed_at": "ISO-8601 or null",
  "phases_completed": ["phase_3"],
  "next_action": "start_phase_4",
  "context_digest": {
    "feature_summary": "Tạo Customer entity với soft-delete",
    "architectural_decisions": [],
    "interfaces_established": {},
    "patterns_in_use": {},
    "cross_batch_contracts": {},
    "gotchas_and_warnings": [],
    "micro_task_outputs": {
      "files_created": ["src/modules/crm/entities/customer.entity.ts"],
      "types_exported": ["CustomerEntity"],
      "exports_for_next_mt": {
        "MT-CUST-002": ["CustomerEntity type from src/modules/crm/entities/customer.entity.ts"]
      }
    }
  },
  "session_number": 1,
  "timestamp": "ISO-8601"
}
```

### Carry-Over Rules

- Khi implement MT-CUST-002: load checkpoint từ MT-CUST-001
- Extract `context_digest.micro_task_outputs.exports_for_next_mt.MT-CUST-002` → Inject vào Phase 1 prompt của MT-CUST-002
- Agent MT-CUST-002 KHÔNG cần re-read Phase 1-3 docs — có carry-over context rõ ràng

### Backward Compatibility

**Nếu feature KHÔNG có A7-EXT:**
- `--micro-task` flag IGNORED với warning: "Task file không có A7-EXT section. Implement cả feature bình thường."
- Workflow chạy single-feature phase files như bình thường

**Nếu feature có A7-EXT nhưng user KHÔNG dùng `--micro-task`:**
- Workflow chạy single-feature phase files như bình thường (implement cả feature, không tách micro-task)
- A7-EXT section bỏ qua
