# 06 — Registry Safe-Write Protocol (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-006, CORE-008, CORE-009, CORE-010)
> **File gốc canonical:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4a, [`.claude/skills/protocols/05-registry-safe-write.md`](../../.claude/skills/protocols/05-registry-safe-write.md)
> **Mục đích:** Định nghĩa **ai được phép update field nào** trong `req-registry.json` — tránh skill này ghi đè ownership của skill khác

---

## 1. Triết lý — tại sao cần Safe-Write?

`req-registry.json` là **Single Source of Truth** của toàn dự án (CORE-004). Nó chứa:

- `systems[]`, `modules[]`, `departments[]` — phân cấp dự án
- `requirements[]` — danh sách REQ-ID + metadata + `impl_status`
- `features[]` — danh sách FEAT-ID + dependencies + `impl_status`
- `implementation_order`, `design_status`, `ux_design_status` — trạng thái phase
- `interface_type`, `locale` — meta dự án

Nếu **mọi skill được phép write toàn bộ file**, sẽ xảy ra:

- Skill A set `requirements[X].impl_status = "done"` → Skill B "tiện thể" downgrade về `not_started` vì code scan không tìm thấy → mất audit trail
- 2 skills cùng update `requirements[].priority` → race condition, value bị overwrite
- Skill upstream tạo entry → skill downstream xóa "vì không cần" → SSOT bị thủng

**Safe-Write Protocol** chốt: mỗi field có **đúng 1 PRIMARY owner**, các skill khác chỉ được làm hành động bị giới hạn (SEED/APPEND/SAFE-UPDATE/...).

---

## 2. Bảy `write_role` hợp lệ

| Role | Mô tả | Quyền |
|------|-------|-------|
| **PRIMARY** | Skill là owner chính | Write đầy đủ — thêm/sửa/xóa entries trong scope |
| **SEED** | Skill init 1 lần đầu | Write 1 lần khi tạo, không sửa sau |
| **APPEND** | Chỉ thêm entries mới | Không modify/delete/rename existing |
| **SAFE-UPDATE** | Chỉ upgrade `impl_status` | `not_started`/`in_progress` → `done`, KHÔNG downgrade |
| **FIX-INVALID** | Chỉ sửa giá trị invalid | Vd: thiếu default → set `not_started` |
| **UPDATE-MODE** | Update theo `change_type` | MODIFY/ADD/DELETE/CLARIFY (vd: wf-manage-change) |
| **NONE** | Không update registry | Phải có notes giải thích delegate sang ai |

---

## 3. Bảng phân công đầy đủ

