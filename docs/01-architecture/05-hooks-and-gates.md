# 05 — Hooks & Gates

> **Mức độ ràng buộc:** Tham khảo (overview)
> **Mục đích:** Mô tả 12 hooks tự động + 3 loại gates (PRE-GATE, POST-GATE, CDG) — gác cổng tự động bảo vệ chất lượng output

---

## 1. Tổng quan 2 cơ chế

MCV3 dùng 2 cơ chế khác nhau để đảm bảo chất lượng:

| Cơ chế | Định nghĩa | Ai chạy |
|--------|-----------|---------|
| **Hooks** | Shell scripts auto-trigger khi Claude Code phát event | Harness (`PreToolUse`, `PostToolUse`, `Stop`, ...) |
| **Gates** | Validation checkpoint trong skill phase | Skill (PRE-GATE / POST-GATE) hoặc User (CDG) |

**Khác biệt:**
- Hook = **lightweight spot-check** mỗi tool call (vd: kebab-case, REQ-ID present)
- Gate = **heavyweight validation** mỗi phase transition (vd: T1→T4 đầy đủ)

```
┌──────────────────────────────────────────────────┐
│  USER gõ /wf-xxx                                  │
└────────────┬─────────────────────────────────────┘
             ▼
   [SessionStart hook] ────→ session-init.sh
             ▼
   Skill load + PRE-GATE ────→ Skill self-check (forensic content, không chỉ exists)
             ▼
   Phase execution:
   ├─ Tool call (Read/Write/Edit/Bash)
   │   ├─ [PreToolUse hook] ──→ privacy-block, scout-block, validate-requirement-sync, ...
   │   ├─ Tool runs
   │   └─ [PostToolUse hook] ──→ update-sync-status, validate-contract-sync, ...
   │
   └─ CDG point (Critical Decision Gate)
       └─ AskUserQuestion → user confirm/reject
             ▼
   POST-GATE T1→T4 ────────→ Skill self-validate output
             ▼
   [Stop hook] ────────────→ stop-session-verify.sh
             ▼
   Return to user
```

---

## 2. Hooks (12 hooks)

### 2.1. SessionStart (1 hook)

| Hook | Mục đích | Behavior |
|------|----------|----------|
| `session-init.sh` | Detect project state, inject context | Scan `.mc-data/`, find latest phase, last checkpoint, project name — output context tóm tắt qua stderr (Claude visible) |

Output mẫu:
```
=== MCV3 Session Context ===
Project data: found (.mc-data/)
Current phase: phase3-architecture
Last checkpoint: wf-design/checkpoint.json
Project: My Project
============================
```

### 2.2. PreToolUse (6 hooks)

| Hook | Tool trigger | Mục đích |
|------|-------------|----------|
| `privacy-block.sh` | Read | Chặn (exit 2) đọc `.env`, `credentials*`, `secrets*`, `*.pem`, `*.key`, SSH keys |
| `scout-block.sh` | Glob | Chặn Glob target heavy directories (`node_modules/`, `__pycache__/`, `.git/`, `dist/`, `build/`, `vendor/`) |
| `pre-bash-safety.sh` | Bash | Chặn lệnh nguy hiểm (`rm -rf /`, `chmod 777 /`, `dd of=/dev/sd*`, ...) |
| `validate-requirement-sync.sh` | Write/Edit | Warning nếu code file thiếu REQ-ID comment |
| `validate-critical-decision.sh` | Write/Edit | Warning cho CDG-02 overwrite (registry critical fields) |

**Quy tắc:** Hook chỉ **block** trên action thật nguy hiểm. Còn lại → **WARN**, không block.

Exit codes:
- `0` → pass, tool tiếp tục
- `2` → BLOCK, tool không chạy, lỗi rõ ràng cho Claude
- Other → continue with stderr message

### 2.3. PostToolUse (4 hooks)

| Hook | Tool trigger | Mục đích |
|------|-------------|----------|
| `update-sync-status.sh` | Write/Edit | Update `.mc-data/sync/` tracking |
| `validate-contract-sync.sh` | Write/Edit | Validate với `req-registry.json` (REQ-ID exist không, FEAT-ID có trong registry không) |
| `validate-ui-component.sh` | Write/Edit | UI component quality checks (accessibility, i18n keys) |
| `validate-naming-convention.sh` | Write/Edit | kebab-case enforcement (CORE-016, CORE-017) |

### 2.4. Stop (1 hook)

| Hook | Mục đích |
|------|----------|
| `stop-session-verify.sh` | Final verification trước khi session end. Warning nếu registry mismatch hoặc có pending action. |

---

## 3. Hooks lifecycle

