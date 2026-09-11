# Phase 1.5: Feature-Level Code Status (CHỈ LEGACY_MODE)

> Xác định `implementation_strategy` per feature dựa trên code thực tế — CORE-019.
> **Chỉ chạy khi `$LEGACY_MODE = true`.** Nếu `$LEGACY_MODE = false` → bỏ qua hoàn toàn.

> **Shared context:** xem `_shared.md` — State Variables Glossary (`$FEATURE_IMPL_MAP`).

---

## PRE-GATE

```bash
[ "$LEGACY_MODE" = "true" ]
```

**Điều kiện bắt buộc:** `$LEGACY_MODE = true`.

**3 runtime modes (depending on file availability):**

| Mode | Snapshot | Mapping | Hành vi |
|------|----------|---------|---------|
| **FULL** | ✓ | ✓ | Dùng snapshot làm ground truth + mapping cho code refs (đường tốt nhất) |
| **GREP_ONLY** | ✗ | ✓ | Grep codebase theo module paths từ mapping → suy ra strategy (chậm hơn nhưng vẫn chính xác) |
| **HEURISTIC** | ✗ | ✗ | Grep toàn repo + heuristic module match từ registry → warn user confidence thấp |

Các trường hợp fail / decision:
- Không phải LEGACY → SKIP Phase 1.5, jump Phase 2.
- LEGACY + thiếu `module-code-mapping.json` nhưng có `impl-status-snapshot.json` → **DỪNG** + AskUserQuestion:
  - (a) Chạy lại `/wf-legacy-extract` để tạo mapping (khuyến nghị)
  - (b) Tiếp tục với HEURISTIC mode (grep toàn repo, chậm trên project > 100 features)
  - (c) Hủy

> **(CORE-019 compliance)** Mọi mode phải **luôn** emit `$FEATURE_IMPL_MAP` với đầy đủ `implementation_strategy` per feature (default `IMPLEMENT_NEW` + `confidence=0.2` khi không có signal nào). Phase 1.5 KHÔNG ĐƯỢC skip toàn bộ chỉ vì snapshot thiếu — task file Phase 7.5 bắt buộc có strategy heading.

---

## 📥 INPUT

| File | Đường dẫn | Mô tả |
|------|-----------|-------|
| Impl status snapshot | `.mc-data/work/legacy-scan/impl-status-snapshot.json` | Scan-time snapshot (READ-ONLY — P8) |
| Module code mapping | `.mc-data/work/legacy-scan/module-code-mapping.json` | Code-to-module mapping |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Features list |

