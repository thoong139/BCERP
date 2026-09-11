# Phase 7: Tạo Output Files

> Tạo Phase 5 implementation docs (module-plan, dependency-graph, roadmap, sprints) + update registry.

> **Shared context:** xem `_shared.md` — Implementation Order Schema, Registry Safe-Write, Token Limit Prevention.

---

## PRE-GATE

`test -n "$LAYERS"`

> **`--graph` shortcut:** Nếu `--graph` flag → chỉ tạo `dependency-graph.md` (step 7.3), bỏ qua steps khác → nhảy Phase 7a.

---

## 📥 INPUT

- `$LAYERS` (in-memory từ Phase 4)
- `$SYSTEM_COVERAGE_MAP` + `$COVERAGE_STRATEGY` (in-memory từ Phase 1.7)
- Registry (đọc lại trước khi ghi — Safe-Write)
- Feature files (`phase2-features/`)
- doc-framework templates

## 📤 OUTPUT

| File | Đường dẫn | Template |
|------|-----------|---------|
| Module plan | `.mc-data/docs/phase5-implementation/module-plan.md` | — (tổng hợp inline từ LAYERS) |
| Dependency graph | `.mc-data/docs/phase5-implementation/dependency-graph.md` | `.claude/doc-framework/_meta/dependency-graph.md` |
| Implementation roadmap | `.mc-data/docs/phase5-implementation/P5-00-implementation-roadmap.md` | `.claude/doc-framework/phase5-implementation/P5-00-implementation-roadmap.md` |
| Sprint plans | `.mc-data/docs/phase5-implementation/sprints/S0[N]-[name].md` | `.claude/doc-framework/phase5-implementation/sprints/S01-sprint-template.md` |
| Registry | `.mc-data/docs/_meta/req-registry.json` | — (safe-write: chỉ field `implementation_order`) |

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 7.1 | `mkdir -p .mc-data/docs/phase5-implementation/sprints/` | Directories exist |
| 7.2 | **Atomic write — module-plan.md:** Ghi `module-plan.md` — BẮT BUỘC chứa section `## System Coverage` (xem §Module-Plan Rules). `TMP=$(mktemp .mc-data/docs/phase5-implementation/.tmp.XXXXXX)` → generate content → WRITE `$TMP` → validate (`grep -q "## System Coverage" $TMP`) → `mv $TMP .mc-data/docs/phase5-implementation/module-plan.md` | `test -s module-plan.md` + `grep -q "## System Coverage"` |
| 7.3 | **Template Usage Rule + Atomic write:** READ `.claude/doc-framework/_meta/dependency-graph.md` → populate với LAYERS data → WRITE `.tmp` → validate → `mv` to `.mc-data/docs/phase5-implementation/dependency-graph.md` | `test -s dependency-graph.md` |
| 7.4-LOCK | **[Cross-Process Mutex — BẮT BUỘC]** Acquire registry lock TRƯỚC §Registry Update. Xem `_shared.md §Cross-Process Mutex (Phase 7 Step 7.4)`. Pattern: `acquire_registry_lock \|\| exit 1; trap release_registry_lock EXIT`. Timeout 30s → fail E_REGISTRY_LOCK_TIMEOUT. Lý do: parallel-safe khi user chạy `wf-implement-feature` song song. Release lock NGAY sau atomic mv ở step 5. | Lock acquired |
| 7.4 | Update `req-registry.json` field `implementation_order` (xem §Registry Update) — đã có atomic write tại §Registry Update step 5. **Sau atomic mv → `release_registry_lock` ngay.** | `jq '.' req-registry.json` + lock released |
| 7.5 | **Template Usage Rule + Atomic write:** READ `.claude/doc-framework/phase5-implementation/P5-00-implementation-roadmap.md` → populate → WRITE `.tmp` → `mv` to `P5-00-implementation-roadmap.md` — **skip nếu file đã tồn tại và non-empty** (`test -f ... && test -s ...`) | `test -s P5-00-implementation-roadmap.md` |
| 7.5b | **`--skip-sprints` Gate:** `IF $HAS_SKIP_SPRINTS_FLAG = "true"` → SKIP steps 7.6 và 7.7 (không tạo bất kỳ sprint file nào) → nhảy thẳng POST-GATE. Log: "Sprint file generation skipped (--skip-sprints flag)." | Gate evaluated |
| 7.6 | **Template Usage Rule + Atomic write:** READ `.claude/doc-framework/phase5-implementation/sprints/S01-sprint-template.md` → populate với Layer 0 modules → WRITE `.tmp` → `mv` to `sprints/S01-foundation.md` — **skip nếu file đã tồn tại và non-empty** | `test -s sprints/S01-foundation.md` |
| 7.7 | **Template Usage Rule + Atomic write:** READ `.claude/doc-framework/phase5-implementation/sprints/S01-sprint-template.md` (cùng template) → populate với Layer N modules → WRITE `.tmp` → `mv` to `sprints/S02+` nếu cần — **skip từng file đã tồn tại và non-empty** | Files created |

