# Phase 2: Analyze — Calculate Sync Rate + Identify Gaps

> Gộp Phase 4 (Calculate Sync Rate) + Phase 5 (Identify Gaps) — xử lý in-memory thuần.
> Output: `$SYNC_RATE`, `$COVERAGE_RATE`, `$W001_ANOMALIES`, `$GAPS_LIST`.

**PRE-GATE:**
- Phase 1 (`phase1-scan.md`) POST-GATE PASS
- `test -n "$REQ_INDEX" && test -n "$CODE_REFS"`

**📥 INPUT:** In-memory từ Phase 1 — `$REQ_INDEX`, `$CODE_REFS`, `$ORPHAN_LIST`

**📤 OUTPUT (in-memory):**
- `$SYNC_RATE` — `(Implemented / Total) × 100`
- `$COVERAGE_RATE` — `((Implemented + InProgress) / Total) × 100`
- `$W001_ANOMALIES` — array REQ-IDs `impl_status="done"` nhưng code không tìm thấy
- `$W003_ANOMALIES` — array REQ-IDs có code và `impl_status="done"`, nhưng Feature cha chưa hoàn thành
- `$GAPS_LIST` — array `{req_id, type, priority, suggested_action}`

> Phase này KHÔNG tạo file. Output là in-memory state cho Phase 3-6.

---

## Reference Sections

- `_shared/state-variables.md`
- `_shared/registry-safe-write.md` (W001 logic)

---

## Steps — Calculate Sync Rate (cũ Phase 4)

> **v4.0+ S4:** Matching + categorization delegated to `vs-analyze.sh` cho token efficiency.

| Step | Action | Verify |
|------|--------|--------|
| 2.1 | **Bash delegation:** Chạy `bash .claude/scripts/wf-verify-sync/vs-analyze.sh --scan-results $SESSION_DIR/scan-results.json --registry .mc-data/docs/_meta/req-registry.json --output $SESSION_DIR/analysis-results.json`. Nếu có `$SCOPE_FILTER` → pass `--scope-file <(echo "$SCOPE_FILTER_JSON")`. | `test -s $SESSION_DIR/analysis-results.json` |
| 2.2 | Đọc `$SESSION_DIR/analysis-results.json` → set `$ANALYSIS_RESULTS` (in-memory). Extract: `$SYNC_RATE`, `$COVERAGE_RATE`, `$W001_ANOMALIES`, `$W002_ANOMALIES`, `$W003_ANOMALIES`, `$GAPS_LIST`, `$FEATURE_SUMMARY`, `$HAS_IN_PROGRESS_FEATURES`, `$IN_PROGRESS_FEATURES_LIST`. | All in-memory variables populated |
| 2.2a | **GUARD — Total == 0 check:** Nếu `$ANALYSIS_RESULTS.e020_triggered == true` → set `$SYNC_RATE = null`, `$COVERAGE_RATE = null`, log **E020** warning → NEXT Phase 6 với N/A report. | E020 guard checked |
| 2.3 | **Feature Completion validation:** Verify `$FEATURE_SUMMARY` loaded correctly. Nếu `$HAS_IN_PROGRESS_FEATURES == true` → log info với số lượng features in_progress. | Feature summary verified |

### vs-analyze.sh — Input/Output

```
Input:  --scan-results <path>      (output từ vs-scan-code.sh)
        --registry <path>           (.mc-data/docs/_meta/req-registry.json)
        --scope-file <path>         (optional: {req_ids: [], modules: []})
        --output <path>
Output: analysis-results.json:
        {implemented[], in_progress[], not_started[], skipped[],
         w001_anomalies[], w002_anomalies[], w003_anomalies[],
         orphan_files[], sync_rate, coverage_rate, total, skipped_count,
         e020_triggered, feature_summary, has_in_progress_features,
         in_progress_features_list, gaps_list[]}
Logic:  jq-based set operations:
        - Implemented: REQ-IDs done + code found + feature done (not W003)
        - W001: done but code NOT found
        - W002: in_progress but code NOT found
        - W003: done + code found but parent feature incomplete
        - Sync rate: (Implemented / Total) x 100
        - Coverage: ((Implemented + InProgress) / Total) x 100
```

### Status categories

