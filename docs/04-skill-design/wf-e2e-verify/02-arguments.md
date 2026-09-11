# 02 — Arguments

> **Mục đích file:** 14 arguments của orchestrator + legacy flag backward-compat (8 legacy flags silent accept + WARN deprecation).

---

## 1. Bảng arguments (new flags v7.0.0+)

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `<FEAT-ID>` | string (positional) | — | Có (trừ `--session=` hoặc `--resume`) | Feature ID cần E2E verify |
| `--from-step=<F0-F8>` | enum | F0 | Không | Jump-to step (validate prereq trước khi run) |
| `--phase=<0-7>` (legacy) | int | auto-detect | Không | Legacy alias map sang `--from-step` |
| `--resume` | flag | — | Không | Resume session gần nhất |
| `--session=<id>` | string | auto-discover | Không | Session ID cụ thể |
| `--status` | flag | — | Không | Display orchestrator dashboard + STOP |
| `--auto` | flag | disabled | Không | Auto-confirm tất cả prompts (pass tới F0a+F1+F4+F6) |
| `--skip=<F2,F3,...>` | CSV enum | none | Không | Opt-out sub-skills (F0/F0a KHÔNG thể skip) |
| `--no-playwright` | flag | disabled (deprecated v7.1.0) | Không | DEGRADE mode trước; v7.1.0+ ignored với WARN |
| `--show-browser` | flag | headless | Không | Hiển thị browser (pass tới F2/F7/F8) |
| `--mobile` | flag | desktop | Không | Mobile viewport (pass tới F2/F7/F8) |
| `--strict-evidence` | flag | **ON** (default) | Không | Bắt buộc screenshot mọi step F2/F7/F8 |
| `--no-seed` | flag | disabled | Không | Skip F0b seed-manifest |
| `--max-impl-items=<N>` | int | unlimited | Không | Limit F4 implement (priority P0 first) |

---

## 2. Legacy flags (backward-compat — silent accept + WARN)

| Legacy flag | Behavior mới | Track |
|-------------|--------------|------|
| `--parallel-safe` | no-op (luôn ON) | `legacy_flags_used[]` WARN "deprecated, always enabled" |
| `--cross-module` | no-op (luôn ON) | WARN "deprecated, always enabled" |
| `--cross-module-wait=<N>` | pass-through tới F5+F7 | accept silent |
| `--playwright-mcp` | no-op (default Playwright cho F2/F5/F7/F8) | WARN "deprecated" |
| `--phase=0..6` | alias `--from-step=F1` (start at F1) | WARN |
| `--phase=7` | alias `--from-step=F7` (F7+F8 only) | WARN |
| `--fix=<path>` | jump to F6 với `--path=<path>` | accept, run F6 standalone |
| `--retest` | jump to F5 standalone | accept |
| `--unblock-test` | jump to F3 standalone | accept |
| `--no-playwright` (v7.1.0+) | **DEPRECATED** — ignored với WARN. Live browser BẮT BUỘC F2/F5/F7/F8. CI không có browser → dùng explicit `--skip=F2,F5,F7,F8` | WARN, ignore |

Tracked trong `e2e-status.json.legacy_flags_used[]` — array các string warnings.

---

## 3. Argument interactions

| Combo | Behavior |
|-------|----------|
| `<FEAT-ID>` + `--resume` | `--resume` ưu tiên → tìm session gần nhất matching FEAT-ID |
| `--session=<id>` + `--resume` | Resume từ session cụ thể (`<id>`) |
| `--status` + bất kỳ flag khác | Status mode ưu tiên, không thực thi |
| `--from-step=F6` + thiếu `--session=` | E007 — F6 standalone cần session đã tồn tại |
| `--skip=F0` hoặc `--skip=F0a` | ERROR — F0/F0a KHÔNG thể skip |
| `--auto` + interactive sub-skill | Pass `--auto` xuống sub-skill spawn |
| `--no-playwright` + v7.1.0+ | WARN deprecation, ignore flag, pipeline vẫn chạy live |
| `--fix=<path>` (legacy) | Force `--from-step=F6` standalone, skip F1-F5 + F7-F8 |
| `--retest` (legacy) | Force `--from-step=F5` standalone |
| `--unblock-test` (legacy) | Force `--from-step=F3` standalone |
| `--phase=7` (legacy) | `--from-step=F7` → chỉ F7+F8 |

