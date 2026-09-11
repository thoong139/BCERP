# Wave 3 Detail — Polish (G6 + G5 + G4)

> **Wave**: 3 — Polish (cuối cùng trước v11.1.0)
> **Order**: G6 → G5 → G4 (đơn giản → phức tạp, isolated → coupled)
> **ETA tổng**: 7-11h (G6: 1-2h, G5: 2-3h, G4: 4-6h)
> **Target version**: v11.0.2 → v11.1.0
> **Backward-compat**: 100% — tất cả changes additive, không phá session v10.x/v11.0.x cũ
> **Prerequisite**: Wave 1+2 done (v11.0.2 production-ready, đã test 5 regression scenarios)

## Nguyên tắc thiết kế

1. **Surgical changes (BHV-003)** — chỉ touch files cần thiết, không "improve" xung quanh
2. **Defensive default** — nếu env/flag không set, behavior cũ giữ nguyên
3. **Schema mới** đều có `$schema` field cho consumer detect version
4. **One file = one writer** (CORE-006) — không 2 component cùng ghi
5. **Test trước commit** — mỗi G phải có smoke test pass

---

## G6 — Windows Path Sanitize (1-2h)

### Mục tiêu

Khử byte rác `\357\200\215` (U+F00D PUA) lọt vào output của `safety-check.json`, `verify-execute-outputs` git diff dumps trên Windows Git Bash.

### Evidence (từ root-causes.md R7)

```
safety-check.json chứa:
"phase4-find-bugs/lanes/QD1-functional\357\200\215/lane-status.json"

xxd của tên dir thực: 5144 312d 6675 6e63 7469 6f6e 616c 0a  (clean "QD1-functional\n")
```

Bytes `\357\200\215` = `0xEF 0x80 0x8D` = U+F00D (Private Use Area, "wrench" trong Nerd Fonts). Nguồn: Git on Windows output có thể inject PUA char khi terminal có Nerd Fonts hoặc khi git config core.quotepath=true encode UTF-8 paths.

### Fix points (4 vị trí)

| # | File | Line | Pattern hiện tại | Fix |
|---|------|------|------------------|------|
| 1 | `.claude/scripts/wf-fix-bugs/safety-check.sh` | 103 | `git diff --name-only \| wc -l` | Post-process `tr -d '\357\200\215\r'` |
| 2 | `.claude/scripts/wf-fix-bugs/safety-check.sh` | 106 | `git diff --name-only \| head -10 \| tr '\n' ','` | Same |
| 3 | `.claude/scripts/wf-fix-bugs/verify-execute-outputs.sh` | 199 | `git diff --name-only > $GIT_DIFF_FILES` | Same |
| 4 | `.claude/scripts/wf-fix-bugs/verify-execute-outputs.sh` | 200 | `git diff --stat > $GIT_DIFF_STAT` | Same |

### Strategy: helper function (DRY)

Tạo helper trong cả 2 scripts (hoặc shared `_git-utils.sh`):

```bash
# Strip PUA wrench (U+F00D = 0xEF 0x80 0x8D) + CR injected by Git on Windows
git_sanitize() {
  tr -d '\357\200\215\r'
}

# Wrapper helper
git_diff_names() {
  git -C "${1:-.}" diff --name-only 2>/dev/null | git_sanitize
}
```

**Decision (BHV-002 Simplicity First)**: Inline `tr -d '\357\200\215\r'` ngay sau mỗi `git diff` thay vì tạo shared helper. Lý do: chỉ 4 call sites, sharing thêm phụ thuộc cross-script không xứng phức tạp.

### Tasks

- [ ] W3-G6-T1: `safety-check.sh:103` add `| tr -d '\357\200\215\r'` trước `wc -l`
- [ ] W3-G6-T2: `safety-check.sh:106` add `| tr -d '\357\200\215\r'` trước `head -10`
- [ ] W3-G6-T3: `verify-execute-outputs.sh:199` add `| tr -d '\357\200\215\r'` trong subshell pipe
- [ ] W3-G6-T4: `verify-execute-outputs.sh:200` add `| tr -d '\357\200\215\r'` trong subshell pipe
- [ ] W3-G6-T5: Smoke test — chạy `bash safety-check.sh` trên EUREKA-2026 working tree, verify `safety-check.json` không chứa byte 0xEF
- [ ] W3-G6-T6: Sync 2 scripts sang EUREKA `.claude/scripts/wf-fix-bugs/`

### Smoke test command