> Output **BẮT BUỘC persist** (A6-H1 fix — trước đây chỉ in-memory, mất khi context reset):
>
> - In-memory variable: `$FEATURE_IMPL_MAP` (dùng ngay trong session)
> - File persist: `.mc-data/work/wf-plan-modules/feature-impl-map.json` (BẮT BUỘC ghi ở Step 1.5.5)
>
> Phase 7.5 sẽ đọc `$FEATURE_IMPL_MAP` nếu còn in-memory, fallback đọc `feature-impl-map.json` nếu biến mất sau resume.
>
> Schema `feature-impl-map.json`:
> ```json
> {
>   "schema_version": "1.0",
>   "generated_at": "<ISO-8601>",
>   "features": [
>     {"feat_id": "...", "req_id": "...", "module_id": "...",
>      "implementation_strategy": "VERIFY_ONLY|COMPLETE_EXISTING|IMPLEMENT_NEW",
>      "existing_code_refs": [...], "gaps_identified": [...], "confidence": 0.0-1.0}
>   ]
> }
> ```

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 1.5.0 | Detect mode: nếu `impl-status-snapshot.json` exist + non-empty → `$MODE=FULL`; elif `module-code-mapping.json` exist → `$MODE=GREP_ONLY`; else → `$MODE=HEURISTIC`. Log mode + warn nếu không phải FULL | Mode set |
| 1.5.1 | Nếu `$MODE=FULL` → đọc `impl-status-snapshot.json`; else → set `$SNAPSHOT={}` | JSON loaded (hoặc empty) |
| 1.5.2 | Nếu `$MODE ∈ {FULL, GREP_ONLY}` → đọc `module-code-mapping.json`; else → set `$MAPPING={}` | JSON loaded (hoặc empty) |
| 1.5.3 | Với MỖI feature trong registry → xác định `implementation_strategy` (xem §Strategy Determination). **Skip features thuộc `$DEPRECATED_MODULES`** — set `implementation_strategy = "SKIPPED_DEPRECATED"` thay vì verify code. **Luôn** emit 1 entry vào `$FEATURE_IMPL_MAP` cho mọi feature (default `IMPLEMENT_NEW`, `confidence=0.2` khi không có signal). | All features classified (no nulls) |
| 1.5.3b | **[v5.1+ Code Quality Scan]** Nếu `implementation_strategy == COMPLETE_EXISTING` và `confidence >= 0.7`: chạy quick grep scan các common issues trong `existing_code_refs[]` (xem §Code Quality Scan). Append findings vào `gaps_identified`. | Scan done, gaps updated |
| 1.5.4 | Tổng hợp Implementation Overview → hiển thị cho user (kèm `$MODE` flag: "⚠️ HEURISTIC mode — độ tin cậy thấp, khuyến nghị chạy lại wf-legacy-scan với --profile=deep") | User reviewed |
| 1.5.5 | **[PERSIST]** WRITE `$FEATURE_IMPL_MAP` ra `.mc-data/work/wf-plan-modules/feature-impl-map.json` qua Atomic Write Pattern (A6-H1 fix). Ghi thêm field `"generation_mode": "FULL\|GREP_ONLY\|HEURISTIC"` ở root. | `test -s feature-impl-map.json` + `jq -e '.features \| length > 0 and .generation_mode'` |

---

## §Strategy Determination (Step 1.5.3 chi tiết)

```
FOR each feature IN registry.features:
  a. Tìm entry trong impl-status-snapshot (match by module + feature name/REQ-ID)
  b. Nếu KHÔNG có entry → Grep codebase cho entity/endpoint/component names:
     Grep patterns: "class [FeatureName]", "[endpoint-path]", "[ComponentName]"

  c. Xác định implementation_strategy:
     ┌─────────────────────────────────────────────────┐
     │ status == DONE AND confidence >= 0.8:           │
     │ → strategy = VERIFY_ONLY                       │
     │ → effort_estimate: "0.5h (verify + annotate)"  │
     ├─────────────────────────────────────────────────┤
     │ status == PARTIAL OR confidence 0.5-0.8:       │
     │ → strategy = COMPLETE_EXISTING                 │
     │ → effort_estimate: dựa trên gaps_count         │
     ├─────────────────────────────────────────────────┤
     │ status == NOT_STARTED:                         │
     │ → strategy = IMPLEMENT_NEW                     │
     │ → effort_estimate: full TDD cycle              │
     └─────────────────────────────────────────────────┘

  d. Lưu vào $FEATURE_IMPL_MAP:
     {
       feat_id: "FEAT-CRM-CUST-001",
       strategy: "VERIFY_ONLY",
       existing_code_refs: ["src/.../CustomerService.cs:45-180"],
       gaps_identified: [],
       effort_estimate: "0.5h"
     }
```

---

## §Code Quality Scan (Step 1.5.3b chi tiết — v5.1+)

> Khi `implementation_strategy == COMPLETE_EXISTING` và `confidence >= 0.7`, chạy quick grep scan
> các common issues trong `existing_code_refs[]`. KHÔNG spawn full agent (quá nặng) — chỉ bash grep.

### Scan Patterns