| Skill | Field | Role | Ghi chú |
|-------|-------|------|---------|
| `/wf-brainstorm` | `project`, `departments[]`, `interface_type`, `locale` | SEED | Ghi 1 lần ở Phase 5.3. `locale` default `"vi"` |
| `/wf-analyze-requirements` | `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `interface_type` | PRIMARY | Owner requirement model |
| `/wf-define-features` | `features[]` (gồm `features[].impl_status`) | PRIMARY | Owner feature catalog |
| `/wf-define-features` | `impl_status` (per REQ-ID) | SAFE-UPDATE | Chỉ set `"skipped"` cho features thuộc module DEPRECATE |
| `/wf-design` | `design_status` | PRIMARY | — |
| `/wf-design-ux` | `ux_design_status` | PRIMARY | — |
| `/wf-plan-modules` | `implementation_order` | PRIMARY | — |
| `/wf-plan-modules` | `impl_status` (per REQ-ID) | SAFE-UPDATE | Chỉ set `"skipped"` cho features thuộc `$DEPRECATED_MODULES` |
| `/wf-implement-feature` | `impl_status` (per REQ-ID) | PRIMARY | Owner `impl_status` lifecycle |
| `/wf-verify-sync` | `impl_status` (per REQ-ID) | SAFE-UPDATE | KHÔNG downgrade `done` (CORE-008) |
| `/wf-fix-bugs` | — | NONE | Pure orchestrator |
| `/wf-fix-triage` | — | NONE | Triage only |
| `/wf-fix-execute` | `impl_status` (per REQ-ID) | SAFE-UPDATE | Phase 4a only |
| `/wf-fix-functional` … `/wf-fix-compat` | — | NONE | Spawned sub-skills — signals only |
| `/wf-fix-observability` `/wf-fix-runtime-health` `/wf-fix-integration` `/wf-fix-business-completeness` | — | NONE | Spawned sub-skills (QD8-QD11) |
| `/wf-design` (legacy flow) | `design_status` + `systems[]`, `modules[]`, `departments[]`, `requirements[]`, `features[]`, `interface_type` | PRIMARY | Registry build khi legacy flow thiếu seed |
| `/wf-design` (legacy flow) | `requirements[].impl_status` | FIX-INVALID | Chỉ fix invalid → `not_started` |
| `/wf-annotate-code` | — | NONE | Chỉ sửa REQ-ID comments trong code files |
| `/wf-add-scope` | `modules[]`, `features[]` | APPEND | Idempotent, dedup theo ID |
| `/wf-manage-change` | `requirements[]`, `features[]`, `impl_status` | UPDATE-MODE | Theo `change_type` |
| `/wf-legacy-scan`, `/wf-legacy-classify`, `/wf-legacy-extract` | — | NONE | Build inventory/extracted artifacts, không đụng registry |

**Lưu ý quan trọng:**
- Bảng trên là **mirror** của canonical [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4a — khi mâu thuẫn, §4a thắng
- Khi thêm skill mới: bổ sung entry vào §4a TRƯỚC, đồng bộ Protocol 5, đồng bộ bảng này

---

## 4. 4 quy tắc Safe-Write (CORE-006)

```
1. ĐỌC registry NGAY TRƯỚC KHI GHI — không cache từ đầu session
2. CHỈ MODIFY fields được phân công — giữ nguyên mọi fields khác
3. GHI ATOMIC — single write operation cho toàn bộ JSON
4. VALIDATE sau ghi — `jq '.' registry.json` phải pass
```

### 4.1. Vì sao "đọc ngay trước khi ghi"?

Trong cùng session, registry có thể đã được sửa bởi skill spawn song song. Cache từ đầu session → ghi đè thay đổi của skill khác.

```bash
# ❌ SAI — cache từ đầu session
REGISTRY=$(cat req-registry.json)   # at session start
# ... 30 phút sau ...
echo "$REGISTRY" | jq '...' > req-registry.json   # ghi đè thay đổi mới

# ✅ ĐÚNG — đọc ngay trước khi ghi
CURRENT=$(cat req-registry.json)   # right before write
UPDATED=$(echo "$CURRENT" | jq '...')
echo "$UPDATED" > req-registry.json.tmp
mv req-registry.json.tmp req-registry.json
```

### 4.2. Vì sao "chỉ modify fields được phân công"?

```bash
# ❌ SAI — "tiện thể" sửa thêm
jq '
  (.requirements[] | select(.id == "REQ-001")).impl_status = "done"
  | (.requirements[] | select(.id == "REQ-001")).priority = "HIGH"
' registry.json
# priority là của wf-define-features (PRIMARY) — wf-implement-feature không được sửa

# ✅ ĐÚNG — chỉ update đúng phần được giao
jq '
  (.requirements[] | select(.id == "REQ-001")).impl_status = "done"
' registry.json
```

### 4.3. Atomic write pattern

```bash
# 1. Build vào tmp
jq '...' registry.json > registry.json.tmp.$$

# 2. Validate
jq '.' registry.json.tmp.$$ > /dev/null || { rm registry.json.tmp.$$; exit 1; }

# 3. Atomic move
mv registry.json.tmp.$$ registry.json
```

Tránh trường hợp partial write → file invalid → mọi skill crash.

---

## 5. `impl_status` lifecycle (CORE-008, CORE-010)

`impl_status` chỉ có 4 giá trị (CORE-010):

```
"not_started"  (default)
   ↓
"in_progress"
   ↓
"done"
   ↓