---

## §Registry Update (Step 7.4 chi tiết)

```
1. Đọc registry NGAY LẬP TỨC (không cache từ Phase 1):
   REGISTRY=$(cat .mc-data/docs/_meta/req-registry.json)

2. Build implementation_order theo canonical schema (xem _shared.md §Implementation Order Schema)

3. Nếu LEGACY_MODE = true AND $DEPRECATED_MODULES không rỗng:
   a. Tìm TẤT CẢ features thuộc $DEPRECATED_MODULES có impl_status CHƯA phải "skipped":
      AFFECTED_FEATURES=$(jq -c --argjson deprecated "$DEPRECATED_JSON" \
        '[.features[] | select(.module_id as $m | $deprecated | index($m))
         | select(.impl_status != "skipped")
         | {feat_id, req_id, module_id, current_status: .impl_status}]' \
        .mc-data/docs/_meta/req-registry.json)

   b. Lọc subset các features đang "done" bị downgrade:
      DOWNGRADE_FROM_DONE=$(echo "$AFFECTED_FEATURES" | jq '[.[] | select(.current_status == "done")]')
      DOWNGRADE_COUNT=$(echo "$DOWNGRADE_FROM_DONE" | jq 'length')

   c. **CDG-03 + CDG-04 trigger (CORE-027, Protocol 16 §16.2)** — BẮT BUỘC khi DOWNGRADE_COUNT > 0:
      Hiển thị:
        ⚠️ [CDG-03] [CDG-04] Critical Decision — Downgrade impl_status done → skipped
        ──────────────────────────────────────────────────────────────────
        Lý do: User đã quyết định DEPRECATE các modules sau (từ wf-brainstorm Phase 0.5).
        Tất cả features thuộc các modules này (bao gồm features đã hoàn thành) sẽ bị set "skipped".

        Modules DEPRECATED: $DEPRECATED_JSON
        Số features bị ảnh hưởng: $(echo "$AFFECTED_FEATURES" | jq 'length')
        Trong đó SẼ downgrade từ "done": $DOWNGRADE_COUNT features

        Chi tiết features done → skipped:
        $(echo "$DOWNGRADE_FROM_DONE" | jq -r '.[] | "- \(.feat_id) (module \(.module_id)) — REQ: \(.req_id)"')

        Hậu quả không thể undo: impl_status "done" sẽ mất, registry không lưu giá trị cũ.
        Code đã viết VẪN còn trên disk nhưng sẽ bị coi là dead code cho đến khi wf-implement
        hoặc user khôi phục module.

      AskUserQuestion (batch accept theo Protocol 16 §16.3 rule 6):
        (a) [ACCEPT ALL] — Đồng ý downgrade tất cả $DOWNGRADE_COUNT features
        (b) [REJECT] — Hủy bỏ, giữ nguyên impl_status hiện tại (registry không thay đổi cho features done)
        (c) [REVIEW] — Hủy thao tác này, chạy lại wf-brainstorm Phase 0.5 để điều chỉnh DEPRECATE list

      Ghi log CDG vào `.mc-data/work/wf-plan-modules/cdg-tokens.json`:
        {"cdg_id": "CDG-03+CDG-04", "action": "downgrade_done_to_skipped",
         "features": [...], "user_decision": "accept|reject|review",
         "decided_at": "<NOW>", "severity_class": "critical"}

      Nếu user REJECT/REVIEW → SKIP bước 3d/3e/4, chỉ update implementation_order ở bước 5 (không touch features[].impl_status).

   d. Nếu user ACCEPT — tạo backup snapshot:
      jq -c --argjson deprecated "$DEPRECATED_JSON" \
        '{timestamp: "<NOW>", deprecated_modules: $deprecated,
          features_snapshot: [.features[] | select(.module_id as $m | $deprecated | index($m))
                              | {feat_id, req_id, module_id, previous_status: .impl_status}]}' \
        .mc-data/docs/_meta/req-registry.json \
        > .mc-data/work/wf-plan-modules/deprecated-snapshot.json
      # Audit trail cho phép user manual-restore nếu cần

4. Update field implementation_order trong registry (giữ nguyên mọi fields khác).

5. Atomic write — narrow per-field jq operation (A3-H2 fix: KHÔNG ghi đè toàn bộ features[]):
   # Bước 5a: Update implementation_order (single top-level field, safe)
   TMP="$(mktemp .mc-data/docs/_meta/.reg.tmp.XXXXXX)"
   jq --argjson new_order "$NEW_ORDER" '.implementation_order = $new_order' \
     .mc-data/docs/_meta/req-registry.json > "$TMP" \
     && mv "$TMP" .mc-data/docs/_meta/req-registry.json \
     || { rm -f "$TMP"; exit 1; }

   # Bước 5b: IF ACCEPT — update impl_status PER feature (chỉ touch field impl_status,
   # KHÔNG replace toàn bộ .features array để tránh drop fields khác của feature).
   if [ "$CDG_DECISION" = "accept" ] && [ "$DOWNGRADE_COUNT" -gt 0 ]; then
     for FEAT_ID in $(echo "$AFFECTED_FEATURES" | jq -r '.[].feat_id'); do
       TMP="$(mktemp .mc-data/docs/_meta/.reg.tmp.XXXXXX)"
       jq --arg fid "$FEAT_ID" \
         '(.features[] | select(.feat_id == $fid) | .impl_status) = "skipped"' \
         .mc-data/docs/_meta/req-registry.json > "$TMP" \
         && mv "$TMP" .mc-data/docs/_meta/req-registry.json \
         || { rm -f "$TMP"; echo "FAIL update $FEAT_ID"; exit 1; }
     done
   fi

6. Validate: jq -e '.implementation_order | length > 0' .mc-data/docs/_meta/req-registry.json
```

