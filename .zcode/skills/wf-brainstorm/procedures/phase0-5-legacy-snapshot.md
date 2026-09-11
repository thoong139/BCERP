# Phase 0.5: Legacy Project Snapshot

> CHỈ chạy khi `$LEGACY_MODE = true` (detected ở phase0-detect-route.md).
> Mục đích: Hiển thị context từ legacy scan cho user, thu thập user intent, tạo `legacy-decisions.json` (CORE-022).

**PRE-GATE:**

- [ ] `$LEGACY_MODE = true`
- [ ] `.mc-data/work/legacy-scan/project-context.md` tồn tại và size > 500 bytes
- [ ] `$LEGACY_CONTEXT` đã load (từ Phase 0)

**INPUT:** `.mc-data/work/legacy-scan/project-context.md`, optional `extracted/{module}-divergences.json`

**OUTPUT:**
- `.mc-data/work/wf-brainstorm/user_intent.md`
- `.mc-data/work/wf-brainstorm/legacy-decisions.json` (BẮT BUỘC)
- `.mc-data/work/wf-brainstorm/divergence-resolution.json` (chỉ S5)
- `.mc-data/work/wf-brainstorm/vision-reconciliation.json` (chỉ S6)

---

## Reference: Strategy Codes (đọc từ `project-context.md` field `scan_strategy`)

| Code | Ý nghĩa | Nguồn |
|------|---------|-------|
| S1 | Greenfield — không có code cũ | wf-legacy-scan Stage 0 |
| S2 | Thin layer — ít code, tài liệu là chủ yếu | wf-legacy-scan Stage 1 |
| S3 | Standard migration — code + docs đồng bộ | wf-legacy-scan Stage 2 |
| S4 | Undocumented code — code nhiều, tài liệu thiếu | wf-legacy-scan Stage 3 |
| S5 | Divergence — code và docs mâu thuẫn nhau | wf-legacy-scan Stage 4 |
| S6 | Re-Vision — yêu cầu thay đổi hướng lớn | wf-legacy-scan Stage 5 |

---

## Step 0.5.1: Đọc project-context.md

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.5.1 | Read `.mc-data/work/legacy-scan/project-context.md` → tóm tắt thân thiện cho user | Read | Content loaded |

---

## Step 0.5.1b: Đọc `doc-quality-map.json` (optional trust display)

```bash
DOC_MAP=".mc-data/work/legacy-scan/doc-quality-map.json"
if test -s "$DOC_MAP"; then
  TOTAL_DOCS=$(jq '.docs | length' "$DOC_MAP")
  TRUSTED=$(jq '[.docs[] | select(.trust_level == "high" or .trust_level == "medium")] | length' "$DOC_MAP")
  OUTDATED=$(jq '[.docs[] | select(.trust_level == "low" or .is_outdated == true)] | length' "$DOC_MAP")
  # Đưa vào snapshot box ở Step 0.5.2
else
  TOTAL_DOCS=0
  TRUSTED=0
  OUTDATED=0
fi
```

> Graceful degradation: nếu file không tồn tại → hiển thị "Tài liệu: chưa đánh giá".

---

## Step 0.5.2: Hiển thị Project Snapshot

```
┌─────────────────────────────────────────────────────┐
│  DEVKIT ĐÃ SCAN DỰ ÁN CỦA BẠN                     │
│  ─────────────────────────────────────────────────  │
│  Tech: [tech_stack từ project-context.md]           │
│  Hệ thống: [N] modules được phát hiện               │
│  Hoàn thiện: [X]% (ước lượng từ code)              │
│  Tài liệu: [$TOTAL_DOCS] files                      │
│    └─ Đáng tin cậy: [$TRUSTED] (high/medium trust)  │
│    └─ Cần review: [$OUTDATED] (low trust/outdated)  │
└─────────────────────────────────────────────────────┘
```

> Khi `$TOTAL_DOCS = 0` hoặc doc-quality-map.json không tồn tại → hiển thị "Tài liệu: chưa đánh giá" (bỏ 2 dòng con).

---

## Step 0.5.3: AskUserQuestion (1 lần, tối đa 3 câu)

> Protocol: Xem `_shared.md` §6 AskUserQuestion Protocol.

```
1. "Mục tiêu phát triển tiếp của bạn là gì?"
   (DEVKIT gợi ý dựa trên gaps detected trong project-context.md)
2. "Có module/tính năng nào DEVKIT hiểu sai không?"
3. "Có yêu cầu quan trọng nào DEVKIT bỏ sót không?"
```

