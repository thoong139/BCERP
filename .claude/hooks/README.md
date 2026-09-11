# DEVKIT Hooks System

Hệ thống hooks để tự động hóa việc đảm bảo tuân thủ quy trình DEVKIT.

## Cấu trúc

```
.claude/hooks/
├── README.md                          # File này
├── _hook-utils.sh                     # Shared utility library (không phải hook)
│
├── session-init.sh                    # SessionStart: Detect project state
├── privacy-block.sh                   # PreToolUse [Read]: Block sensitive files
├── scout-block.sh                     # PreToolUse [Glob]: Block heavy directories
├── validate-requirement-sync.sh       # PreToolUse [Write|Edit]: Kiểm tra REQ-ID
├── validate-critical-decision.sh      # PreToolUse [Write|Edit]: CDG-02 overwrite warning
├── pre-bash-safety.sh                 # PreToolUse [Bash]: Block dangerous commands
├── update-sync-status.sh              # PostToolUse [Write|Edit]: Cập nhật sync status
├── validate-contract-sync.sh          # PostToolUse [Write|Edit]: Validate contract consistency
├── validate-ui-component.sh           # PostToolUse [Write|Edit]: UI component quality checks
├── validate-naming-convention.sh      # PostToolUse [Write|Edit]: Naming convention (CORE-016/017)
└── stop-session-verify.sh             # Stop: Verify trước khi end session
```

## Hook Types

| Type | Khi nào chạy | Mục đích |
|------|-------------|---------|
| **SessionStart** | Khi session bắt đầu | Detect project state, inject context |
| **PreToolUse** | Trước khi tool thực thi | Validation, blocking dangerous actions |
| **PostToolUse** | Sau khi tool thực thi | Logging, auto-format, status updates |
| **Stop** | Khi session kết thúc | Final verification, cleanup |

## Hooks hiện có

### 1. session-init.sh (SessionStart)

**Trigger:** Mỗi khi session bắt đầu

**Chức năng:**
- Detect `.mc-data/` tồn tại
- Scan current phase (latest phase dir có docs)
- Tìm last checkpoint file
- Đọc project name từ `req-registry.json`
- Output context summary qua stderr (visible cho Claude)

**Output example:**
```
=== MCV3 Session Context ===
Project data: found (.mc-data/)
Current phase: phase3-architecture
Last checkpoint: wf-design/checkpoint.json
Project: My Project
============================
```

### 2. privacy-block.sh (PreToolUse — Read)

**Trigger:** `Read` tool

**Chức năng:**
- Block đọc sensitive files (exit 2): `.env`, `credentials*`, `secrets*`, `*.pem`, `*.key`, SSH keys
- Exempt: `.env.example`, `.env.sample`, `.env.template`
- Exempt paths: `.mc-data/**`, `.claude/**`
- Prevents accidental credential exposure trong AI context

### 3. scout-block.sh (PreToolUse — Glob)

**Trigger:** `Glob` tool

**Chức năng:**
- Block Glob patterns target heavy directories (exit 2): `node_modules/`, `__pycache__/`, `.git/`, `dist/`, `build/`, `.next/`, `vendor/`
- Configurable qua `.claude/.mcignore`
- Ngăn AI scan directories lớn, tiết kiệm tokens

### 4. validate-requirement-sync.sh (PreToolUse — Write|Edit)

**Trigger:** `Write|Edit` trên code files

**Chức năng:**
- Kiểm tra code file có reference đến REQ-ID không
- Hiển thị warning nếu không có REQ-ID (không block)
- Skip non-code files (.md, .json, .yaml, etc.)

**REQ-ID Format được hỗ trợ:**
```
REQ-001              # Simple
REQ-FIN-001          # System prefix
REQ-ERP-FIN-001      # Full prefix
REQ-FIN-NFR-001      # Non-functional requirements
REQ-CRM-INT-001      # Integration requirements
```

**Cách thêm REQ-ID vào code:**
```typescript
// REQ-ID: REQ-FIN-001
export function calculateTax(amount: number) { ... }

// TypeScript/JavaScript
/** @req-id REQ-FIN-001 */
export const API_ENDPOINT = '/api/v1/tax';

// C# Attribute
[Description("REQ-API-FIN-001")]
public class PaymentController { ... }

// Python decorator
# REQ-ID: REQ-FIN-001
def process_payment():
    pass
```

### 5. validate-critical-decision.sh (PreToolUse — Write|Edit)

**Trigger:** `Write|Edit` trên files có nội dung

**Chức năng:**
- CDG-02 overwrite detection — WARNING-only (không block, luôn exit 0)
- Phát hiện khi file đã tồn tại VÀ có nội dung (`test -s`)
- Whitelist: files trong `.mc-data/work/` được overwrite tự do
- Hook chỉ log WARNING — CDG-02 confirmation nằm trong skill logic (protocols/16-critical-decision-gate.md §16.2)
- Liên quan CORE-027 (Critical Decision Gate Protocol)

### 6. pre-bash-safety.sh (PreToolUse — Bash)

**Trigger:** `Bash` tool

**Chức năng:**
- Block các dangerous commands:
  - `rm -rf /` hoặc tương tự
  - `git push --force` lên main/master
  - `DROP DATABASE` trong SQL commands
  - Credentials/keys exposure