---

## §Module-Plan Rules (Step 7.2 chi tiết)

File `module-plan.md` BẮT BUỘC có section `## System Coverage` cuối file, liệt kê TẤT CẢ systems trong registry (covered + orphan + thin_client). Structure:

```markdown
## System Coverage

**Coverage Strategy:** [full | placeholders | thin_clients]
**Coverage Summary:** [X]/[Y] systems planned ([percent]%)

| System ID | Name | Modules | Features | Status | Ghi chú |
|-----------|------|---------|----------|--------|---------|
| SYS-XXX   | ...  | N       | M        | ✅ COVERED / ⚠️ ORPHAN / ℹ️ THIN_CLIENT | ... |

### Orphan Systems (nếu có)
- **SYS-XXX** — [reason từ user tại Phase 1.7]
  - Placeholder: `tasks/[sys-slug]/_NO-FEATURES.md`

### Thin Client Systems (nếu có)
- **SYS-XXX** — [reason: e.g., "chỉ gọi API Backend, không có business logic riêng"]
```

**Rules cho section `## 1. Tổng Quan Hệ Thống` (đầu file):**

- ❌ KHÔNG đưa % completion giả định (`~90%`, `~50%`, v.v.) trừ khi có dữ liệu thực
  từ `impl-status-snapshot.json` (chỉ LEGACY_MODE)
- ❌ KHÔNG liệt kê orphan systems trong section này — tách xuống `## System Coverage`
- ✅ CHỈ liệt kê systems có `modules_count > 0` (tức đã `COVERED`)
- ✅ Số cột "Modules" và "Features" phải khớp chính xác với `$SYSTEM_COVERAGE_MAP`

---

## POST-GATE

- T1 Existence: `module-plan.md`, `dependency-graph.md`, `P5-00-implementation-roadmap.md` tồn tại + non-empty (`test -s`)
- T1 Existence: Sprint files tồn tại (trừ khi `--skip-sprints`)
- T1 Existence: Registry `implementation_order` field updated với canonical schema (`jq '.'`)
- T2 Structure: `module-plan.md` có section `## System Coverage` (`grep -q`)
- T3/T4 Content depth + Cross-reference: được thực hiện ở Phase 7a (dedicated verification phase) — xem `procedures/phase7a-verify.md`

---

## Next

→ Checkpoint: position → `phase_7.5.0` (orphan) / `phase_7.5`
→ Nếu `$COVERAGE_STRATEGY == "placeholders"` AND có orphan → Read `procedures/phase7.5.0-orphan.md`
→ Else → Read `procedures/phase7.5-tasks.md`