```
┌─────────────────────────────────────────────┐
│  Session Start                                │
│  └─ session-init.sh                          │
└─────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  Loop: User → Claude → Tool calls            │
│  ├─ Each Read:                               │
│  │   └─ PreToolUse: privacy-block.sh         │
│  │                                            │
│  ├─ Each Glob:                               │
│  │   └─ PreToolUse: scout-block.sh           │
│  │                                            │
│  ├─ Each Bash:                               │
│  │   └─ PreToolUse: pre-bash-safety.sh       │
│  │                                            │
│  └─ Each Write/Edit:                         │
│      ├─ PreToolUse:                          │
│      │   ├─ validate-requirement-sync.sh     │
│      │   └─ validate-critical-decision.sh    │
│      ├─ Tool runs                            │
│      └─ PostToolUse:                         │
│          ├─ update-sync-status.sh            │
│          ├─ validate-contract-sync.sh        │
│          ├─ validate-ui-component.sh         │
│          └─ validate-naming-convention.sh    │
└─────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  Session End (Stop)                          │
│  └─ stop-session-verify.sh                   │
└─────────────────────────────────────────────┘
```

---

## 4. Gates — 3 loại trong Skills

### 4.1. PRE-GATE (Forensic Entry Validation)

**Khi:** Đầu mỗi phase trong skill
**Ai chạy:** Skill (procedures/phase{N}-*.md)
**Mục đích:** Verify dữ liệu đầu vào ĐỦ ĐIỀU KIỆN để skill tiếp tục

**Quy tắc cứng (CORE-011):** Forensic check **content**, không chỉ exists.

```bash
# ❌ Không đủ:
test -f .mc-data/docs/_meta/req-registry.json

# ✅ Đúng (forensic):
test -f .mc-data/docs/_meta/req-registry.json \
  && jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json \
  && jq -e '.features | length > 0' .mc-data/docs/_meta/req-registry.json
```

**4 tiers** (cùng namespace với POST-GATE):

| Tier | Check |
|------|-------|
| T1 | File exists |
| T2 | Structure valid (JSON parse, schema) |
| T3 | Content depth (length > 0, có required fields) |
| T4 | Cross-reference với upstream (vd: REQ-ID có trong registry) |

**Fail action:** Block phase, output error code (E020-E029 cho Phase 2), suggest fix.

### 4.2. POST-GATE (Tiered Output Validation)

**Khi:** Cuối mỗi phase, sau khi sản xuất output
**Ai chạy:** Skill (procedures/phase{N}-*.md)
**Mục đích:** Verify output đạt chuẩn trước khi advance phase

**4 tiers (CORE-012):**

| Tier | Check | Auto-fix attempt |
|------|-------|------------------|
| T1 | `test -f output.json` | Re-run step tạo file |
| T2 | `jq '.' output.json` (structure) | Re-read template + populate lại |
| T3 | `jq '.data | length > 0'` (content non-empty) | Re-generate với more context |
| T4 | Cross-ref upstream (vd: feature_id trong file phải match registry) | Re-read source + re-write target |

**Auto-fix budget:** Max 3 retries / phase (CORE-034). Hết → ESCALATE qua AskUserQuestion.

```
T1 FAIL → AUTO-FIX 1 (re-run step) → check
   ↓ still fail
T1 FAIL → AUTO-FIX 2 (re-read template) → check
   ↓ still fail
T1 FAIL → AUTO-FIX 3 (clean + retry) → check
   ↓ still fail
ESCALATE: AskUserQuestion "Re-run phase / Skip (risky) / Cancel"
```

### 4.3. CDG — Critical Decision Gate

**Khi:** Tại 13 điểm quyết định quan trọng trong workflow
**Ai chạy:** Skill triggers, USER quyết định
**Mục đích:** Đảm bảo USER ý thức + đồng ý các quyết định critical

13 CDG points hiện tại:

| CDG | Skill | Điểm |
|-----|-------|------|
| CDG-01 | wf-brainstorm | Chốt scope dự án |
| CDG-02 | wf-analyze-requirements | Chốt departments + domain experts |
| CDG-03 | wf-define-features | Chốt MVP feature list |
| CDG-04 | wf-design | Chốt architecture style |
| CDG-05 | wf-design-ux | Chốt design system |
| CDG-06 | wf-plan-modules | Chốt sprint plan |
| CDG-07 | wf-implement-feature | Pre-implementation safety (overwrite existing code) |
| CDG-08 | wf-fix-bugs | Triage signature confirmation |
| CDG-09 | wf-fix-bugs | High-risk fix authorization |
| CDG-10 | wf-fix-bugs | Auto-fix budget exhausted — continue / skip / cancel |
| CDG-11 | wf-fix-business-completeness | Enhancement suggestions (ACCEPT/REJECT) |
| CDG-12 | wf-manage-change | Confirm scope of change impact |
| CDG-13 | wf-add-scope | Confirm append-only operation |

**CDG flow:**
```
Skill phase reach CDG point
   ↓
Skill prepares question + options + rationale
   ↓
AskUserQuestion tool → user UI shows decision
   ↓
User selects option (or types custom response)
   ↓
Skill logs decision vào decision-registry.global.json
   ↓
Continue per user response
```

**KHÔNG bypass CDG** trừ khi user explicitly trao quyền (vd: `--auto` flag).

Chi tiết: [`../03-design-patterns/10-cdg-gate.md`](../03-design-patterns/10-cdg-gate.md).

---

## 5. Hook vs Gate — phân định trách nhiệm

