# §1 State Variables Glossary

> **Slim (v10.13.0):** Phần lớn variable types đã document trong rules. File này chỉ giữ canonical table cho phase-to-phase data flow.
>
> Xem thêm: [CORE-001 — Read registry + docs](../../../../rules/00-core.md#1-single-source-of-truth-b%E1%BA%AFt-bu%E1%BB%99c), [_contract.json](../../_contract.json) `§inputs`/`§outputs`.

Các biến in-memory được set/đọc xuyên suốt pipeline execution.

| Variable | Set by Phase | Read by Phase | Description |
|----------|-------------|---------------|-------------|
| `$SESSION_ID` | 1 | All | `YYYY-MM-DD-{scope}-{slug}-{NN}` |
| `$SESSION_DIR` | 1 | All | `.mc-data/work/wf-fix-bugs/sessions/$SESSION_ID` |
| `$PROFILE` | 1 | 2-7 | `quick` / `standard` / `deep` / `exhaustive` |
| `$DIMS_ARRAY` | 1 | 2-7 | Array QD1..QD11 |
| `$SCOPE` | 1 | 2-4 | `all` / `system` / `module` |
| `$NAME` | 1 | 2-3 | Scope target ID |
| `$LEGACY_MODE` | 1 | 2-6 | Boolean — CORE-021 |
| `$LLM_SCAN` | 1 | 3-5 | Boolean — `--llm-scan` |
| `$DRY_RUN` | 1 | 5-6 | Boolean — `--dry-run` |
| `$SHOW_BROWSER` | 1 | 4 | Boolean — `--show-browser` (Chromium visible). v10.2: auto-set true khi `--mobile`. |
| `$NO_BROWSER` | 1 | 1,3,4 | Boolean — `--no-browser` (skip QD5/QD7/QD9). v10.2: tách khỏi `$SHOW_BROWSER`. |
| `$MOBILE_MODE` | 1 | 2,4,7 | Boolean — `--mobile` (device emulation). |
| `$MOBILE_DEVICE` | 1 | 4 | String — tên device (`iPhone 14`/`Pixel 7`/`iPad Pro`). v10.2: cấu hình qua `--device=<name>` hoặc env `MCV3_MOBILE_DEVICE`. |
| `$GITNEXUS_AVAILABLE` | 1 (CI PRE-GATE) | 2-7 | Boolean — Protocol 20 |
| `$SERENA_AVAILABLE` | 1 (CI PRE-GATE) | 2-7 | Boolean — Protocol 20 |
| `$CI_CONTEXT` | 1 (CI PRE-GATE) | 2,5,6 | CI context string cho sub-skill spawn |
| `$INTERFACE_TYPE` | 2 | 3-7 | `web` / `mobile` / `api-only` / `hybrid` |
| `$TOTAL_ISSUES` | 5 | 6-7 | Integer — từ `issue-registry.json` |
| `$EXECUTION_MODE` | 3 | 4-6 | `inline` / `agent_dispatch` |
| `$SCOPE_INVENTORY` | 2 | 3 | Code + doc inventory results |
| `$CONTEXT_PERCENT` | Every phase | Every phase | Context budget usage |
| `$RETRY_COUNT` | All phases | All phases | Per-phase retry counter array |
| `error_log[]` | All phases | All phases | Array errors cumulative |

## §1.1 Contract Reference: `_contract.json`

> **SSOT cho output paths, templates, error codes, inputs, và cross-skill contracts.**
> `_contract.json` (`wf-fix-bugs/_contract.json`, schema `skill-contract-v1`) là canonical source:
> - **§inputs** — tất cả CLI arguments với type, default, required flag
> - **§outputs.working[]** — mọi output path + template (CORE-031 compliance)
> - **§errors** — namespaced error codes E001-E109 + EDLG (canonical lookup)
> - **§procedure[]** — lazy-load manifest (9 procedure files)
> - **§cross_skill_contracts** — orchestrates (wf-fix-triage, wf-fix-execute), produces_for, consumes_from
>
> Khi thêm/sửa output hoặc error code → **cập nhật `_contract.json` trước**, rồi mới code.
