# Phase 0: Context Loading & Intake

> Parse args, load scan docs, CI detect, sub-skill pre-flight, validate input, init session.
> Phase 0 la buoc dau tien — moi lan chay `/wf-migrate-module` deu bat dau tu day (tru `--resume`).

> **Shared:** Xem `procedures/_shared.md` — State Variables, Session Isolation, LEGACY Detection, Auto-Approve Mode, CI-ROUTE, Sub-Skill Pre-Flight Check.

---

## PRE-GATE

```bash
test -f .mc-data/docs/_meta/req-registry.json
jq -e '.requirements | length > 0' .mc-data/docs/_meta/req-registry.json
```

Neu fail → STOP: *"Du an chua co registry. Chay `/wf-brainstorm` truoc."*

**Forensic validation (Protocol 10.4 — CORE-011):** kiem tra content, khong chi file existence.

---

## INPUT

| File | Duong dan | Dieu kien |
|------|-----------|-----------|
| Registry | `.mc-data/docs/_meta/req-registry.json` | BAT BUOC |
| Scan session | `.mc-data/work/wf-scan-target/sessions/$SCAN_SESSION_ID/` | BAT BUOC |
| Legacy decisions | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | BAT BUOC khi LEGACY_MODE (CORE-022) |
| User prompt | `$ARGUMENTS` | BAT BUOC |

---

## OUTPUT