"skipped"   (chỉ wf-define-features/wf-plan-modules set, lý do DEPRECATE)
```

### 5.1. Quy tắc lifecycle

```
not_started → in_progress    OK (wf-implement-feature start)
in_progress → done           OK (wf-implement-feature complete)
not_started → done           OK (verify-sync detect code đã có sẵn)
done → not_started           ❌ DOWNGRADE — CORE-008 cấm
done → in_progress           ❌ DOWNGRADE — CORE-008 cấm
done → skipped               ❌ DOWNGRADE — CORE-008 cấm
* → skipped                  OK chỉ khi module thuộc DEPRECATE list
```

### 5.2. CORE-008 — KHÔNG downgrade `done`

```
NẾU verify-sync scan code không tìm thấy REQ-ID đã marked `done`:
  → KHÔNG downgrade `impl_status` về `not_started`
  → THAY VÀO: log warning + trigger CDG-03 (hỏi user)
  → User quyết định: keep `done` (có thể code rename) hoặc manual fix
```

**Vì sao:** Code có thể bị rename file, REQ-ID comment có thể lệch chuẩn nhưng functionality vẫn có. Auto-downgrade → audit trail false negative → tin cậy SSOT bị phá.

### 5.3. SAFE-UPDATE checklist

| Skill | Trước update | Sau update |
|-------|-------------|-----------|
| `wf-implement-feature` | `impl_status = "not_started"` | `impl_status = "done"` |
| `wf-verify-sync` | `impl_status = "in_progress"` (verified bằng code) | `impl_status = "done"` |
| `wf-verify-sync` | `impl_status = "done"` (code không tìm thấy) | KEEP `"done"` + WARN + CDG-03 |
| `wf-fix-execute` Phase 4a | `impl_status = "done"` (sau fix) | KEEP `"done"` |

---

## 6. Schema validation (CORE-009)

KHÔNG validate registry chỉ bằng `test -f`. PHẢI check content:

```bash
# ❌ SAI — chỉ check file tồn tại
test -f req-registry.json || exit 1

# ✅ ĐÚNG — check JSON valid + có nội dung
jq -e '.requirements | length > 0' req-registry.json > /dev/null || {
  echo "Registry rỗng hoặc invalid. Chạy /wf-brainstorm hoặc /existing-project trước."
  exit 1
}
```

**Forensic validation** ở entry PRE-GATE (CORE-011):
- T1: `test -s registry.json` (non-empty)
- T2: `jq '.'` (JSON valid)
- T3: `jq -e '.requirements | length > 0'` (có ≥1 requirement)
- T4: Tham chiếu chéo với upstream `phase1-business/`

---

## 7. APPEND-only pattern (wf-add-scope)

`wf-add-scope` có role **APPEND** cho `modules[]`, `features[]`. Yêu cầu **idempotent + dedup**:

```bash
# Đọc registry hiện tại
existing_ids=$(jq -r '.features[].id' registry.json | sort -u)

