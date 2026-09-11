# `isg/` — Interactive Selection Gate

> **Trạng thái:** B1 Skeleton (2026-04-20) · chưa implement logic thật
> **Version:** 0.1.0-skeleton
> **ADR refs:** ADR-14 (ISG), ADR-22 rule 1 (safety floor QD1+QD2+QD5)
> **CORE refs:** CORE-027 (Critical Decision Gate)
> **Registry role:** NONE
> **Nơi được gọi:** `/wf-fix-bugs` orchestrator Phase 0 (khi user không truyền `--dims`)

---

## 1. Mục Đích

ISG là **cổng tương tác** giữa user và orchestrator `wf-fix-bugs` v6.0. Khi user gõ `/wf-fix-bugs` không kèm `--dims`, ISG làm 3 việc:

1. **Phân tích signals** (git diff, preflight report, domain hints) để biết **nên** quét chiều nào.
2. **Hiển thị bảng tick** 7 Quality Dimension kèm recommend (`★` cho chiều recommend strong, `·` cho weak, blank cho không recommend).
3. **Nhận selection từ user** → emit `dim-selection.json` cho orchestrator đọc.

ISG **không quét code** — chỉ đọc metadata (diff, registry, preflight) để gợi ý.

---

## 2. Input / Output

### 2.1. Input

| Nguồn | Đường dẫn | Bắt buộc | Ghi chú |
|-------|-----------|----------|---------|
| Git diff (nếu có) | Output của `git diff --name-only <ref>` | Không | Nếu `--since=<ref>` được truyền, dùng ref đó; mặc định `HEAD~1` |
| Preflight report | `.mc-data/work/wf-preflight/preflight-report.md` | Không | Nếu tồn tại, parse để lấy severity hints |
| Req registry | `.mc-data/docs/_meta/req-registry.json` | Có | Để đếm feature in-scope + domain detect |
| Profile flag | `--profile=quick|standard|deep|exhaustive` | Không (default `standard`) | Xác định safety floor |
| User scope | `--scope=all|system|module [--name=...]` | Không (default `all`) | Thu hẹp phân tích signal |

### 2.2. Output

**File:** `$SESSION_DIR/dim-selection.json`

**Schema:** [`schemas/dim-selection.schema.json`](schemas/dim-selection.schema.json)

**Ví dụ:**

```json
{
  "$schema": "dim-selection-v1",
  "selected_at": "2026-04-20T10:30:00+07:00",
  "profile": "standard",
  "scope": {"type": "all"},
  "recommendations": [
    {"dim": "QD1", "strength": "strong", "reason": "git diff chạm 8 file trong src/features/"},
    {"dim": "QD2", "strength": "strong", "reason": "registry có domain=logistics → nghiệp vụ cần verify"},
    {"dim": "QD3", "strength": "weak", "reason": "diff chạm 1 file auth middleware"},
    {"dim": "QD5", "strength": "strong", "reason": "profile=standard luôn include UI"}
  ],
  "selected": ["QD1", "QD2", "QD5"],
  "skipped": ["QD3", "QD4", "QD6", "QD7"],
  "skipped_rationale": "User chọn profile=standard, không thêm chiều ngoài default",
  "safety_floor_enforced": true,
  "source_signals": {
    "git_diff_files": 8,
    "preflight_available": true,
    "preflight_critical_count": 2,
    "domain": "logistics"
  }
}
```

---

## 3. Hành Vi Theo Profile

| Profile | Default selected | Có thể bỏ? | Safety floor |
|---------|------------------|-----------|--------------|
| `quick` | `[QD1, QD5]` | Có thể bỏ bất kỳ, nhưng phải chọn ≥1 | Không có floor (fast feedback) |
| `standard` | `[QD1, QD2, QD5]` | **Không được bỏ toàn bộ QD1+QD2+QD5** (ADR-22 rule 1) | Floor = `QD1 ∨ QD2 ∨ QD5` (ít nhất 1) |
| `deep` | `[QD1, QD2, QD5, QD6, QD3]` | Được bỏ QD3/QD6 nếu có CDG confirmation | Floor giống `standard` |
| `exhaustive` | `[QD1..QD11]` | Không được bỏ (enforce by orchestrator) | Floor = full 11 |

**ADR-22 rule 1 chi tiết:** Nếu profile ≥ `standard` và user tick bỏ cả QD1 + QD2 + QD5, ISG **từ chối** emit selection và hiển thị lỗi:

```
LỖI: Profile 'standard' yêu cầu ít nhất 1 trong [QD1, QD2, QD5] phải được chọn.
    Lý do: North Star của wf-fix-bugs là ưu tiên logic + nghiệp vụ + UI.
    Gợi ý: Dùng --profile=quick nếu bạn muốn bỏ cả 3.
```

---