```bash
cd /d/Working/EUREKA-2026
SESSION_DIR=.mc-data/work/wf-fix-bugs/sessions/test-g6-smoke \
SESSION_ID=test-g6-smoke \
PROJECT_DIR=. \
bash .claude/scripts/wf-fix-bugs/safety-check.sh

# Verify clean
xxd $SESSION_DIR/phase5-triage/safety-check.json | grep -E 'ef ?80 ?8d'
# Expected: 0 matches
```

### Acceptance G6

- ✅ safety-check.json không chứa byte sequence `0xEF 0x80 0x8D` trên Windows
- ✅ Git Bash + WSL đều pass (test trong cả 2)
- ✅ Backward-compat: trên Linux/Mac (không có PUA) → tr không tác động
- ✅ Performance: tr overhead < 5ms per call (negligible)

### Risk

- **LOW** — `tr -d` deterministic, không thay đổi bytes khác.
- Edge case: nếu user thực sự có path với U+F00D trong tên file (cực hiếm) → sẽ bị strip. Document trong comment.

---

## G5 — False-Positive Exclusions (2-3h)

### Mục tiêu

Loại 8 false positives i18n keys khỏi QD3 Security scan (P-QD3-secret-detection). Tránh tốn iteration budget xử lý noise → real bugs có chỗ.

### Evidence (từ root-causes.md R6)

8 issue IDs `ISS-20260516-021/030/048/049/051/079/082/099` đều ở paths matching:
- `apps/erp-web/src/messages/*.json`
- `apps/mobile-customer/src/i18n/locales/*.json`
- `apps/web-customer/messages/*.json`

Trigger: regex secret pattern (generic API key / generic password) match translation key `"password.placeholder": "..."` hoặc value.

### Strategy

3-layer defense:

1. **Probe pre-filter** — bash script `wf-fix-probe-static-secret.sh` skip paths matching exclusion globs
2. **Exclusions config** — JSON file dễ extend/maintain
3. **Phase 5 aggregate de-priority** — nếu vẫn lọt qua probe, aggregate downgrade severity → info

### Tasks

#### G5.1 — Exclusions config

- [ ] W3-G5-T1: Tạo `.claude/skills/workflow/wf-fix-security/exclusions.json` (schema `scan-exclusions-v1`)

```json
{
  "$schema": "scan-exclusions-v1",
  "version": "1.0.0",
  "last_updated": "2026-05-17",
  "purpose": "Path patterns excluded from QD3 secret detection (false positive prevention)",
  "exclusions": {
    "i18n_translations": {
      "patterns": [
        "**/messages/*.json",
        "**/i18n/**/*.json",
        "**/locales/**/*.json",
        "**/translations/*.json",
        "**/lang/*.json"
      ],
      "reason": "Translation keys may contain words matching secret patterns (password, api_key, token) but are not actual credentials",
      "applies_to": ["P-QD3-secret-detection"]
    },
    "test_fixtures": {
      "patterns": [
        "**/*.test.*",
        "**/__tests__/**",
        "**/__fixtures__/**",
        "**/test-data/**",
        "**/mocks/**"
      ],
      "reason": "Test fixtures intentionally contain dummy secrets for testing",
      "applies_to": ["P-QD3-secret-detection", "P-QD3-owasp-top-ten"]
    },
    "docs_examples": {
      "patterns": [
        "**/docs/**/*.md",
        "**/*.example",
        "**/*.example.*",
        "**/README*",
        "**/CHANGELOG*"
      ],
      "reason": "Documentation examples are illustrative, not real secrets",
      "applies_to": ["P-QD3-secret-detection"]
    }
  }
}
```

#### G5.2 — Probe pre-filter implementation

- [ ] W3-G5-T2: Update `wf-fix-probe-static-secret.sh` để đọc exclusions.json + filter trước khi scan

```bash
# Pseudo-code patch
EXCLUSIONS_FILE=".claude/skills/workflow/wf-fix-security/exclusions.json"
EXCLUDED_PATTERNS=()
if [ -f "$EXCLUSIONS_FILE" ]; then
  while IFS= read -r pat; do
    EXCLUDED_PATTERNS+=("$pat")
  done < <(jq -r '.exclusions[] | select(.applies_to[] | contains("P-QD3-secret-detection")) | .patterns[]' "$EXCLUSIONS_FILE")
fi

# Trong scan loop, skip file matching any exclusion
should_scan() {
  local file="$1"
  for pat in "${EXCLUDED_PATTERNS[@]}"; do
    case "$file" in
      $pat) return 1 ;;  # Excluded
    esac
  done
  return 0
}
```

#### G5.3 — Probe MD documentation update

