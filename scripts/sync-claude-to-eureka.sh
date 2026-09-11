#!/usr/bin/env bash
# ============================================================================
# sync-claude-to-eureka.sh
# Đồng bộ .claude/ từ MCV3 sang EUREKA-2026 (giữ nguyên .mc-data/ + settings.local.json)
#
# Usage:
#   bash scripts/sync-claude-to-eureka.sh [--dry-run] [--no-backup] [--force]
#                                          [--include-settings]
#                                          [--source=PATH] [--target=PATH]
#
# Default behavior:
#   1. Backup EUREKA-2026/.claude/ → .claude.backup.YYYYMMDD-HHMMSS/
#   2. Đồng bộ 10 thư mục con từ MCV3 → EUREKA-2026
#      (agents, commands, doc-framework, hooks, references, rules,
#       schemas, scripts, skills, templates)
#   3. PRESERVE: settings.json, settings.local.json, .mcignore (KHÔNG đụng)
#   4. Clean __pycache__ ở target sau khi sync
#
# WHY settings.json bị PRESERVE: EUREKA-2026 có hooks GitNexus + Serena
# integration mà MCV3 không có. Sync sẽ mất các hooks đó. Dùng
# --include-settings để override (sẽ overwrite — bạn tự merge lại tay).
#
# KHÔNG đụng vào: .mc-data/, .git/, CLAUDE.md, mọi file ngoài .claude/
# ============================================================================

set -euo pipefail

# ---- Config ----------------------------------------------------------------
SOURCE_DEFAULT="D:/Working/MCV3"
TARGET_DEFAULT="D:/Working/EUREKA-2026"

SOURCE="$SOURCE_DEFAULT"
TARGET="$TARGET_DEFAULT"
DRY_RUN=0
NO_BACKUP=0
FORCE=0
INCLUDE_SETTINGS=0

# Thư mục con của .claude/ sẽ được đồng bộ (mirror MCV3 → target)
SYNC_DIRS=(
    agents
    commands
    doc-framework
    hooks
    references
    rules
    schemas
    scripts
    skills
    templates
)

# File ở root .claude/ sẽ được đồng bộ (opt-in qua --include-settings)
SYNC_FILES_OPTIONAL=(
    settings.json
)

# File/dir KHÔNG được đụng vào (bảo toàn ở target)
PRESERVE=(
    settings.json        # EUREKA-2026 có GitNexus/Serena hooks riêng
    settings.local.json  # Local user permissions
    .mcignore            # Project-specific ignore
)

# ---- Parse args ------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --dry-run)           DRY_RUN=1 ;;
        --no-backup)         NO_BACKUP=1 ;;
        --force)             FORCE=1 ;;
        --include-settings)  INCLUDE_SETTINGS=1 ;;
        --source=*)          SOURCE="${arg#*=}" ;;
        --target=*)          TARGET="${arg#*=}" ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown arg: $arg" >&2
            exit 1
            ;;
    esac
done

SOURCE_CLAUDE="$SOURCE/.claude"
TARGET_CLAUDE="$TARGET/.claude"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$TARGET/.claude.backup.$TIMESTAMP"

# ---- Pre-flight checks -----------------------------------------------------
echo "============================================================"
echo "  SYNC .claude/ : MCV3 → EUREKA-2026"
echo "============================================================"
echo "Source : $SOURCE_CLAUDE"
echo "Target : $TARGET_CLAUDE"
echo "Backup : $([ "$NO_BACKUP" = "1" ] && echo '(skipped)' || echo "$BACKUP_DIR")"
echo "Mode   : $([ "$DRY_RUN" = "1" ] && echo 'DRY-RUN' || echo 'EXECUTE')"
echo ""

if [ ! -d "$SOURCE_CLAUDE" ]; then
    echo "[ERROR] Source .claude/ not found: $SOURCE_CLAUDE" >&2
    exit 1
fi
if [ ! -d "$TARGET_CLAUDE" ]; then
    echo "[ERROR] Target .claude/ not found: $TARGET_CLAUDE" >&2
    exit 1
fi
if [ ! -d "$TARGET/.mc-data" ]; then
    echo "[WARN] Target .mc-data/ not found — đảm bảo đúng project trước khi sync."
fi

# ---- Show plan -------------------------------------------------------------
echo "Sync plan:"
for d in "${SYNC_DIRS[@]}"; do
    if [ -d "$SOURCE_CLAUDE/$d" ]; then
        src_count=$(find "$SOURCE_CLAUDE/$d" -type f 2>/dev/null | wc -l)
        tgt_count=$(find "$TARGET_CLAUDE/$d" -type f 2>/dev/null | wc -l)
        echo "  [DIR ] $d/ (src=$src_count files, tgt=$tgt_count files)"
    else
        echo "  [SKIP] $d/ (not in source)"
    fi
done
if [ "$INCLUDE_SETTINGS" = "1" ]; then
    echo ""
    echo "[!] --include-settings: settings.json SẼ được overwrite từ MCV3"
    echo "    EUREKA-2026 settings.json có GitNexus/Serena hooks riêng — bạn"
    echo "    cần merge tay từ backup sau khi sync."
    for f in "${SYNC_FILES_OPTIONAL[@]}"; do
        echo "    [FILE] $f (overwrite)"
    done