## 4. Signal Analysis Heuristics

### 4.1. Git Diff Signals

- File path chạm `src/**/*.service.ts|py` → QD1 + QD6 (strong)
- File path chạm `src/**/*.controller.ts` + `src/**/auth/**` → QD3 (strong)
- File path chạm `src/**/*.component.tsx|jsx|vue` → QD5 (strong)
- File path chạm `migrations/**` → QD6 (strong)
- File path chạm `src/**/perf/**` hoặc query builder → QD4 (weak)
- > 30 file thay đổi → QD7 compat risk (weak)

### 4.2. Preflight Signals

Parse `preflight-report.md` section severity:

- `CRITICAL` count > 0 → liên quan dim nào thì strong cho dim đó
- `WARN` trong security section → QD3 strong
- `WARN` trong performance section → QD4 weak

### 4.3. Domain Signals (từ `req-registry.json`)

- `departments[]` chứa `finance|accounting` → QD2 strong (business correctness cho tính toán tài chính)
- `departments[]` chứa `healthcare|medical` → QD2 + QD3 + QD6 strong
- `departments[]` chứa `logistics|shipping` → QD2 + QD6 strong (HS code, traceability)
- `interface_type == "api-only"` → QD5 weak (không có UI)

---

## 5. Flow Tương Tác

```
┌─────────────────────────────────────────────────────────┐
│ /wf-fix-bugs  (không có --dims)                         │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
          ┌──────────────────┐
          │   isg-prompt.sh  │  (shell orchestrator)
          └────────┬─────────┘
                   │
                   ├─▶ isg_recommender.py --analyze
                   │     ├─ load git diff
                   │     ├─ load preflight
                   │     ├─ load registry
                   │     └─ emit recommendations.json (temp)
                   │
                   ├─▶ render_checklist(profile, recommendations)
                   │     → in ra markdown table tick-box
                   │
                   ├─▶ đọc user response
                   │     (format: "QD1,QD2,QD5" hoặc "all" hoặc "recommend")
                   │
                   ├─▶ enforce_safety_floor(selected, profile)
                   │     (ADR-22 rule 1 — raise nếu vi phạm)
                   │
                   ├─▶ CDG check (CORE-027)
                   │     (nếu user bỏ QD1 hoặc QD3 ở profile deep)
                   │
                   └─▶ emit_selection() → dim-selection.json
```

---

## 6. Critical Decision Gate (CDG)

ISG phải chạy CDG confirm khi user chọn:

| Hành động | Trigger CDG? | Prompt |
|-----------|-------------|--------|
| Bỏ QD1 ở profile `standard` | ✅ | "Bạn đang bỏ Functional Correctness ở profile standard. Điều này vi phạm ADR-22 rule 1. Gõ `override-qd1` để xác nhận override (không khuyến khích)." |
| Bỏ QD3 ở profile `deep` | ✅ | "Security ở profile deep thường nên giữ. Gõ `confirm-skip-qd3` để tiếp tục." |
| Chọn `exhaustive` nhưng `fix-workload.json` ước 3h+ | ✅ (do orchestrator check sau) | Delegation tới Workload Gate ADR-15 |

Note: CDG của ADR-22 cho secrets-in-code (rule 4) do `signal_bus/` enforce, không phải ISG.

---

## 7. Files Trong Module Này

| File | Vai trò | Ngôn ngữ |
|------|---------|----------|
| `README.md` | (file này) Tài liệu tổng thể | Tiếng Việt |
| `isg-prompt.sh` | Shell orchestrator — parse args, gọi Python, render checklist | Bash |
| `isg_recommender.py` | Python — phân tích signals + render + parse response | Python 3 |
| `schemas/dim-selection.schema.json` | JSON Schema cho output | JSON Schema Draft 2020-12 |
| `_contract.json` | Module contract (version, inputs, outputs, ADR refs) | JSON |

---

## 8. Testing Plan

- **B1 (phiên này):** chỉ skeleton — `raise NotImplementedError` ở mọi hàm.
- **B3:** wire-up với `wf-fix-functional` và `wf-fix-business` bellweather; test manual flow.
- **B4:** Fixture `safety-floor-violation.json` — input profile=standard + selected=[QD3] → assert ISG refuse emit.

---

## 9. Tham Chiếu

- ADR-14 (ISG): [`07-tradeoffs-adr.md`](../../../../../docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md)
- ADR-22 Safety Defaults: [`09-design-decisions.md §8`](../../../../../docs/design/skills/wf-fix-bugs/09-design-decisions.md)
- User scenario 1 (ISG flow): [`08-user-scenarios-solutions.md §3`](../../../../../docs/design/skills/wf-fix-bugs/08-user-scenarios-solutions.md)
- CORE-027 (CDG): `.claude/rules/00-core.md` Quick Reference