| Aspect | Hook | Gate |
|--------|------|------|
| Chạy lúc nào | Mỗi tool call | Mỗi phase transition |
| Ai chạy | Claude Code harness | Skill self-check / User |
| Phạm vi | 1 file / 1 action | Toàn bộ phase output |
| Chi phí | Light (ms) | Heavy (seconds) |
| Block flow? | Có (exit 2) hoặc warn | Có (E0xx) hoặc escalate |
| Có thể bypass? | Không (harness enforce) | Skill-level: T4 → escalate; CDG → user choice |

**Ranh giới:**
- Hook check **invariant** (kebab-case đúng, không có secrets) — luôn đúng/sai
- Gate check **business contract** (T1→T4) — có thể auto-fix
- CDG check **judgment call** — phải user

---

## 6. Configuration (`.claude/settings.json`)

Hooks được đăng ký trong settings:

```json
{
  "hooks": {
    "SessionStart": ["session-init.sh"],
    "PreToolUse": {
      "Read": ["privacy-block.sh"],
      "Glob": ["scout-block.sh"],
      "Bash": ["pre-bash-safety.sh"],
      "Write|Edit": [
        "validate-requirement-sync.sh",
        "validate-critical-decision.sh"
      ]
    },
    "PostToolUse": {
      "Write|Edit": [
        "update-sync-status.sh",
        "validate-contract-sync.sh",
        "validate-ui-component.sh",
        "validate-naming-convention.sh"
      ]
    },
    "Stop": ["stop-session-verify.sh"]
  }
}
```

---

## 7. Thêm Hook mới

1. Tạo `.claude/hooks/{name}.sh` (bash script)
2. Theo template `_hook-utils.sh` cho shared utilities (logging, helper functions)
3. Đảm bảo idempotent — chạy lại nhiều lần kết quả không đổi
4. Exit codes rõ ràng: `0` (pass), `2` (block), other (warn)
5. Output `stderr` để Claude thấy
6. Đăng ký trong `.claude/settings.json`
7. Test: simulate event → verify behavior
8. Update `.claude/hooks/README.md` + bảng tại §2 file này

**Ví dụ skeleton:**

```bash
#!/usr/bin/env bash
# Hook: PostToolUse validate-something.sh
source "$(dirname "$0")/_hook-utils.sh"

# Read tool input from stdin (JSON)
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE_PATH" ] && exit 0

# Light spot-check
if echo "$FILE_PATH" | grep -q "[A-Z]"; then
  log_warn "Filename has uppercase: $FILE_PATH (CORE-016)"
  exit 0  # warn, không block
fi

exit 0
```

---

## 8. Anti-patterns

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Hook chạy logic heavy (full registry validation 5s) | Hook chỉ spot-check — full check trong POST-GATE |
| Hook block mỗi warning | Block CHỈ với action nguy hiểm thật sự |
| Hook output to stdout (Claude không thấy) | Output stderr |
| Skill POST-GATE chỉ check T1 (file exists) | PHẢI đủ T1→T4 |
| CDG question viết bằng English | Tiếng Việt cho user-facing |
| CDG question không có "lý do" | Phải explain rationale để user quyết định informed |
| Skill bypass CDG khi user không có flag `--auto` | KHÔNG được — CDG bắt buộc |
| Hook modify file (vd: auto-format) trong PreToolUse | PostToolUse mới được modify |
| 2 hooks cùng listen 1 event không có ordering | Định nghĩa rõ order trong settings.json |
| Hook script không exit code rõ ràng | Luôn explicit `exit 0/2/...` |

---

## 9. Debug Hooks

```bash
# Manually trigger hook để test:
echo '{"tool_input":{"file_path":"test.ts"}}' | bash .claude/hooks/validate-requirement-sync.sh

# Disable hook tạm thời (rename):
mv .claude/hooks/privacy-block.sh .claude/hooks/privacy-block.sh.disabled

# Check hook execution log (nếu enabled):
ls -la .mc-data/work/_trace/hook-log.json
```

**Env var:**
- `MCV3_HOOK_METRICS_ENABLED=1` — bật metrics cho hooks

---

## 10. Liên kết

- **Hook source:** [`.claude/hooks/`](../../.claude/hooks/)
- **Hook utilities:** [`.claude/hooks/_hook-utils.sh`](../../.claude/hooks/_hook-utils.sh)
- **Hook README:** [`.claude/hooks/README.md`](../../.claude/hooks/README.md)
- **Quality Gates standard:** [`../02-standards/05-quality-gates.md`](../02-standards/05-quality-gates.md) — chi tiết T1→T4
- **CDG pattern:** [`../03-design-patterns/10-cdg-gate.md`](../03-design-patterns/10-cdg-gate.md)
- **Protocol 10 (POST-GATE):** [`.claude/skills/protocols/10-post-gate-schema.md`](../../.claude/skills/protocols/10-post-gate-schema.md)
- **Protocol 16 (CDG):** [`.claude/skills/protocols/16-critical-decision-gate.md`](../../.claude/skills/protocols/16-critical-decision-gate.md)
- **CORE rules:** CORE-011, CORE-012, CORE-027 trong [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md)