| Status | Điều kiện | Cách xác định |
|--------|-----------|---------------|
| Implemented | REQ-ID có code + registry `impl_status="done"` + Feature cha ĐÃ HOÀN THÀNH | Code chứa REQ-ID comment VÀ registry ghi "done" VÀ không thuộc $W003_ANOMALIES |
| In Progress | REQ-ID có code + registry `impl_status="in_progress"` (hoặc bị W003) | Code chứa REQ-ID comment VÀ (registry ghi "in_progress" HOẶC bị đánh dấu W003) |
| W001 Anomaly | Registry `impl_status="done"` NHƯNG code scan không tìm thấy | KHÔNG downgrade — ghi WARNING, yêu cầu user xác nhận. Đếm vào `$W001_ANOMALIES` |
| W002 Anomaly | Registry `impl_status="in_progress"` NHƯNG code scan không tìm thấy | Ghi WARNING "in_progress nhưng không có code". Đếm vào `$W002_ANOMALIES`. Push vào `$GAPS_LIST` type="partial_implementation" với flag `w002=true` |
| W003 Anomaly | Registry `impl_status="done"` VÀ code tồn tại, NHƯNG REQ-ID thuộc về Feature chưa hoàn thành | Tính vào `In Progress` thay vì `Implemented`. Ghi WARNING. Đếm vào `$W003_ANOMALIES`. Push vào `$GAPS_LIST` type="partial_implementation" với flag `w003=true` |
| Not Started | `impl_status="not_started"` VÀ không tìm thấy code | Không có file nào chứa REQ-ID comment VÀ registry ghi "not_started" |
| Skipped | `impl_status = "skipped"` | Registry ghi "skipped" — loại khỏi tính sync rate |
| Orphan Code | Code không có REQ-ID | File source code không chứa bất kỳ REQ-ID comment nào |

> **Lưu ý quan trọng:**
> - "Implemented" CHỈ tính REQ-IDs có `impl_status="done"` trong registry, code tồn tại, VÀ Feature cha đã hoàn thành (không bị W003).
> - REQ-IDs có code nhưng `impl_status="in_progress"` được tính là "In Progress", KHÔNG phải "Implemented".
> - REQ-IDs có `impl_status="done"` nhưng code scan KHÔNG tìm thấy → **W001 Anomaly** (đếm riêng vào `$W001_ANOMALIES`, KHÔNG đếm vào Not Started, KHÔNG downgrade).
> - REQ-IDs có `impl_status="in_progress"` nhưng code scan KHÔNG tìm thấy → **W002 Anomaly** (đếm riêng vào `$W002_ANOMALIES`, đưa vào `$GAPS_LIST` type="partial_implementation" với flag `w002=true`).
> - REQ-IDs có `impl_status="done"` và có code nhưng Feature chưa hoàn thành → **W003 Anomaly** (đếm vào `$W003_ANOMALIES`, tính vào "In Progress", đưa vào `$GAPS_LIST`).
> - **W001 và W003 Anomalies VẪN được tính vào Total (denominator)** — KHÔNG loại trừ như "skipped".
> - **W002 và W003 Anomalies được tính vào InProgress (Coverage Rate denominator calculation)** nhưng KHÔNG được đưa vào Implemented.
> - `$W001_ANOMALIES`, `$W002_ANOMALIES`, và `$W003_ANOMALIES` PHẢI được tính tại Step 2.2/2.2b để Phase 5 cross-validation dùng được.

### Hai công thức

```
Total REQ-IDs = tổng REQ-IDs trong scope TRỪ những có impl_status = "skipped"  ← denominator cho sync rate
                W001 anomalies KHÔNG bị loại — W001 là "done" trong registry, KHÔNG phải "skipped"
Skipped Count = số REQ-IDs có impl_status = "skipped" (dùng để hiển thị, không dùng làm denominator)
Sync Rate    = (Implemented / Total) × 100%    ← CHỈ đếm "done" CÓ code VÀ không bị W003; W001 và W003 KHÔNG đếm vào Implemented
Coverage Rate = ((Implemented + InProgress) / Total) × 100%  ← W003 được đếm vào InProgress; W001 KHÔNG đếm vào InProgress

GUARD: Nếu Total == 0 (tất cả REQ-IDs đều skipped hoặc scope không có REQ-ID nào):
  → $SYNC_RATE = null, $COVERAGE_RATE = null
  → LOG WARNING (E020): "Tất cả REQ-IDs trong scope đều skipped hoặc scope rỗng — Sync Rate không thể tính."
  → KHÔNG tính tiếp — NEXT ngay Phase NEXT (skip Phase 3/4/5 nếu total == 0, nhảy sang Phase 6 với N/A report)
  → Phase 6 hiển thị "N/A" thay vì số phần trăm

Ví dụ: 10 REQ-IDs, 0 skipped, 1 W001 (REQ-INV-003: done nhưng không có code)
  → Total       = 10 - 0 skipped = 10   ← W001 KHÔNG bị trừ
  → Implemented = 6 (done + code found, KHÔNG bao gồm W001)
  → InProgress  = 1
  → Sync Rate   = 6/10 = 60%            ← KHÔNG phải 6/9
  → Coverage    = (6+1)/10 = 70%        ← KHÔNG phải 7/9
```