fi

echo ""
echo "Preserved at target (NOT touched):"
for p in "${PRESERVE[@]}"; do
    if [ -e "$TARGET_CLAUDE/$p" ]; then
        if [ "$p" = "settings.json" ] && [ "$INCLUDE_SETTINGS" = "1" ]; then
            continue
        fi
        echo "  [KEEP] $p"
    fi
done
echo ""

# ---- Confirm ---------------------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] Không thực thi. Bỏ --dry-run để chạy thật."
    exit 0
fi

if [ "$FORCE" != "1" ]; then
    read -p "Tiếp tục sync? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Đã hủy."
        exit 0
    fi
fi

# ---- Backup ----------------------------------------------------------------
if [ "$NO_BACKUP" != "1" ]; then
    echo "[1/4] Backing up target .claude/ → $BACKUP_DIR ..."
    mkdir -p "$BACKUP_DIR"
    # Copy entire target .claude/ (giữ nguyên cấu trúc cho rollback)
    cp -a "$TARGET_CLAUDE/." "$BACKUP_DIR/"
    echo "       Backup OK ($(find "$BACKUP_DIR" -type f | wc -l) files)"
else
    echo "[1/4] Backup SKIPPED (--no-backup)"
fi

# ---- Save preserve files to temp -------------------------------------------
echo "[2/4] Lưu tạm các file preserve..."
PRESERVE_TMP="$(mktemp -d)"
for p in "${PRESERVE[@]}"; do
    if [ -e "$TARGET_CLAUDE/$p" ]; then
        cp -a "$TARGET_CLAUDE/$p" "$PRESERVE_TMP/"
        echo "       Saved: $p"
    fi
done

# ---- Sync directories ------------------------------------------------------
echo "[3/4] Syncing directories..."
for d in "${SYNC_DIRS[@]}"; do
    if [ ! -d "$SOURCE_CLAUDE/$d" ]; then
        echo "       [SKIP] $d/ (source not exist)"
        continue
    fi
    # Xóa target dir (mirror) rồi copy lại — đảm bảo file đã xóa ở source cũng xóa ở target
    if [ -d "$TARGET_CLAUDE/$d" ]; then
        rm -rf "$TARGET_CLAUDE/$d"
    fi
    cp -a "$SOURCE_CLAUDE/$d" "$TARGET_CLAUDE/$d"
    file_count=$(find "$TARGET_CLAUDE/$d" -type f | wc -l)
    echo "       [SYNC] $d/ ($file_count files)"
done

# Sync top-level files (opt-in via --include-settings)
if [ "$INCLUDE_SETTINGS" = "1" ]; then
    for f in "${SYNC_FILES_OPTIONAL[@]}"; do
        if [ -f "$SOURCE_CLAUDE/$f" ]; then
            cp -a "$SOURCE_CLAUDE/$f" "$TARGET_CLAUDE/$f"
            echo "       [SYNC] $f (overwritten — REMEMBER to merge GitNexus/Serena hooks!)"
        fi
    done
fi

# ---- Restore preserve files (chỉ khi bị overwrite) -------------------------
# Vì cp -a file ở root .claude/ chỉ ghi đè đúng file đó, các file preserve không bị động.
# Nhưng restore lại cho chắc (idempotent), TRỪ settings.json nếu user opt-in:
for p in "${PRESERVE[@]}"; do
    if [ -e "$PRESERVE_TMP/$p" ]; then
        if [ "$p" = "settings.json" ] && [ "$INCLUDE_SETTINGS" = "1" ]; then
            continue  # User opt-in to overwrite — không restore
        fi
        cp -a "$PRESERVE_TMP/$p" "$TARGET_CLAUDE/$p"
    fi
done
rm -rf "$PRESERVE_TMP"

# ---- Cleanup __pycache__ ---------------------------------------------------
echo "[4/4] Dọn __pycache__ ở target..."
find "$TARGET_CLAUDE" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
pyc_count=$(find "$TARGET_CLAUDE" -name "*.pyc" 2>/dev/null | wc -l)
echo "       Còn lại $pyc_count file .pyc"

# ---- Summary ---------------------------------------------------------------
echo ""
echo "============================================================"
echo "  SYNC HOÀN TẤT"
echo "============================================================"
echo "Target  : $TARGET_CLAUDE"
echo "Backup  : $([ "$NO_BACKUP" = "1" ] && echo '(none)' || echo "$BACKUP_DIR")"
echo ""
echo "Verify nhanh:"
echo "  diff -rq \"$SOURCE_CLAUDE/skills/workflow/wf-fix-bugs/\" \\"
echo "         \"$TARGET_CLAUDE/skills/workflow/wf-fix-bugs/\" | head -5"
echo ""
echo "Bước tiếp theo:"
echo "  1. cd \"$TARGET\""
echo "  2. Mở Claude Code session mới ở thư mục này"
echo "  3. Chạy: /wf-fix-bugs --scope=module --name=tms --profile=quick --dry-run"
echo "     (hoặc --resume nếu muốn tiếp session 2026-05-06-module-tms-01)"
echo ""
echo "Rollback (nếu cần):"
echo "  rm -rf \"$TARGET_CLAUDE\""
echo "  mv \"$BACKUP_DIR\" \"$TARGET_CLAUDE\""
