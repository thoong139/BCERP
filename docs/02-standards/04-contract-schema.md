# 04 — Contract Schema (BẮT BUỘC)

> **Mức độ ràng buộc:** BẮT BUỘC (CORE-007, CORE-031, CORE-036)
> **File gốc canonical:** [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md), [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4b + §4m
> **Mục đích:** Định nghĩa schema bắt buộc cho `_contract.json` per-skill + chuẩn cross-skill artifact contracts

---

## 1. Triết lý — tại sao có `_contract.json`?

`_contract.json` là **contract giữa skill và phần còn lại của MCV3**. Nó trả lời 3 câu hỏi:

1. **Skill này nhận gì?** — `inputs[]`, `prerequisites`, args, file PRE-GATE
2. **Skill này sản xuất gì?** — `outputs[]` với template + schema version
3. **Skill này nối với ai?** — `orchestrates[]`, `produces_for{}`, `consumes_from{}`

Trước v10.0 (wf-fix-bugs) và v5.0 (wf-legacy-scan), nhiều skill tự ý đổi output path hoặc consume artifact của skill khác **mà không có contract**. Hậu quả:

- `wf-design` đổi path output từ `phase3-architecture/` sang `phase3-design/` → `wf-plan-modules` PRE-GATE fail
- `wf-fix-bugs` consume `fix-impact.json` nhưng không validate `$schema` → silent breakage khi schema đổi
- 2 skills cùng ghi `req-registry.json` `priority` field → race condition

`_contract.json` chốt: **mỗi output path là 1 contract**, **mỗi artifact phải versioned**, **consumer phải validate ở PRE-GATE**.

---

## 2. Schema top-level — `skill-contract-v1`

Bắt buộc các field sau (ví dụ từ `wf-fix-bugs/_contract.json`):

```json
{
  "$schema": "skill-contract-v1",
  "skill": "wf-fix-bugs",
  "version": "10.2.1",
  "phase": "phase5",
  "description": "Mô tả 1-2 câu — what, for whom, key features",

  "prerequisites": { /* §3 */ },
  "inputs": [ /* §4 */ ],
  "procedure": [ /* §5 */ ],
  "outputs": { /* §6 */ },
  "registry_scope": { /* §7 */ },
  "cross_skill_contracts": { /* §8 */ },
  "orchestrator_gates": [ /* §9 — optional */ ],
  "resume_routing": { /* §10 — optional */ },
  "errors": { /* §11 */ },
  "code_intelligence": { /* §12 — optional, nếu skill dùng CI */ },
  "evals": { /* §13 — optional */ }
}
```

### Mô tả field bắt buộc

| Field | Type | Quy tắc |
|-------|------|---------|
| `$schema` | string | LUÔN `"skill-contract-v1"` — consumer dùng để validate |
| `skill` | string | Tên skill, kebab-case, khớp folder name |
| `version` | semver | `X.Y.Z` — bump khi đổi schema output hoặc breaking behavior |
| `phase` | string | Vị trí trong 7-phase workflow: `phase0` … `phase6`, `pre-phase0`, `cross-cutting` |
| `description` | string | 1-2 câu — what + for whom, ghi rõ version changelog nếu cần |

---

## 3. `prerequisites` — file/state cần có trước khi chạy

```json
"prerequisites": {
  "files": [".mc-data/docs/_meta/req-registry.json"],
  "directories_any_of": ["src", "apps"],
  "registry_fields": ["requirements", "features"],
  "forensic_validation": "jq -e '.requirements | length > 0' req-registry.json + src/apps có >= 1 source file (CORE-011, Protocol 10.4)."
}
```

**Quy tắc:**
- `files[]` — file PHẢI tồn tại (T1 check)
- `directories_any_of[]` — ít nhất 1 thư mục trong list phải tồn tại
- `registry_fields[]` — field nào trong `req-registry.json` phải có dữ liệu
- `forensic_validation` — string mô tả T3 check (content depth), không phải executable; PRE-GATE phải chạy đúng câu lệnh này (CORE-011)

**Ví dụ:** `wf-legacy-scan` là entry point cho legacy path → `prerequisites.files: []` (chỉ cần project directory tồn tại).

---

## 4. `inputs` — CLI arguments

Có 2 style được chấp nhận:

**Style A (flat array — `wf-fix-bugs`):**
```json
"inputs": [
  {"name": "--scope", "type": "enum", "values": ["all", "system", "module"], "required": false, "default": "all"},
  {"name": "--profile", "type": "enum", "values": ["quick", "standard", "deep", "exhaustive"], "default": "standard"},
  {"name": "--resume", "type": "flag", "description": "Resume từ session checkpoint."}
]
```

**Style B (object với required/optional — `wf-legacy-scan`):**
```json
"inputs": {
  "required": [{"path": "<project-path>", "description": "..."}],
  "optional": [{"path": "...", "description": "..."}]
}
```

**Quy tắc:**
- Mỗi arg: `name`, `type` (`string` / `enum` / `flag` / `url`), `required` (boolean), `default` (nếu có), `description` (tiếng Việt)
- `--resume`, `--status`, `--dry-run` là flag chuẩn — mọi multi-phase skill nên có
- `description` PHẢI ngắn gọn (≤200 ký tự) — chi tiết để vào SKILL.md

---

## 5. `procedure` — danh sách procedure files (CORE-032)

```json
"procedure": [
  "procedures/_shared.md",
  "procedures/phase1-init.md",
  "procedures/phase2-scan.md",
  "...",
  "procedures/resume-status.md"
]
```

**Quy tắc (CORE-032):**
- Path tương đối từ skill folder
- Thứ tự = thứ tự lazy-load runtime
- `_shared.md` luôn đầu tiên
- `resume-status.md` luôn cuối cùng (nếu skill có `--resume`/`--status`)

Single-procedure skill (vd: `wf-legacy-scan`) có thể dùng dạng string:
```json
"procedure": "procedures/phase0-detection.md"
```

---

## 6. `outputs` — file/artifact skill sản xuất

```json
"outputs": {
  "working": [
    {
      "path": "$SESSION_DIR/fix-status.json",
      "template": "templates/phase1-init/fix-status.json",
      "schema": "fix-status-v1",
      "owner": "orchestrator (init), updated per phase",
      "notes": "SSOT phase state (7 phases). Atomic Write."
    }
  ],
  "docs": [],
  "registry": {
    "action": "none",
    "description": "Orchestrator KHÔNG ghi req-registry.json. Delegate sang wf-fix-execute."
  }
}
```

### 6.1. `outputs.working[]` — runtime artifacts

| Field | Bắt buộc | Mô tả |
|-------|---------|-------|
| `path` | ✅ | Absolute hoặc dùng biến `$SESSION_DIR`. Placeholder `{N}`, `{id}`, `{slug}` cho dynamic paths |
| `template` | ✅ (CORE-031) | Path template file. `null` chỉ khi file APPEND-only (vd: `session-log.json`, `.lock`) |
| `schema` | ⚠️ Khi cross-skill | Schema version cho artifact được skill khác consume (vd: `fix-impact-v1`, `change-impact-v1`) |
| `owner` | ⚠️ Khi delegate | Ai write file này (nếu khác orchestrator). Vd: `wf-fix-triage`, `wf-fix-execute` |
| `notes` | Khuyến nghị | Mô tả purpose + write pattern (Atomic / APPEND / Init-once) |
| `required` | Optional | `true`/`false` — nếu `false` thì có thể skip trong một số mode |
| `condition` | Optional | Câu mô tả khi nào tạo file (vd: `"Chỉ tạo khi screen_count > 0"`) |
| `deprecated_in` | Optional | Version sẽ bỏ file này (backward-compat tracking) |

### 6.2. `outputs.docs[]` — file vào `.mc-data/docs/`

Tài liệu nghiệp vụ — cùng schema field như `working[]`. Vd: `phase2-features/[sys]/[mod]/[feat].md`.

### 6.3. `outputs.registry` — quan hệ với `req-registry.json`

```json
"registry": {
  "action": "none"  // hoặc "seed" / "append" / "safe-update" / "primary"
}
```

Map sang `write_role` trong `registry_scope` (§7).

---

## 7. `registry_scope` — Safe-Write contract (CORE-006)

```json
"registry_scope": {
  "write_role": "SAFE-UPDATE",
  "fields_owned": [
    "requirements[].impl_status (chỉ upgrade not_started → in_progress → done)",
    "features[].impl_status"
  ],
  "safe_write_rule": "CORE-006, CORE-008",
  "notes": "KHÔNG đụng requirements[].priority — đó là của wf-define-features"
}
```

**`write_role` chỉ có 7 giá trị (CORE-006):**

| Role | Mô tả |
|------|-------|
| `PRIMARY` | Skill là owner, write đầy đủ tất cả field trong scope |
| `SEED` | Write 1 lần khi tạo (init), không sửa sau |
| `APPEND` | Chỉ thêm mới (modules[], features[]) — không sửa cũ |
| `SAFE-UPDATE` | Chỉ upgrade `impl_status` (không downgrade `done` → khác — CORE-008) |
| `FIX-INVALID` | Chỉ sửa entry invalid (vd: thiếu default) |
| `UPDATE-MODE` | Update theo `change_type` (vd: wf-manage-change) |
| `NONE` | Không update — phải có `notes` giải thích delegate sang ai |

**Bảng đầy đủ ai-update-cái-gì:** xem [`06-safe-write-protocol.md`](06-safe-write-protocol.md) (canonical: [`.claude/skills/protocols/05-registry-safe-write.md`](../../.claude/skills/protocols/05-registry-safe-write.md)).

---

## 8. `cross_skill_contracts` — quan hệ với skill khác (CORE-036)

Đây là phần **quan trọng nhất** của contract — định nghĩa producer↔consumer relationships.

### 8.1. `orchestrates[]` — skill spawn skill khác

```json
"orchestrates": [
  {
    "phase": 5,
    "skill": "wf-fix-triage",
    "trigger": "Phase 4 POST-GATE pass (N>0) + CDG handoff accepted",
    "passes": ["$SESSION_DIR/fix-status.json", "$SESSION_DIR/phase5-triage/issue-registry.json"],
    "validation": "jq -e '.phases.phase5.status == \"completed\"' + bug-triage.md tồn tại"
  }
]
```

**Field bắt buộc:** `skill`, `trigger` (mô tả khi nào spawn), `passes` (file/state truyền sang), `validation` (cách kiểm tra child skill hoàn thành).

### 8.2. `produces_for{}` — artifact cho skill khác consume

```json
"produces_for": {
  "wf-verify-sync": ["phase7-verify/fix-impact.json", "phase6-execute/fix-report.md"],
  "wf-prepare-deployment": ["phase7-verify/fix-impact.json"],
  "wf-implement-feature": ["phase7-verify/fix-impact.json (Pre-Implementation Safety enhanced)"]
}
```

**Quy tắc:**
- Key = tên skill consumer
- Value = list relative path (từ `$SESSION_DIR` hoặc `.mc-data/`)
- Mỗi artifact PHẢI có schema version trong `outputs.working[]` (CORE-036)

### 8.3. `consumes_from{}` — artifact đọc từ skill khác

```json
"consumes_from": {
  "wf-preflight": ["preflight-report.md (optional — consumed by Phase 4 QD7)"],
  "wf-legacy-scan": ["project-context.md (LEGACY_MODE detection CORE-021)"]
}
```

**Quy tắc:**
- Consumer PHẢI validate `$schema` ở PRE-GATE (T2 structure check)
- Artifact thiếu/version mismatch → WARN + graceful degradation (KHÔNG silent fail)

### 8.4. Quy tắc xuyên suốt

| ✅ Đúng | ❌ Sai |
|---------|--------|
| Path khớp `protocols/21-cross-skill-output-path-contract.md` | Tự đổi path không sync Protocol 21 |
| Artifact có `$schema` field trong template | Consumer đoán schema từ field names |
| Consumer validate version ở PRE-GATE | Silent consume → cascade error khi schema đổi |
| Khi đổi schema → bump major version + viết migration note | Đổi schema trong place, consumer bị surprise |

---

## 9. Artifact schema — `$schema` field BẮT BUỘC

Mọi cross-skill artifact JSON PHẢI có `$schema` ngay đầu file:

```json
{
  "$schema": "fix-impact-v1",
  "audit_chain": {
    "source": "$SESSION_DIR/fix-status.json",
    "checksum": "sha256:abc123..."
  },
  "data": { ... }
}
```

### Schema versioning rules

| Tình huống | Bump |
|-----------|------|
| Đổi tên field cũ, xóa field cũ, đổi semantic | **Major** (v1 → v2) — breaking |
| Thêm field mới optional, thêm enum value | **Minor** (v1 → v1.1) — non-breaking |
| Sửa lỗi typo trong description, không đổi data shape | **Patch** (v1.1 → v1.1.1) |

### Schema version pattern

```
{artifact-name}-v{major}[.{minor}[.{patch}]]
```

**Ví dụ thực tế:**
- `fix-impact-v1` (wf-fix-bugs Phase 7)
- `preflight-impact-v1` (wf-preflight Phase 7)
- `change-impact-v1` (wf-manage-change Phase 6)
- `lane-signals-v1` (wf-fix-bugs Phase 4 — internal)
- `issue-registry-v2` (wf-fix-bugs Phase 5 — bumped khi đổi schema)

### `audit_chain` — bắt buộc cho cross-skill artifact

```json
"audit_chain": {
  "source": "<path file gốc dùng để build artifact này>",
  "checksum": "sha256:<hash của source>"
}
```

Dùng để consumer biết artifact derived từ state nào → verify tính nhất quán.

---

## 10. `errors` — namespaced error codes (CORE-034)

```json
"errors": {
  "E001": {"code": "E001", "severity": "critical", "description": "POST-GATE fail sau 3 retries — DỪNG phase, escalate."},
  "E005": {"code": "E005", "severity": "info", "description": "N=0 issues — Hệ thống healthy, skip Phase 5-6 → jump Phase 7."},
  "E010": {"code": "E010", "severity": "high", "description": "Phase 1: CI PRE-GATE fail."}
}
```

**Quy tắc CORE-034:**

| Range | Phase | Ý nghĩa |
|-------|-------|---------|
| E001-E009 | Shared | Pipeline/session/lock chung |
| E010-E019 | Phase 1 | Init errors |
| E020-E029 | Phase 2 | ... |
| ... | ... | mỗi phase 1 range 10 codes |
| E090-E099 | CDG | User-facing decision gates |
| E100-E109 | Warnings | Recommendations, non-blocking |

**Per-error fields:** `code`, `severity` (`info`/`low`/`medium`/`high`/`critical`), `description` (tiếng Việt, mô tả + auto-fix strategy nếu có).

**Đăng ký error code mới:** xem [`08-error-code-registry.md`](08-error-code-registry.md) — KHÔNG được dùng code đã claim bởi skill khác.

---

## 11. `code_intelligence` — CI integration (CORE-033)

Nếu skill cần đọc/analyze code, BẮT BUỘC có section này:

```json
"code_intelligence": {
  "integration": true,
  "protocol": "20-code-intelligence.md",
  "role": "orchestrator",
  "pattern": "CI PRE-GATE Na/Nb/Nc → CI context injection into sub-skills",
  "ci_route_matrix": true,
  "ci_context_passes_to": ["wf-fix-triage", "wf-fix-execute"],
  "graceful_degradation": "Lock held → fallback Grep. Tool unavailable → fallback Grep/Glob. Zero regression."
}
```

**Field bắt buộc khi `integration: true`:**
- `protocol` — luôn `"20-code-intelligence.md"`
- `role` — `orchestrator` / `scan_acceleration` / `consumer`
- `pattern` — mô tả Na/Nb/Nc usage
- `graceful_degradation` — câu mô tả khi tool unavailable

Chi tiết tại [`../03-design-patterns/02-ci-first-integration.md`](../03-design-patterns/02-ci-first-integration.md).

---

## 12. `evals` — test cases

```json
"evals": {
  "primary": "evals/evals.json",
  "regression_tests": [
    {
      "id": "test-isg-name-narrowing",
      "path": "evals/regression-tests/test-isg-name-narrowing.sh",
      "covers_bug": "skill-issues-2026-05-09 #1",
      "description": "Verify isg_recommender với --scope=module --name=marketing.",
      "runtime_estimate_sec": 5
    }
  ],
  "e2e_tests": [ ... ],
  "ci_workflow": ".github/workflows/devkit-skill-tests.yml"
}
```

**Quy tắc:**
- `evals/evals.json` có ≥3 test cases (compliance audit yêu cầu)
- Mỗi regression test cover 1 bug cụ thể (`covers_bug` field)
- `runtime_estimate_sec` để CI biết test này có chạy nhanh hay slow

---

## 13. Ví dụ Pass/Fail

### ✅ PASS — Contract khớp pattern chuẩn

```json
{
  "$schema": "skill-contract-v1",
  "skill": "wf-verify-sync",
  "version": "3.0.0",
  "phase": "phase5",
  "description": "Verify REQ-ID-to-code traceability — input từ wf-implement-feature, output verify-sync-impact.json.",
  "prerequisites": {
    "files": [".mc-data/docs/_meta/req-registry.json"],
    "registry_fields": ["requirements", "features"],
    "forensic_validation": "jq -e '.requirements[] | select(.impl_status == \"done\") | length > 0'"
  },
  "outputs": {
    "working": [
      {
        "path": ".mc-data/work/wf-verify-sync/sessions/{id}/verify-sync-impact.json",
        "template": "templates/verify-sync-impact.json",
        "schema": "verify-sync-impact-v1",
        "notes": "Cross-skill artifact. Atomic Write. audit_chain.source = verify-sync.md."
      }
    ],
    "registry": {"action": "safe-update"}
  },
  "registry_scope": {
    "write_role": "SAFE-UPDATE",
    "fields_owned": ["requirements[].impl_status"],
    "safe_write_rule": "CORE-006, CORE-008"
  },
  "cross_skill_contracts": {
    "produces_for": {
      "wf-prepare-deployment": ["verify-sync-impact.json"]
    },
    "consumes_from": {
      "wf-implement-feature": ["impl-status.json"],
      "wf-fix-bugs": ["fix-impact.json (--from-fix-bugs)"]
    }
  }
}
```

### ❌ FAIL — Thiếu trường bắt buộc + breaking schema không tracked

```json
{
  "skill": "wf-bad-skill",
  "outputs": [".mc-data/work/wf-bad-skill/some-file.json"],
  "consumes": ["fix-impact.json"]
}
```

**Vi phạm:**
- Thiếu `$schema: "skill-contract-v1"` → audit fail (CORE-036)
- Thiếu `version`, `description`, `phase`
- `outputs` không có template field (CORE-031)
- `consumes` (sai key name — phải là `consumes_from`)
- Path `fix-impact.json` không có producer skill rõ ràng
- Không có `registry_scope` → ambiguous về Safe-Write contract

---

## 14. Anti-patterns — KHÔNG được làm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Output JSON không có `$schema` field | Mọi cross-skill artifact PHẢI có `$schema` (CORE-036) |
| Đổi schema không bump version | Bump major khi breaking, viết migration_notes |
| Consumer đoán schema từ field names | Validate `$schema` ở PRE-GATE T2 |
| Output path hardcode trong code, không đăng ký `_contract.json` | Mọi path PHẢI đăng ký + khớp Protocol 21 |
| `registry.action` "primary" cho 2 skill cùng field | 1 field = 1 PRIMARY owner |
| Template thiếu — chỉ ghi `"template": null` cho file không phải APPEND-only | `template: null` CHỈ cho `.lock`, `*-log.json` (APPEND), `events.jsonl` |
| Error code trùng skill khác | Đăng ký namespace tại [`08-error-code-registry.md`](08-error-code-registry.md) |
| `consumes_from{}` thiếu key skill nào artifact lấy từ | Liệt kê đầy đủ — `wf-legacy-scan: [...]` |
| `audit_chain` thiếu trong cross-skill artifact | Bắt buộc — `source` + `checksum` cho mọi `*-impact.json` |
| Đổi output path mà không sync Protocol 21 | Sync cả `_contract.json` + Protocol 21 trong 1 PR |

---

## 15. Checklist khi tạo/sửa `_contract.json`

**Trước khi merge:**

- [ ] `$schema: "skill-contract-v1"` đúng vị trí (line 1-2)
- [ ] `version` bump đúng (major nếu breaking, minor nếu thêm output mới, patch nếu fix description)
- [ ] `description` rõ what + for whom + key changes
- [ ] `prerequisites` có `forensic_validation` (không chỉ existence — CORE-011)
- [ ] Mọi `outputs.working[]` có `template` field (CORE-031), trừ APPEND/lock files
- [ ] Mọi cross-skill artifact có `schema` version
- [ ] `registry_scope.write_role` 1 trong 7 giá trị hợp lệ (CORE-006)
- [ ] `cross_skill_contracts.produces_for{}` + `consumes_from{}` khớp Protocol 21
- [ ] `errors{}` codes nằm trong namespace của skill, không trùng skill khác
- [ ] Nếu CI: có section `code_intelligence` với `protocol: "20-code-intelligence.md"`
- [ ] Đã chạy `./.claude/scripts/validate-schema-sync.sh {skill}` → PASS
- [ ] Đã update Protocol 21 nếu thêm/đổi output path mới
- [ ] Nếu bump major: viết `migration_notes` (vd: `wf-legacy-scan` v5.0)

**Update khi:**
- Skill thêm phase/lane/dimension mới → thêm output entries
- Đổi cách spawn agent → update `orchestrates[]`
- Phát hành version mới → bump `version` + viết changelog trong `description`

---

## 16. Compliance audit

Script `./.claude/scripts/validate-schema-sync.sh {skill}` kiểm tra:

- ✅ `$schema` field tồn tại + đúng giá trị `"skill-contract-v1"`
- ✅ Mọi output path khớp Protocol 21 (cross-skill paths)
- ✅ Mọi template file path trong `outputs.working[]` tồn tại thật
- ✅ `registry_scope.fields_owned[]` không conflict với skill khác
- ✅ Error codes namespace không trùng

Chạy:
```bash
./.claude/scripts/validate-schema-sync.sh wf-fix-bugs
./.claude/scripts/validate-schema-sync.sh --all   # toàn bộ
```

---

## 17. Liên kết

- **Canonical Protocol 21:** [`.claude/skills/protocols/21-cross-skill-output-path-contract.md`](../../.claude/skills/protocols/21-cross-skill-output-path-contract.md)
- **Rule liên quan:** CORE-007 (path contract), CORE-031 (template usage), CORE-036 (artifact contract)
- **Case studies thực tế:**
  - [`.claude/skills/workflow/wf-fix-bugs/_contract.json`](../../.claude/skills/workflow/wf-fix-bugs/_contract.json) — orchestrator pattern
  - [`.claude/skills/workflow/wf-legacy-scan/_contract.json`](../../.claude/skills/workflow/wf-legacy-scan/_contract.json) — entry point + many produces_for
  - [`.claude/skills/workflow/wf-manage-change/_contract.json`](../../.claude/skills/workflow/wf-manage-change/_contract.json) — UPDATE-MODE registry role
- **Bảng path tổng:** [`11-output-path-contract.md`](11-output-path-contract.md)
- **Error code registry:** [`08-error-code-registry.md`](08-error-code-registry.md)
- **Pattern + ví dụ:** [`../03-design-patterns/03-cross-skill-artifacts.md`](../03-design-patterns/03-cross-skill-artifacts.md)