- [ ] W3-G5-T3: Update `procedures/probes/P-QD3-secret-detection.md` section "Filter false positives" thêm reference đến exclusions.json

#### G5.4 — Phase 5 aggregate de-priority (defense-in-depth)

- [ ] W3-G5-T4: `phase5-triage/B-aggregate.md` Step 5.4 thêm post-process: signals matching excluded paths → severity=info, flag `excluded_by_pattern: true`

Lý do tách 2 layer: nếu user disable probe pre-filter qua env var nhưng vẫn muốn de-prio ở aggregate, hoặc nếu probe pre-filter có bug, aggregate là safety net.

#### G5.5 — Smoke test

- [ ] W3-G5-T5: Tạo test fixture `tests/fixtures/g5-i18n-sample/messages/en.json` với keys `"password.label": "Mật khẩu"`, `"apiKey.placeholder": "..."` rồi chạy probe → expect 0 signals
- [ ] W3-G5-T6: Test secondary — real secret AKIA... trong `apps/backend/.env.example` → expect SKIP (docs_examples exclusion)
- [ ] W3-G5-T7: Test tertiary — real AKIA... trong `apps/backend/src/config.ts` → expect 1 CRITICAL signal (không exclude)

### Acceptance G5

- ✅ Trên session settings re-run, 8 i18n false positives KHÔNG xuất hiện trong issue-registry
- ✅ Real secrets vẫn được detect (test fixture verify)
- ✅ exclusions.json schema validate OK (jq parse + $schema field)
- ✅ Probe MD reference exclusions.json (docs sync)
- ✅ Backward-compat: nếu exclusions.json không tồn tại → probe behavior cũ (scan all)

### Risk

- **MEDIUM** — Pattern matching glob có thể miss/over-match. Cần test fixture đầy đủ.
- Mitigation: defensive `should_scan()` default to `return 0` (scan) khi không match → fail-safe direction (rather scan + false positive than miss real secret)

---

## G4 — Cross-Scope CDG E096 + Follow-up Queue (4-6h)

### Mục tiêu

Khi session phát hiện cross-module issues KHÔNG thể fix trong scope hiện tại (vd: scope=module nhưng issue cần touch module khác), skill phải:
1. CDG E096 hỏi user spawn cross-scope session mới
2. Queue follow-up suggestions vào file APPEND-only
3. orchestrator-summary suggest commands cụ thể

### Evidence (từ root-causes.md R5)

Session settings có 8 cross-module runtime issues với action "Mở session wf-fix-bugs --scope=cross-module". Skill tự viết text này vào `deferred-issues-analysis.md` (ad-hoc file) nhưng KHÔNG CDG hỏi user → user phải tự đọc và chạy lệnh.

### Sub-spike: ID Schema Normalization (cần làm trước, ~1h)

3 ID schemes incompatible:
- `issue-registry.json`: `QD9-RT-007` (dimension-probe-N)
- `fix-plan.md`: `ISS-20260516-001` (date-based)
- `fix-report.md`: `ISS-001` (short)

→ Cross-join per-item không khả thi. Cần `id-mapping.json` per session để bridge.

#### G4.0 — ID mapping script

- [ ] W3-G4-T0: Tạo `.claude/scripts/wf-fix-bugs/build-id-mapping.sh`

Input: 3 source files trong session.
Output: `$SESSION_DIR/_meta/id-mapping.json` (schema `id-mapping-v1`)

```json
{
  "$schema": "id-mapping-v1",
  "session_id": "2026-05-17-module-settings-01",
  "generated_at": "2026-05-17T15:00:00Z",
  "mappings": [
    {
      "canonical_id": "QD9-RT-007",
      "registry_id": "QD9-RT-007",
      "plan_id": "ISS-20260516-001",
      "report_id": "ISS-001",
      "title": "Modules Listing Fails to Render Module Pages",
      "scope_required": "cross-module"
    }
  ]
}
```

Logic: match by title fuzzy + severity + dimension → assign canonical_id = registry_id (most stable).

### Main implementation

#### G4.1 — Cross-scope detection

- [ ] W3-G4-T1: Tạo `.claude/scripts/wf-fix-bugs/detect-cross-scope.sh`

Input: `issue-registry.json` + `fix-plan.md` + scope context (system/module/feat).
Output: stdout JSON `{ "cross_scope_count": N, "items": [...] }`.

Logic detect cross-scope:
- Issue path không thuộc current scope (vd: scope=module=settings, issue.file_paths chứa `apps/erp-web/src/app/[locale]/(dashboard)/dispatch/**`)
- Issue có flag `cross_module_dependencies: [...]`
- Issue có action description chứa "cross-module" / "cross-scope" / "spawn session"