| # | Pattern | What it finds | Severity |
|---|---------|---------------|----------|
| G1 | `grep -rn 'process\.env\.' --include='*.tsx' --include='*.jsx' [refs]` | `process.env` in browser code | HIGH |
| G2 | `grep -rnE "(dev-secret\|admin123\|changeme\|temp_key)" [refs]` | Hardcoded secrets | CRITICAL |
| G3 | `grep -rn '\.replace(['"'"'"'"]' --include='*.ts' --include='*.tsx' [refs] \| grep -v '/g'` | Non-global replace | MEDIUM |
| G4 | `grep -rn 'alert(' --include='*.tsx' --include='*.jsx' [refs]` | alert() calls (accessibility) | MEDIUM |
| G5 | `grep -rn 'console\.log(' --include='*.ts' --include='*.tsx' [refs]` | Console.log leaks | LOW |

### Exclusion

```bash
# Luôn exclude test files, node_modules, dist, build
EXCLUDE=( "*.test.*" "*.spec.*" "node_modules/" "dist/" "build/" ".next/" "__snapshots__/" )
```

### Steps

```
FOR each feature WHERE strategy == COMPLETE_EXISTING AND confidence >= 0.7:
  REFS="$feature.existing_code_refs"   # chỉ scan files đã biết, không toàn repo
  GAPS=()

  # G1: process.env in browser code
  G1_RESULT=$(echo "$REFS" | grep -E '\.(tsx|jsx)$' | grep -v '/server/' | xargs -r grep -n 'process\.env\.' 2>/dev/null)
  IF G1_RESULT not empty:
    FOR each match: GAPS += "AUTO-SCAN: process.env in [file] (line [N]) — Vite browser code"

  # G2: hardcoded secrets
  G2_RESULT=$(echo "$REFS" | xargs -r grep -nE "(dev-secret|admin123|changeme|temp_key)" 2>/dev/null)
  IF G2_RESULT not empty:
    FOR each match: GAPS += "AUTO-SCAN: Hardcoded '[value]' in [file] (line [N])"

  # G3: non-global replace
  G3_RESULT=$(echo "$REFS" | grep -E '\.(ts|tsx)$' | xargs -r grep -n '\.replace(['"'"'"'"]' 2>/dev/null | grep -v '/g')
  IF G3_RESULT not empty:
    FOR each match: GAPS += "AUTO-SCAN: Non-global replace in [file] (line [N]) — consider regex /g"

  # G4: alert() calls
  G4_RESULT=$(echo "$REFS" | grep -E '\.(tsx|jsx)$' | xargs -r grep -n 'alert(' 2>/dev/null)
  IF G4_RESULT not empty:
    FOR each match: GAPS += "AUTO-SCAN: alert() in [file] (line [N]) — use Toast component"

  # G5: console.log
  G5_RESULT=$(echo "$REFS" | grep -E '\.(ts|tsx)$' | grep -v '\.test\.' | xargs -r grep -n 'console\.log(' 2>/dev/null)
  IF G5_RESULT not empty:
    FOR each match: GAPS += "AUTO-SCAN: console.log in [file] (line [N])"

  # Append vào feature's gaps_identified
  $FEATURE_IMPL_MAP[feature.id].gaps_identified += GAPS
```

**Performance:** grep patterns chạy nhanh (<2s cho 100 files), không đáng kể so với tổng thời gian Phase 1.5.

**Scope giới hạn:** Chỉ scan files trong `existing_code_refs[]` của feature đó, không scan toàn bộ repo.

---

## §Implementation Overview Display (Step 1.5.4 chi tiết)

```
📊 Feature Implementation Overview (Legacy Project)
────────────────────────────────────────────────────
VERIFY_ONLY:      N features (chỉ verify + annotate, không code mới)
COMPLETE_EXISTING: M features (bổ sung phần thiếu, không rewrite)
IMPLEMENT_NEW:     K features (TDD đầy đủ)

Tổng effort ước lượng: ~Xh

Bạn có muốn điều chỉnh strategy cho feature nào không? (yes/no)
```

> Cho phép user điều chỉnh strategy nếu cần (ví dụ: đổi VERIFY_ONLY → COMPLETE_EXISTING nếu code cũ cần cải thiện).

---

## POST-GATE

- Mọi feature đã được gán `implementation_strategy`
- User đã review overview

---

## Next

→ Checkpoint: position → `phase_2`
→ Read `procedures/phase2-deps.md`
