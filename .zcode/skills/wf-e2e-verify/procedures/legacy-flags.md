# wf-e2e-verify Orchestrator — Legacy Flag Mapping

## Goal

Backward-compat hoàn toàn với người dùng wf-e2e-verify v6.5.0 cũ. Tất cả legacy flags vẫn work, nhưng map sang behavior mới + display WARN deprecation.

---

## Legacy Flag Detection + Mapping

```bash
map_legacy_flags() {
  LEGACY_WARNS=()
  
  # --parallel-safe → no-op (luôn ON)
  if [ "${PARALLEL_SAFE:-false}" = "true" ]; then
    LEGACY_WARNS+=("--parallel-safe deprecated, always enabled in v7.0.0+")
  fi
  
  # --cross-module → no-op (luôn ON)
  if [ "${CROSS_MODULE:-false}" = "true" ]; then
    LEGACY_WARNS+=("--cross-module deprecated, always enabled in v7.0.0+")
  fi
  
  # --cross-module-wait → still accepted (pass to F5, F7)
  if [ -n "${CROSS_MODULE_WAIT:-}" ]; then
    LEGACY_WARNS+=("--cross-module-wait deprecated, sẽ pass to F5/F7 sub-skills internally")
    # Set env var để pass down
    export CROSS_MODULE_WAIT
  fi
  
  # --playwright-mcp → no-op (default ON, mandatory v7.1.0+)
  if [ "${PLAYWRIGHT_MCP:-false}" = "true" ]; then
    LEGACY_WARNS+=("--playwright-mcp deprecated, F2/F5/F7/F8 mặc định BẮT BUỘC dùng Playwright. Auto-start mandatory.")
  fi

  # --no-playwright → deprecated v7.1.0, IGNORED. Live browser BẮT BUỘC.
  if [ "${NO_PLAYWRIGHT:-false}" = "true" ]; then
    LEGACY_WARNS+=("--no-playwright DEPRECATED v7.1.0, IGNORED. Live browser BẮT BUỘC; auto-start mandatory; ESCALATE Nhóm 2 nếu hạ tầng fail. Dùng --skip=F2,F5,F7,F8 nếu thật sự cần bỏ qua UI test (chịu trách nhiệm).")
    unset NO_PLAYWRIGHT  # clear để downstream không pick up
  fi
  
  # --phase=0..6 → alias --from-step=F1
  if [[ "${PHASE:-}" =~ ^[0-6]$ ]]; then
    LEGACY_WARNS+=("--phase=${PHASE} deprecated, mapped to --from-step=F1 (P1-6 logic now in F1 wf-e2e-test)")
    FROM_STEP="F1"
    # If user wants specific phase trong F1, pass --phase to F1
    F1_PHASE_FLAG="--phase=${PHASE}"
  fi
  
  # --phase=7 → alias --from-step=F7 (run F7 + F8)
  if [ "${PHASE:-}" = "7" ]; then
    LEGACY_WARNS+=("--phase=7 deprecated, mapped to --from-step=F7 (Playwright scenario+demo)")
    FROM_STEP="F7"
  fi
  
  # --fix=<path> → jump to F6 standalone với --path
  if [ -n "${FIX_PATH:-}" ]; then
    LEGACY_WARNS+=("--fix=<path> deprecated, mapped to standalone F6 wf-e2e-fix với --path")
    STANDALONE="F6"
    FROM_STEP="F6"
    F6_PATH_FLAG="--path=${FIX_PATH}"
  fi
  
  # --retest → standalone F5
  if [ "${RETEST:-false}" = "true" ]; then
    LEGACY_WARNS+=("--retest deprecated, mapped to standalone F5 wf-e2e-retest")
    STANDALONE="F5"
    FROM_STEP="F5"
  fi
  
  # --unblock-test → standalone F3
  if [ "${UNBLOCK_TEST:-false}" = "true" ]; then
    LEGACY_WARNS+=("--unblock-test deprecated, mapped to standalone F3 wf-e2e-unblock")
    STANDALONE="F3"
    FROM_STEP="F3"
  fi
  
  # --max-impl-items → DEPRECATED since v8.0.0, dùng --max-time thay thế
  if [ -n "${MAX_IMPL_ITEMS:-}" ]; then
    LEGACY_WARNS+=("--max-impl-items=${MAX_IMPL_ITEMS} deprecated kể từ v8.0.0. Dùng --max-time=<duration> thay thế (ví dụ: --max-time=60m). Argument bị bỏ qua.")
    # Ignore MAX_IMPL_ITEMS, không pass xuống F4
    unset MAX_IMPL_ITEMS
  fi
  
  # --auto → pass through F1+F4+F6
  if [ "${AUTO:-false}" = "true" ]; then
    # Not deprecated, still useful, no warn
    export AUTO=true
  fi
  
  # Display warnings
  if [ ${#LEGACY_WARNS[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  DEPRECATION WARNINGS:"
    for WARN in "${LEGACY_WARNS[@]}"; do
      echo "  - $WARN"
    done
    echo ""
    echo "Migration guide: xem .claude/skills/workflow/wf-e2e-verify/SKILL.md §Backward Compatibility"
    echo ""
    
    # Log to ledger
    for WARN in "${LEGACY_WARNS[@]}"; do
      log_event "LEGACY_FLAG" "init" "$WARN"
    done
    
    # Track in e2e-status.json
    jq --argjson w "$(printf '%s\n' "${LEGACY_WARNS[@]}" | jq -R . | jq -s .)" '
      .legacy_flags_used = $w
    ' "$E2E_STATUS" > "$E2E_STATUS.tmp"
    mv "$E2E_STATUS.tmp" "$E2E_STATUS"
  fi
}
```

