# Phase 0: Init — PRE-GATE & Argument Routing

> Entry point. **LUÔN chạy đầu tiên** để parse arguments, validate codebase tồn tại,
> xử lý conflict `.mc-data/` đã có sẵn, tạo status file. Phase này KHÔNG gọi sub-skill.

## PRE-GATE (CORE-011 — Forensic Content Validation)

```bash
# T1: Codebase tồn tại tại thư mục hiện tại
test -d . && ls 2>/dev/null | head -1 > /dev/null || exit_with E001

# T2: Có file source hoặc config (heuristic — không strict, chỉ warn)
ls *.* 2>/dev/null | head -1 > /dev/null \
  || ls src/ apps/ packages/ lib/ 2>/dev/null > /dev/null \
  || echo "WARNING: Thư mục có vẻ trống, nhưng vẫn tiếp tục"
```

**Error message:**
- E001 → *"Không tìm thấy codebase. Kiểm tra thư mục project hoặc chuyển đến thư mục root của dự án."*

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.1 | Parse `$ARGUMENTS`: `--resume`, `--from-phase N` | - | Args parsed |
| 0.2 | Tạo tracking dir `.mc-data/work/existing-project/` | Bash `mkdir -p` | `test -d` |
| 0.3 | Detect `legacy_pipeline_done` (xem §Pipeline Status Detection) | Bash | Saved |
| 0.4 | Conflict handling — nếu `.mc-data/` đã có và KHÔNG có flag `--resume`/`--from-phase` → menu 3 lựa chọn (xem §Conflict Menu) | Bash + Read | User chọn |
| 0.5 | Tạo `$STATUS_FILE` theo schema (xem `_shared.md §Status File Schema`) | Write | `test -f` |
| 0.6 | Hiển thị overview workflow + xác nhận với user (bỏ qua khi `--resume` hoặc `--from-phase`) | - | User confirm |

## Argument Processing

- **Có `--resume`** → chuyển sang Resume Protocol (xem `_shared.md §Resume Protocol`)
- **Có `--from-phase N`** → validate N (xem `_shared.md §--from-phase Mapping`) → nếu invalid → E010 → kiểm tra prerequisites của phase đích → nếu chưa đủ → E011 → nhảy đến phase tương ứng
- **Không flag** → chạy step 0.4 (conflict check) → step 0.6 (overview confirm)

## Pipeline Status Detection (Step 0.3)

```bash
LEGACY_PIPELINE_DONE=false

if test -f .mc-data/work/legacy-scan/ledger.json; then
  # Validate JSON content (CORE-011)
  if ! jq -e '.stages | type == "object"' .mc-data/work/legacy-scan/ledger.json > /dev/null 2>&1; then
    exit_with E005   # "Ledger JSON corrupt — re-run wf-legacy-scan"
  fi

  PIPELINE_STATUS=$(jq -r '.pipeline_status // "INCOMPLETE"' .mc-data/work/legacy-scan/ledger.json)
  if [[ "$PIPELINE_STATUS" == "COMPLETE" ]]; then
    LEGACY_PIPELINE_DONE=true
  elif [[ "$PIPELINE_STATUS" != "INCOMPLETE" && "$PIPELINE_STATUS" != "null" ]]; then
    # Pipeline đã chạy nhưng chưa COMPLETE
    echo "Pipeline chưa hoàn tất (status=$PIPELINE_STATUS). Cần chạy /wf-legacy-scan --resume trước."
    exit_with E005
  fi
fi
```

Ghi vào `$STATUS_FILE.legacy_pipeline_done`. Nếu `true` → phase-scan và 0b cluster sẽ tự skip.

## Conflict Menu (Step 0.4)

Áp dụng KHI: `test -d .mc-data` && KHÔNG có `--resume` && KHÔNG có `--from-phase`.

```
Tìm thấy .mc-data/ từ lần trước.
  1. Resume — tiếp tục từ bước đang dở
  2. Onboard lại — backup và làm lại từ đầu
  3. Hủy — không làm gì
```

| Lựa chọn | Action |
|----------|--------|
| `1` | Set flag `--resume` ngầm → chuyển sang Resume Protocol |
| `2` | `mv .mc-data _mc-data-backup-$(date +%Y%m%d-%H%M%S)` → tiếp tục step 0.5 |
| `3` | STOP workflow |

**Backup verify:**
```bash
test -d _mc-data-backup-*    # E002 nếu fail
```

## Overview Display (Step 0.6)

```
🔄 DEVKIT — Existing Project Workflow
─────────────────────────────────────
Sẽ thực hiện 13 bước từ Legacy Scan đến Deployment:

  scan         → Phân tích codebase hiện có (wf-legacy-scan)
  brainstorm   → Phase 0 docs từ extracted data
  analyze-req  → Phase 1 docs (BA + domain experts)
  define-feats → Phase 2 docs (feature specs + impl_status)
  design       → Phase 3 docs + registry build + gap analysis
  annotate     → (conditional) Inject REQ-ID vào code hiện có
  phase4       → (conditional) UX/UI design
  phase5a      → Implementation plan
  phase5b      → Code implementation (loop per feature)
  preflight    → Health check toàn diện
  verify       → Traceability sync check
  deployment   → Deployment docs + user guides

Mỗi bước sẽ hỏi xác nhận trước khi tiếp tục.

Bạn có muốn bắt đầu không? (yes/no)
```

## POST-GATE

- `$STATUS_FILE` tồn tại, JSON valid
- `current_step = "scan"` (hoặc phase mục tiêu nếu `--from-phase`)
- `legacy_pipeline_done` đã ghi
- Append `"phase0"` vào `phases_completed[]`

## Transition

```
✅ Phase 0 hoàn thành — context loaded
  legacy_pipeline_done: [true/false]
  Resume mode: [true/false]

→ Next: phase-scan (Legacy Scan Pipeline)
   HOẶC nhảy theo --from-phase nếu có
```

## Errors liên quan

- **E001** — Codebase không tồn tại (STOP)
- **E002** — Backup `.mc-data/` fail
- **E005** — Ledger JSON corrupt hoặc pipeline INCOMPLETE
- **E010** — `--from-phase` giá trị không hợp lệ
- **E011** — `--from-phase` prerequisites chưa sẵn sàng
- **E016** — Status file corrupt → trigger E012 fallback

Chi tiết: `_shared.md §Error Handling Reference`.