#### G4.2 — CDG E096 INLINE block trong Step 6.6 (G-finalize)

- [ ] W3-G4-T2: Update `phase6-execute/G-finalize.md` insert CDG E096 sau core finalize logic, trước POST-GATE

Pseudo-flow:

```bash
# Inside G-finalize.md (Step 6.6)
CROSS_SCOPE_JSON=$(bash .claude/scripts/wf-fix-bugs/detect-cross-scope.sh)
CROSS_COUNT=$(echo "$CROSS_SCOPE_JSON" | jq -r '.cross_scope_count')

if [ "$CROSS_COUNT" -ge ${MCV3_FIX_CROSS_SCOPE_THRESHOLD:-3} ]; then
  # E096: Cross-scope items threshold reached → CDG render INLINE
  # AskUserQuestion 3 options:
  #   1. Spawn cross-scope session now (Recommended)
  #   2. Enqueue follow-up only (defer to user manual run)
  #   3. Ignore (treat as backlog)
  # NOTE: --no-prompt env var → default option 2 (silent enqueue)
fi
```

CDG E096 spec:
- Code: E096
- Type: warning (không block POST-GATE — chỉ suggest)
- Trigger: cross_scope_count >= 3 (env-overridable)
- Anti-loop guard: log decision vào error-ledger, không re-fire trong cùng session

#### G4.3 — Follow-up queue file

- [ ] W3-G4-T3: Schema `_followup-queue.jsonl` (APPEND-only JSONL)

Path: `.mc-data/work/wf-fix-bugs/_followup-queue.jsonl` (KHÔNG per-session — global queue)

Format mỗi line:
```json
{"$schema":"followup-queue-v1","queued_at":"2026-05-17T15:30:00Z","source_session":"2026-05-17-module-settings-01","kind":"cross_scope_fix","suggested_command":"/wf-fix-bugs --scope=cross-module --dims=QD10","items":[{"canonical_id":"QD9-RT-007","title":"...","reason":"..."}],"priority":"high","status":"pending"}
```

`kind` enum: `cross_scope_fix` | `e2e_scenario_fix` (cho wf-cmi compat) | `manual_review`
`status` enum: `pending` | `acknowledged` | `executed` | `dismissed`

- [ ] W3-G4-T4: Helper script `.claude/scripts/wf-fix-bugs/enqueue-followup.sh` (atomic append + lock)

#### G4.4 — orchestrator-summary follow-up section

- [ ] W3-G4-T5: Update `templates/phase7-verify/orchestrator-summary.md` thêm section "Follow-up Suggestions"

```markdown
## Follow-up Suggestions

{{#if FOLLOWUP_COUNT}}
Phát hiện **{{FOLLOWUP_COUNT}}** items cần xử lý ở scope khác:

| # | Kind | Suggested Command | Priority |
|---|------|-------------------|----------|
{{#each FOLLOWUP_ITEMS}}
| {{@index}} | {{kind}} | `{{suggested_command}}` | {{priority}} |
{{/each}}

→ Xem chi tiết: `.mc-data/work/wf-fix-bugs/_followup-queue.jsonl`
{{else}}
Không có follow-up suggestions.
{{/if}}
```

- [ ] W3-G4-T6: Update `generate-phase7-reports.sh` populate {{FOLLOWUP_COUNT}} + {{FOLLOWUP_ITEMS}} từ queue file

#### G4.5 — Smoke test + integration test

- [ ] W3-G4-T7: Test fixture — session với 5 cross-module items → CDG E096 trigger
- [ ] W3-G4-T8: Test queue append → verify JSONL format + lock không corrupt under parallel write
- [ ] W3-G4-T9: Test orchestrator-summary render → section "Follow-up Suggestions" present + accurate

### Acceptance G4

- ✅ Session settings re-run: 8 cross-module items → CDG E096 trigger 1 lần (anti-loop)
- ✅ Queue file `_followup-queue.jsonl` có 1 entry với suggested_command đúng format `/wf-fix-bugs --scope=cross-module --dims=QD10`
- ✅ orchestrator-summary render "Follow-up Suggestions" section với 8 items
- ✅ User chọn "Enqueue follow-up only" → entry status="pending", không spawn session mới
- ✅ User chọn "Spawn cross-scope session" → suggested_command được copy vào clipboard hoặc echo cho user run
- ✅ Backward-compat: env `MCV3_FIX_CROSS_SCOPE_DISABLE=true` → G4 logic skip toàn bộ
- ✅ id-mapping.json schema valid, 3 ID schemes bridge thành công