> Sync Rate là chỉ số chính để đánh giá release readiness. Coverage Rate là tham khảo bổ sung.

---

## Steps — Identify Gaps (cũ Phase 5)

> **v4.0+ S4:** Gaps list được build bởi `vs-analyze.sh` — không cần xử lý thủ công.
> Xem `$ANALYSIS_RESULTS.gaps_list` — phân loại thành Missing/Partial/Orphan/DesignMismatch.

| Step | Action | Verify |
|------|--------|--------|
| 2.4 | Verify `$ANALYSIS_RESULTS.gaps_list` includes entries for all not_started REQ-IDs (type=missing_implementation) | Missing gaps verified |
| 2.5 | Verify `$ANALYSIS_RESULTS.gaps_list` includes entries for W002/W003 REQ-IDs (type=partial_implementation) | Partial gaps verified |
| 2.6 | Verify `$ANALYSIS_RESULTS.gaps_list` includes orphan code entries (type=orphan_code) | Orphan gaps verified |
| 2.7 | (Optional) Manual cross-check vs technical design → thêm type=design_mismatch entries. Nếu không có technical design → skip. | Mismatches added (hoặc skipped) |
| 2.8 | Verify priorities assigned per gap entry (từ registry hoặc default medium) | Priorities verified |

### Gap types

- **Missing Implementation** — REQ-ID tồn tại, không có code
- **Partial Implementation** — Có code nhưng thiếu tests / chưa "done"
- **Orphan Code** — Code không có REQ-ID
- **Design Mismatch** — Code khác với technical design (optional)

---

**POST-GATE Phase 2:**
- `$SYNC_RATE` defined (number 0-100 HOẶC null nếu E020)
- `$COVERAGE_RATE` defined (number 0-100 HOẶC null nếu E020)
- `$W001_ANOMALIES` defined (có thể empty array)
- `$W002_ANOMALIES` defined (có thể empty array)
- `$W003_ANOMALIES` defined (có thể empty array)
- `$GAPS_LIST` defined (có thể empty array — nếu sync_rate=100%)
- `$FEATURE_SUMMARY` defined (object — có thể all-zeros nếu registry không có features[])
- `$HAS_IN_PROGRESS_FEATURES` defined (bool)
- `$IN_PROGRESS_FEATURES_LIST` defined (array — có thể empty)
- Cập nhật `verify-sync-status.json`: `phases.phase_2.status="completed"`, `phases.phase_2.sync_rate` (hoặc "N/A"), `phases.phase_2.coverage_rate` (hoặc "N/A"), `phases.phase_2.gaps_count`, `phases.phase_2.partial_count`, `phases.phase_2.w001_count`, `phases.phase_2.w002_count`, `phases.phase_2.w003_count`, `phases.phase_2.total_req_ids`, `phases.phase_2.e020_triggered` (bool), `phases.phase_2.features_in_progress_count` = `$FEATURES_IN_PROGRESS`

**NEXT:**
- Nếu `$INTERFACE_TYPE != "api-only"` → Load `phase3-ui-coverage.md`
  - Sau Phase 3: Nếu `--fix` → Load `phase4-fix.md`, ngược lại → Load `phase5-crossval.md`
- Nếu `$INTERFACE_TYPE == "api-only"` (bỏ qua Phase 3):
  - Nếu `--fix` → Load `phase4-fix.md`
  - Nếu không `--fix` → Load `phase5-crossval.md`