# Chỉ thêm new IDs (not in existing)
new_features=$(echo "$proposed_features" | jq --argjson existing "$existing_ids" '
  map(select(.id as $id | $existing | index($id) | not))
')

# Concatenate + sort by id để deterministic
jq --argjson new "$new_features" '.features = (.features + $new | unique_by(.id))' registry.json > tmp
mv tmp registry.json
```

**Tại sao idempotent:** User có thể chạy `wf-add-scope` 2 lần với cùng input. Nếu không dedup → duplicate entries, audit trail noise.

---

## 8. UPDATE-MODE pattern (wf-manage-change)

`wf-manage-change` có role **UPDATE-MODE** — update theo `change_type`:

| `change_type` | Hành động |
|---------------|-----------|
| `ADD` | Thêm REQ-ID/FEAT-ID mới (như APPEND) |
| `MODIFY` | Update field cũ (vd: description, priority) |
| `DELETE` | Xóa REQ-ID/FEAT-ID — TRIGGER CDG-04 trước khi xóa |
| `CLARIFY` | Update description nhưng không thay đổi semantic |

**Quy tắc DELETE:**
- CDG-04 BẮT BUỘC (hiển thị dependencies, hỏi user)
- Update mọi reference khác trong registry (vd: `features[].depends_on[]`)
- Log vào `change-impact.json` audit trail

---

## 9. Ví dụ Pass/Fail

### ✅ PASS — Safe-Write đầy đủ

```
wf-implement-feature complete FEAT-CRM-001:
  1. Read registry.json (RIGHT BEFORE write)
  2. jq update:
     - features[id="FEAT-CRM-001"].impl_status = "done"
     - requirements[id="REQ-CRM-001"].impl_status = "done"
     - KHÔNG đụng priority, dependencies, business_rules
  3. Write registry.json.tmp.$$ → validate jq '.' → mv tmp registry.json
  4. POST-validate: jq -e '.features[] | select(.id == "FEAT-CRM-001").impl_status == "done"'
  → PASS
```

### ❌ FAIL — Wide-write + downgrade

```
wf-verify-sync scan code không thấy REQ-CRM-001:
  1. Set impl_status = "not_started" (DOWNGRADE done→not_started)
  2. "Tiện thể" set priority = "LOW" (priority là của wf-define-features)
  3. Update version bump trong registry meta (không phải scope của skill)
  → 3 vi phạm:
     - CORE-008: downgrade done
     - CORE-006: wide-write priority
     - CORE-006: meta version không thuộc scope
```

---

## 10. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Cache registry từ session start | Đọc ngay trước khi write |
| `done → not_started` (downgrade) | Keep `done` + CDG-03 hỏi user (CORE-008) |
| Skill SAFE-UPDATE sửa priority/description | Chỉ sửa `impl_status` |
| 2 skills cùng PRIMARY 1 field | 1 field = 1 PRIMARY |
| Append `modules[]` không dedup | Idempotent: dedup theo `.id` |
| Delete REQ-ID không CDG-04 | CDG-04 BẮT BUỘC trước DELETE |
| Write registry không validate sau | `jq '.' registry.json` sau write |
| Set `impl_status = "completed"` (sai enum) | Chỉ 4 giá trị CORE-010 |
| Wide-write toàn bộ object thay vì update field | jq update single path |
| Sửa `features[].impl_status` từ skill chưa được phân quyền | Đọc bảng §3 — check role trước |

---

## 11. Checklist khi skill update registry

**Trước khi merge:**
- [ ] `_contract.json` có `registry_scope.write_role` = 1 trong 7 giá trị hợp lệ
- [ ] `fields_owned[]` liệt kê đầy đủ field skill được sửa
- [ ] `notes` giải thích nếu role NONE (delegate sang skill nào)
- [ ] Code skill: read registry ngay trước khi write (không cache)
- [ ] Code skill: atomic write pattern (tmp → validate → mv)
- [ ] Code skill: validate sau write (`jq '.' registry.json`)
- [ ] Nếu DELETE/rename: trigger CDG-04
- [ ] Nếu downgrade `done`: trigger CDG-03
- [ ] Đồng bộ entry trong `.claude/rules/00-core.md` §4a + Protocol 5
- [ ] Đồng bộ entry trong bảng §3 này

---

## 12. Compliance audit

Script `./.claude/scripts/skill-compliance-audit.sh` kiểm tra:

- ✅ `registry_scope.write_role` thuộc 7 giá trị hợp lệ
- ✅ `fields_owned[]` không conflict với skill khác cùng role PRIMARY
- ✅ Mọi skill có write registry phải có `safe_write_rule: "CORE-006"` reference

Manual check:
```bash
# Tìm skill nào claim PRIMARY field "priority":
jq -r '.skill + ": " + (.registry_scope.fields_owned | tostring)' \
  .claude/skills/workflow/*/\_contract.json \
  | grep PRIMARY
```

---

## 13. Liên kết

- **Canonical bảng phân công:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4a
- **Protocol 5 (mirror):** [`.claude/skills/protocols/05-registry-safe-write.md`](../../.claude/skills/protocols/05-registry-safe-write.md)
- **Rule liên quan:** CORE-006, CORE-008, CORE-009, CORE-010, CORE-027 (CDG-03/04)
- **Contract schema:** [`04-contract-schema.md`](04-contract-schema.md) §7
- **Quality gates:** [`05-quality-gates.md`](05-quality-gates.md) §4 CDG