### Risk

- **HIGH** — Cross-scope logic chạm nhiều surface (detection + CDG + queue + orchestrator-summary). Cần test fixture rộng.
- Mitigation:
  - Threshold default 3 (env-overridable) — không trigger với 1-2 items lẻ
  - CDG E096 type=warning (không block POST-GATE) — fail-open
  - Queue file APPEND-only, lock-protected (tránh race condition)

---

## Wave 3 Acceptance (tổng)

- ✅ G6 (W3-G6-T1..T6) done — safety-check.json clean trên Windows
- ✅ G5 (W3-G5-T1..T7) done — 8 i18n false positives gone
- ✅ G4 (W3-G4-T0..T9) done — cross-scope CDG E096 + queue working
- ✅ Smoke tests pass: routing tests Phase 5/6/7 không regression (254 checks)
- ✅ Cross-skill: wf-verify-sync consume fix-impact.json v1 không break
- ✅ Sessions cũ v10.x/v11.0.x `--resume` chạy bình thường
- ✅ Version bump v11.0.2 → v11.1.0
- ✅ CHANGELOG.md release notes Wave 3
- ✅ Sync EUREKA mirror scripts (5 scripts mới/modified)

---

## Migration Notes v11.0.2 → v11.1.0

### Breaking changes
- **NONE** — Wave 3 hoàn toàn additive.

### Env vars mới
- `MCV3_FIX_CROSS_SCOPE_THRESHOLD` (default 3) — số cross-scope items minimum để trigger CDG E096
- `MCV3_FIX_CROSS_SCOPE_DISABLE` (default false) — skip G4 toàn bộ
- `MCV3_FIX_SECURITY_EXCLUSIONS_DISABLE` (default false) — skip G5 exclusions, scan all paths

### Files mới (8)
- `.claude/scripts/wf-fix-bugs/build-id-mapping.sh`
- `.claude/scripts/wf-fix-bugs/detect-cross-scope.sh`
- `.claude/scripts/wf-fix-bugs/enqueue-followup.sh`
- `.claude/skills/workflow/wf-fix-security/exclusions.json`
- `.claude/skills/workflow/wf-fix-bugs/templates/phase6-execute/id-mapping.json` (template)
- `tests/fixtures/g5-i18n-sample/messages/en.json` (test fixture)
- `tests/fixtures/g5-i18n-sample/.env.example` (test fixture)
- `tests/fixtures/g5-i18n-sample/src/config.ts` (test fixture — real secret)

### Files modified (8)
- `.claude/scripts/wf-fix-bugs/safety-check.sh` — G6 sanitize
- `.claude/scripts/wf-fix-bugs/verify-execute-outputs.sh` — G6 sanitize
- `.claude/scripts/wf-fix-bugs/wf-fix-probe-static-secret.sh` — G5 exclusions
- `.claude/scripts/wf-fix-bugs/generate-phase7-reports.sh` — G4 follow-up populate
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase5-triage/B-aggregate.md` — G5 de-prio
- `.claude/skills/workflow/wf-fix-bugs/procedures/phase6-execute/G-finalize.md` — G4 CDG E096 INLINE
- `.claude/skills/workflow/wf-fix-bugs/templates/phase7-verify/orchestrator-summary.md` — G4 section
- `.claude/skills/workflow/wf-fix-security/procedures/probes/P-QD3-secret-detection.md` — G5 docs ref
- `.claude/skills/workflow/wf-fix-bugs/SKILL.md` — version v11.0.2 → v11.1.0
- `CHANGELOG.md` — release notes

### Cross-skill impact
- **wf-verify-sync**: KHÔNG đổi — fix-impact.json schema v1 giữ nguyên
- **wf-prepare-deployment**: KHÔNG đổi — audit_chain format giữ nguyên
- **wf-implement-feature**: KHÔNG đổi — safety gate input giữ nguyên
- **wf-cmi**: Có thể consume `_followup-queue.jsonl` để generate `integrity-impact.json` cross-references (opt-in, sang phiên khác)

### Resume cũ
Sessions v10.x/v11.0.x `--resume` chạy bình thường:
- G6: tr không tác động nếu byte không tồn tại
- G5: exclusions.json missing → probe behavior cũ
- G4: cross_scope_count < threshold → CDG E096 không trigger

---

## Bugs phát hiện qua production test (placeholder)

> Section này để log bugs phát hiện khi test Wave 3 trước khi release v11.1.0.

(empty — chưa test)