---

## Conflict Detection

Một số legacy combinations conflict:

```bash
detect_conflicts() {
  # --fix + --retest đồng thời → ambiguous
  if [ -n "${FIX_PATH:-}" ] && [ "${RETEST:-false}" = "true" ]; then
    log_error "E006" "init" "Cannot use --fix and --retest together"
    echo "ERROR E006: --fix và --retest không kết hợp được. Chọn 1 trong 2."
    exit 1
  fi
  
  # --unblock-test + --retest → ambiguous
  if [ "${UNBLOCK_TEST:-false}" = "true" ] && [ "${RETEST:-false}" = "true" ]; then
    log_error "E006" "init" "Cannot use --unblock-test and --retest together"
    exit 1
  fi
  
  # --phase=7 + --no-playwright → v7.1.0+: --no-playwright ignored, --phase=7 vẫn chạy F7/F8 live
  if [ "${PHASE:-}" = "7" ] && [ "${NO_PLAYWRIGHT:-false}" = "true" ]; then
    echo "INFO: --no-playwright deprecated, ignored. --phase=7 vẫn chạy F7+F8 live (auto-start mandatory)."
  fi
}
```

---

## Examples

### Example 1: Legacy full pipeline

```bash
$ /wf-e2e-verify FEAT-EW-CRM-001 --playwright-mcp --cross-module --parallel-safe

⚠️  DEPRECATION WARNINGS:
  - --parallel-safe deprecated, always enabled in v7.0.0+
  - --cross-module deprecated, always enabled in v7.0.0+
  - --playwright-mcp deprecated, F2/F5/F7/F8 mặc định BẮT BUỘC dùng Playwright. Auto-start mandatory.

Migration guide: xem .claude/skills/workflow/wf-e2e-verify/SKILL.md §Backward Compatibility

→ Continue with default F1→F8 chain
```

### Example 2: Legacy --fix standalone

```bash
$ /wf-e2e-verify FEAT-EW-CRM-001 --fix=path/to/issues.json --session=FEAT-EW-CRM-001-20260513-1200

⚠️  DEPRECATION WARNINGS:
  - --fix=<path> deprecated, mapped to standalone F6 wf-e2e-fix với --path

→ Jump to F6 wf-e2e-fix với --path=path/to/issues.json --session=FEAT-EW-CRM-001-20260513-1200
→ Other steps (F1-F5, F7-F8) SKIPPED
```

### Example 3: Legacy --phase=7

```bash
$ /wf-e2e-verify FEAT-EW-CRM-001 --phase=7 --session=FEAT-EW-CRM-001-20260513-1200

⚠️  DEPRECATION WARNINGS:
  - --phase=7 deprecated, mapped to --from-step=F7 (Playwright scenario+demo)

→ Skip F1-F6, jump to F7 wf-e2e-scenario then F8 wf-e2e-demo
→ Requires F1 outputs already exist in session (test-scenario.md + user-guide.md)
```

### Example 4: Mixed legacy + new flags

```bash
$ /wf-e2e-verify FEAT-EW-CRM-001 --auto --playwright-mcp --skip=F4

⚠️  DEPRECATION WARNINGS:
  - --playwright-mcp deprecated, F2/F5/F7/F8 mặc định dùng Playwright.

→ Default F1→F8 chain với --auto pass to F1+F6, skip F4 per user request
```

---

## Migration Path (for users)

Display sau khi run legacy command:

```
================================================================
🔄 MIGRATION GUIDE — wf-e2e-verify v6.5.0 → v7.0.0
================================================================

OLD (v6.5.0):
  /wf-e2e-verify FEAT-XXX --playwright-mcp --cross-module --parallel-safe --auto

NEW (v7.0.0):
  /wf-e2e-verify FEAT-XXX --auto
  (Playwright + cross-module + parallel-safe đều default ON)

OLD: --fix=<path>
NEW: /wf-e2e-fix FEAT-XXX --session=<id> --path=<path>
     OR: /wf-e2e-verify FEAT-XXX --fix=<path> (vẫn work)

OLD: --retest --session=<id>
NEW: /wf-e2e-retest FEAT-XXX --session=<id>
     OR: /wf-e2e-verify FEAT-XXX --retest --session=<id> (vẫn work)

OLD: --unblock-test --session=<id>
NEW: /wf-e2e-unblock FEAT-XXX --session=<id>
     OR: /wf-e2e-verify FEAT-XXX --unblock-test --session=<id> (vẫn work)

OLD: --phase=<0-6>
NEW: --from-step=F1 (resume in F1)

OLD: --phase=7
NEW: --from-step=F7

OLD: --max-impl-items=10
NEW: --max-time=60m  (F4 tự quản lý priority P0/P1/P2 theo time budget)
================================================================
```