| File | Template |
|------|----------|
| `$SESSION_DIR/migrate-status.json` | `templates/migrate-status.json` |
| `.mc-data/work/wf-migrate-module/index.json` | `templates/index.json` |
| `$SESSION_DIR/preflight-results.json` | _(new — v1.1)_ |

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 0.0 | **CORE-026 START trace:** Append START entry vao `.mc-data/work/_trace/session-log.json` (xem `_shared.md` §CORE-026) | Write | Entry logged |
| 0.0a | **CI Capabilities Detection (Protocol 20):** Run `bash .claude/scripts/ci-detect.sh` → doc `.mc-data/work/_meta/code-intelligence.json` → set `$GITNEXUS_AVAILABLE`, `$SERENA_AVAILABLE`. Ghi vao `$CI_CAPABILITIES = {gitnexus: bool, serena: bool}`. Neu CI khong available → WARNING + fallback Grep/Glob. | Bash | CI flags set |
| 0.1 | **Handle --status flag:** Neu `$ARGUMENTS` chua `--status` → doc index.json → hien thi bang sessions → STOP (xem `_shared.md` §--status Handler) | Read | Handled |
| 0.2 | **Handle --resume flag:** Neu `$ARGUMENTS` chua `--resume` → doc index.json → checkpoint.json → route den phase tuong ung → STOP sau khi route (xem `_shared.md` §--resume Handler). NEU `--resume-task=<n>` → route den Phase 6 Step 6.0b (xem `_shared.md` §--resume-task Handler) | Read | Handled |
| 0.3 | **Generate MIGRATE_ID + tao session dir:** `$MIGRATE_ID = "MIG-$(date +%Y%m%d)-$(printf '%03d' $NEXT_N)"`. Tao `$SESSION_DIR = .mc-data/work/wf-migrate-module/$MIGRATE_ID/`. Tao `mkdir -p $SESSION_DIR`. Tao `mkdir -p $SESSION_DIR/snapshots`. **BO QUA neu `--resume`.** | Bash | `$SESSION_DIR` exists |
| 0.4 | **Parse `$ARGUMENTS`:** Extract `--from-scan=<id>` → `$SCAN_SESSION_ID`. Extract `--to-system=<id>` → `$TARGET_SYSTEM`. Extract `--to-module=<id>` → `$TARGET_MODULE`. Extract `--auto-approve` → `$AUTO_APPROVE = true` (default `false`). Extract `--dry-run` → `$DRY_RUN = true` (default `false`). Extract `--auto-rollback` → `$AUTO_ROLLBACK = true` (default `false`). Extract `--resume-task=<n>` → `$RESUME_TASK = n` (default `null`). Extract `--skip-phase=<p>` → append to `$SKIP_PHASES[]`. **$USER_PROMPT** = phan mo-ta-yeu-cau tu `$ARGUMENTS` sau khi loai bo tat ca flags. Neu `$USER_PROMPT` trong → E005. | — | Tat ca required args da parse |
| 0.5 | **Validate scan session:** `$SCAN_SESSION_DIR = .mc-data/work/wf-scan-target/sessions/$SCAN_SESSION_ID/`. Kiem tra `test -d $SCAN_SESSION_DIR` → neu khong ton tai → E002. Kiem tra `test -f $SCAN_SESSION_DIR/target-map.json` → neu khong co → E002. Kiem tra `target-map.json` co `"status": "completed"` → neu khong → E003. | Bash | Scan session valid |
| 0.6 | **Load scan docs:** Doc `$SCAN_SESSION_DIR/target-map.json` → set `$TARGET_MAP`. Doc `$SCAN_SESSION_DIR/feature-inventory.md` → set `$FEATURE_INVENTORY`. Doc `$SCAN_SESSION_DIR/module-map.md` → set `$MODULE_MAP`. | Read | Scan docs loaded |
| 0.7 | **Validate target system:** Kiem tra `$TARGET_SYSTEM` co trong registry `systems[]` khong. Neu khong → E004 (hoi user: tao system moi hay nhap lai?). | Read/Grep | Target system confirmed |
| 0.8 | **Validate target module:** Kiem tra `$TARGET_MODULE` co trong registry `modules[]` khong. Set `$MODULE_EXISTS = true/false`. Neu `$MODULE_EXISTS = true` → WARNING: "Module da ton tai. Features moi se duoc merge vao module nay." | Read/Grep | Module status known |
| 0.9 | **LEGACY_MODE Detection (CORE-021):** xem `_shared.md` §LEGACY Detection → set `$LEGACY_MODE`. | Bash | Flag set |
| 0.9b | **CORE-022 — Doc legacy-decisions.json (neu LEGACY_MODE):** xem `_shared.md` §Legacy Decisions Bridge → set `$DEPRECATED_MODULES[]`. | Read | DEPRECATED_MODULES set |
| 0.9c | **Sub-Skill Pre-Flight Check:** Voi moi sub-skill se duoc goi (wf-add-scope, wf-define-features, wf-design, wf-plan-modules, wf-implement-feature), chay pre-flight check theo `_shared.md` §Sub-Skill Pre-Flight Check. Doc `_contract.json` cua tung sub-skill → verify `inputs[]` + `prerequisites` → ghi ket qua vao `$PREFLIGHT_RESULTS`. Neu bat ky sub-skill nao fail → WARNING + hoi user (E016). Ghi `$SESSION_DIR/preflight-results.json`. | Read | Pre-flight done |
| 0.10 | **Khoi tao index.json:** Doc `templates/index.json` → POPULATE session data (`$MIGRATE_ID`, `$SCAN_SESSION_ID`, `$TARGET_SYSTEM`, `$TARGET_MODULE`, `$SOURCE_MODULE` tu scan docs, status="intake", `$AUTO_APPROVE`) → WRITE `.mc-data/work/wf-migrate-module/index.json`. | Read/Write | index.json created |
| 0.11 | **Khoi tao migrate-status.json:** Doc `templates/migrate-status.json` → POPULATE session data (tat ca state variables, current_phase="intake", status="in_progress", flags.auto_approve=`$AUTO_APPROVE`, flags.ci_capabilities=`$CI_CAPABILITIES`) → WRITE `$SESSION_DIR/migrate-status.json`. | Read/Write | Status file created |
| 0.12 | **Luu checkpoint:** Doc `templates/checkpoint.json` → POPULATE (current_phase="phase0", next_phase="phase1") → WRITE `$SESSION_DIR/checkpoint.json`. | Read/Write | Checkpoint created |

---

## POST-GATE

```bash
test -f .mc-data/work/wf-migrate-module/index.json
test -f $SESSION_DIR/migrate-status.json
test -f $SESSION_DIR/checkpoint.json
test -f $SESSION_DIR/preflight-results.json
test -f $SCAN_SESSION_DIR/target-map.json
jq -e '.status == "in_progress"' $SESSION_DIR/migrate-status.json
```

---

## Next Phase

→ `procedures/phase1-gap-analysis.md`