---

## Step 0.5.4: Lưu user_intent.md

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.5.4 | Write `.mc-data/work/wf-brainstorm/user_intent.md` — nội dung: user's goals + corrections + additions từ Step 0.5.3 | Write | `test -s user_intent.md && size > 100 bytes` |

---

## Step 0.5.5: Xử lý Divergence (CHỈ khi `scan_strategy == S5`)

```
1. Đọc extracted/{module}-divergences.json
2. Hiển thị conflicts (tối đa 10): "Code nói X, Docs nói Y"
3. User chọn: Trust Code / Trust Docs / Manual
4. Lưu .mc-data/work/wf-brainstorm/divergence-resolution.json
```

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.5.5 | (S5 only) Đọc divergences → AskUserQuestion → Write divergence-resolution.json | Read + AskUserQuestion + Write | `test -f divergence-resolution.json` |

---

## Step 0.5.6: Xử lý Re-Vision (CHỈ khi `scan_strategy == S6`)

```
1. Đọc project-context.md để lấy hiện trạng codebase (architectural constraints, tech stack, module structure)
   Optional: đọc extracted/{module}.json nếu cần chi tiết per module
2. Thu thập vision mới từ user
3. Reconcile: KEEP/IMPROVE/NEW/DEPRECATE/REFACTOR
4. Lưu .mc-data/work/wf-brainstorm/vision-reconciliation.json
```

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.5.6 | (S6 only) Đọc current state → User vision → Reconcile → Write vision-reconciliation.json | Read + AskUserQuestion + Write | `test -f vision-reconciliation.json` |

---

## Step 0.5.7: Tạo `legacy-decisions.json` (BẮT BUỘC — TẤT CẢ strategies)

> CORE-022: File này là BRIDGE file — downstream skills phụ thuộc vào nó. KHÔNG được skip dù S3/S4.

```
Write `.mc-data/work/wf-brainstorm/legacy-decisions.json`

Nội dung:
- "scan_strategy": đọc từ project-context.md field scan_strategy
- "module_dispositions":
    S6: từ vision-reconciliation.json (có structured KEEP/DEPRECATE/IMPROVE decisions)
    S3/S4/S5: parse user_intent.md cho deprecation signals (keywords: "bỏ", "deprecate",
      "không dùng nữa", "thay thế bằng", "loại bỏ", "remove", "replace").
      Nếu user nói "module X không dùng nữa" ở Step 0.5.3 → thêm vào module_dispositions
      với action = "DEPRECATE". Nếu không có signal → [].
- "divergence_resolutions": từ divergence-resolution.json (nếu S5) hoặc []
- "scope_exclusions": từ user_intent.md section excluded scope
- "user_goals": tóm tắt ngắn gọn từ user_intent.md
- "trust_overrides": [] (default — user có thể cung cấp ở Step 0.5.3)
```

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.5.7 | Build legacy-decisions.json (luôn ghi, dù module_dispositions = []) | Write | `test -f legacy-decisions.json && jq empty legacy-decisions.json` |

> **RESUME logic:** Khi `--resume` và `legacy-decisions.json` đã tồn tại → KHÔNG ghi đè.
> User đã confirm decisions — re-creating sẽ mất customizations.
> Chỉ re-create nếu user chạy Phase 0.5 lại từ đầu (không `--resume`).

---

## POST-GATE Phase 0.5

- T1: `test -f .mc-data/work/wf-brainstorm/user_intent.md && wc -c < user_intent.md > 100`
- T2: `test -f .mc-data/work/wf-brainstorm/legacy-decisions.json` (LUÔN tồn tại)
- T3: `jq empty .mc-data/work/wf-brainstorm/legacy-decisions.json` (valid JSON)
- T4: (S5 only) `test -f .mc-data/work/wf-brainstorm/divergence-resolution.json`
- T5: (S6 only) `test -f .mc-data/work/wf-brainstorm/vision-reconciliation.json`

---

## Next Phase

→ **`phase1-collect-basic.md`** (chung pipeline với NEW project, có context legacy)

> Lưu ý: Khi sang Phase 1, các agent spawn ở Phase 2-4 PHẢI inject `$LEGACY_CONTEXT` + `legacy-decisions.json`.
> Xem `_shared.md` §12 LEGACY_MODE Context Injection.