---

## 4. `--from-step` matrix

| `--from-step=<X>` | Phases chạy | Phases skipped (mark `skip_reason='--from-step=X'`) |
|-------------------|------------|---------------------------------------------------|
| F0 (default) | F0 → F0a → F0b? → F1 → F2 → F3? → F4? → F5 → F6? → F7 → F8 | none |
| F1 | F1 → F2 → ... → F8 | F0, F0a, F0b |
| F3 (standalone) | F3 only | F0-F2, F4-F8 |
| F4 (standalone) | F4 only | F0-F3, F5-F8 |
| F5 | F5 → F6? → F7 → F8 | F0-F4 |
| F6 (standalone) | F6 only | F0-F5, F7-F8 |
| F7 | F7 → F8 | F0-F6 |

**`--from-step` validate prereq:** Nếu jump tới F5 mà F1-F4 outputs chưa có → E007 (suggest --resume hoặc fresh run).

---

## 5. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| `<FEAT-ID>` | Match `^FEAT-[A-Z]+-[0-9]+$` AND tồn tại trong `req-registry.json` | E001 |
| Feature spec | `test -f <spec_path> && size >= 500 bytes` | E002 |
| 11 sub-skill dirs | `test -d .claude/skills/workflow/wf-e2e-{infra-check,finding,seed-manifest,test,browser,unblock,implement,retest,fix,scenario,demo}` | E003 |
| `--from-step` | In set `{F0, F0a, F0b, F1, F2, F3, F4, F5, F6, F7, F8}` | E006 |
| `--skip` | KHÔNG chứa `F0` hoặc `F0a` | E006 |
| `--session=<id>` | Match `^FEAT-[A-Z]+-[0-9]+-[0-9]{8}-[0-9]{4}$` | E007 |
| Lock | `.lock` không stale (age <30 min) hoặc auto-release | E008 |

---

## 6. Examples

```bash
# Full pipeline (default)
/wf-e2e-verify FEAT-EW-CRM-001

# Resume session đang dở
/wf-e2e-verify FEAT-EW-CRM-001 --resume

# Auto-confirm mọi prompts
/wf-e2e-verify FEAT-EW-CRM-001 --auto

# Skip browser + UI tests (CI không có browser)
/wf-e2e-verify FEAT-EW-CRM-001 --skip=F2,F5,F7,F8

# Standalone F6 fix from path
/wf-e2e-verify FEAT-EW-CRM-001 --fix=path/to/issues.json --session=FEAT-EW-CRM-001-20260513-1200

# Status dashboard
/wf-e2e-verify FEAT-EW-CRM-001 --status

# Mobile viewport
/wf-e2e-verify FEAT-EW-CRM-001 --mobile --show-browser

# Legacy 3-flag user
/wf-e2e-verify FEAT-EW-CRM-001 --playwright-mcp --cross-module --parallel-safe
# → WARN 3 deprecations, run default chain

# Phase 7 only (legacy)
/wf-e2e-verify FEAT-EW-CRM-001 --phase=7
# → --from-step=F7

# Skip F0b seed
/wf-e2e-verify FEAT-EW-CRM-001 --no-seed
```

---

## 7. Liên kết

- Legacy flag handler: [`procedures/legacy-flags.md`](../../../.claude/skills/workflow/wf-e2e-verify/procedures/legacy-flags.md)
- Skip rules: [`procedures/skip-rules.md`](../../../.claude/skills/workflow/wf-e2e-verify/procedures/skip-rules.md)
- Error codes: [05-error-codes.md](05-error-codes.md)
- Resume flow: [`procedures/resume-status.md`](../../../.claude/skills/workflow/wf-e2e-verify/procedures/resume-status.md)