- Warning cho các commands cần cẩn thận

### 7. update-sync-status.sh (PostToolUse — Write|Edit)

**Trigger:** `Write|Edit` trên code files

**Chức năng:**
- Trích xuất REQ-IDs từ code vừa tạo/sửa
- Cập nhật `.mc-data/sync/sync-status.md` với change history
- Log new REQ-IDs detected

### 8. validate-contract-sync.sh (PostToolUse — Write|Edit)

**Trigger:** `Write|Edit` trên design-map.json hoặc feature files

**Chức năng:**
- Kiểm tra REQ-IDs trong phase2-features + phase3-architecture docs khớp với `req-registry.json`
- Validate modules trong design-map.json tồn tại trong registry
- Bắt lỗi AI tự chế REQ-ID hoặc Module ngoài scope
- Đọc từ `.mc-data/docs/_meta/req-registry.json` (Single Source of Truth)

### 9. validate-ui-component.sh (PostToolUse — Write|Edit)

**Trigger:** `Write|Edit` trên UI files (.tsx, .jsx, .vue, .svelte, .html, .css)

**Chức năng:**
- Kiểm tra accessibility (alt text, aria labels)
- Phát hiện hardcoded colors (nên dùng design tokens)
- Kiểm tra cursor-pointer cho interactive elements
- Skip non-UI files tự động

### 10. validate-naming-convention.sh (PostToolUse — Write|Edit)

**Trigger:** `Write|Edit` trên legacy pipeline files (classified/*, extracted/*, req-registry.json)

**Chức năng:**
- Validate module/system names theo lowercase-kebab-case convention (CORE-016, CORE-017)
- 2-tier validation: per-file (Tier 1) + full-tree (Tier 2 tại phase boundaries)
- Check classified batch files, extracted JSON, và req-registry.json
- Detect case-insensitive duplicate IDs trong registry
- Skip files ngoài legacy pipeline scope

### 11. stop-session-verify.sh (Stop)

**Trigger:** Session kết thúc

**Chức năng:**
- Kiểm tra có uncommitted changes không
- Verify REQ-ID sync status
- Reminder về pending tasks

## Shared Utility

### `_hook-utils.sh`

Shared library được source bởi các hooks. Không phải hook, không đăng ký trong settings.json.

**Cung cấp:**
- `hook_now_utc()` — ISO-8601 timestamp
- `hook_timer_start()` / `hook_timer_end()` — Performance timing
- `hook_normalize_path()` — Windows/Unix path normalization
- `hook_detect_phase_from_path()` — Detect workflow phase từ file path
- `hook_resolve_jq()` — Cross-platform jq resolution
- `hook_metrics_enabled()` — Check metrics có enabled
- `hook_log_jsonl()` — Write performance logs (JSONL)
- `hook_append_metric()` — Write structured metrics
- `hook_detect_tier_mode()` — Detect Tier 1/2 validation mode

## Cấu hình

Hooks được cấu hình trong `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/session-init.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/privacy-block.sh" }
        ]
      },
      {
        "matcher": "Glob",
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/scout-block.sh" }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/validate-requirement-sync.sh" },
          { "type": "command", "command": "./.claude/hooks/validate-critical-decision.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/pre-bash-safety.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/update-sync-status.sh" },
          { "type": "command", "command": "./.claude/hooks/validate-contract-sync.sh" },
          { "type": "command", "command": "./.claude/hooks/validate-ui-component.sh" },
          { "type": "command", "command": "./.claude/hooks/validate-naming-convention.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "./.claude/hooks/stop-session-verify.sh" }
        ]
      }
    ]
  }
}
```

## Exit Codes

| Code | Ý nghĩa | Hành động |
|------|---------|-----------|
| 0 | Success | Tiếp tục |
| 2 | Block | Dừng tool execution |
| Other | Error | Log warning, continue |

## Yêu cầu

- **jq** — JSON processor (cần cho parsing tool input)
  - macOS: `brew install jq`
  - Windows: `choco install jq` hoặc dùng Git Bash
- **Git Bash** hoặc **WSL** (Windows users)

## Troubleshooting

### Hooks không chạy

1. Check file permissions: `chmod +x .claude/hooks/*.sh`
2. Check path trong `settings.json` (dùng forward slashes)
3. Verify `jq` installed: `jq --version`

### False positives trong REQ-ID detection

- Hook sử dụng regex matching, có thể match nhầm
- Solution: Thêm comment `// REQ-ID: REQ-XXX-NNN` rõ ràng

### Windows compatibility

- Scripts require bash environment
- Use Git Bash hoặc WSL
- Alternative: Convert sang PowerShell scripts

## Best Practices

1. **Luôn thêm REQ-ID** khi viết code mới
2. **Check sync status** trước khi commit: `/wf-verify-sync`
3. **Review warnings** từ hooks — không ignore
4. **Keep hooks updated** khi thay đổi workflow

## Adding New Hooks

1. Tạo script file trong `.claude/hooks/`
2. Source `_hook-utils.sh` nếu cần shared utilities
3. Add vào `settings.json` dưới đúng hook type + matcher
4. Test thoroughly trước khi dùng production
5. Update README.md này
