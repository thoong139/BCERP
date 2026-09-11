# §4 Error Handling Canonical

> **Slim (v10.13.0):** Namespace convention + auto-fix protocol đã canonical trong [CORE-034 — Namespaced Error Codes](../../../../rules/00-core.md#4k-core-034-namespaced-error-codes--auto-fix-budget-b%E1%BA%AFt-bu%E1%BB%99c). File này CHỈ giữ canonical codes table cho wf-fix-bugs (skill-specific lookup).

## Namespace Convention

```
E001-E009   → Pipeline/session/lock (shared)
E010-E019   → Phase 1 Init (flags, CI PRE-GATE, CDG, session)
E020-E029   → Phase 2 Scan (scan code, scan docs, CI tools)
E030-E039   → Phase 3 Plan (ISG, partition, workload gate, dispatch)
E040-E049   → Phase 4 Find Bugs (lane dispatch, probes, Playwright)
E050-E059   → Phase 5 Triage (aggregate, dedup, triage, CDG, safety)
E060-E069   → Phase 6 Execute (fix spawn, docs, verify)
E070-E079   → Phase 7 Verify (CQG, summaries, impact)
E090-E099   → CDG User-Facing Gates (Browser, Scope, Cost, Mobile)
E100-E109   → Recommendations (QD9/QD10/QD11)
```

**Exception: Cross-phase reference codes.** Downstream phases có thể emit upstream namespace codes khi PRE-GATE phát hiện upstream state thiếu/lỗi (vd: Phase 4 PRE-GATE emit E030 khi Phase 3 chưa completed, hoặc E035 cho atomic write fail khi semantically thuộc Phase 3 schema). Các trường hợp này phải được declare trong `_contract.json §errors` với mô tả nêu rõ "cross-phase" + danh sách phases sử dụng.

## Canonical Codes (wf-fix-bugs)

| Code | Severity | Tình huống | Xử lý | Phase |
|------|---------|-----------|-------|-------|
| E001 | high | POST-GATE fail sau 3 retries | DỪNG, escalate | All |
| E002 | medium | User từ chối tiếp tục (CDG reject) | Checkpoint, `--resume` | 3,5,7 |
| E003 | high | Registry thiếu/rỗng | STOP — chạy `/wf-brainstorm` trước | 1 |
| E004 | high | Sub-skill SKILL.md không tồn tại | Báo lỗi path, dừng | 1 |
| E005 | info | N=0 issues sau Phase 5 | "Healthy!" → jump Phase 7 | 5 |
| E009 | high | Context > 90% | FORCE checkpoint, STOP | All |
| E010 | medium | `--status` dispatched | Hiển thị status → STOP | 1 |
| E011 | medium | `--resume` dispatched | Enter resume path | 1 |
| E012 | medium | `--migrate` dispatched | Delegate migration script | 1 |
| E013 | high | Deprecation block (legacy v6.x) | CDG render, escape hatch | 1 |
| E014 | high | CI detection fail | Graceful degrade → Grep/Glob fallback | 1 |
| E015 | high | CI tools unavailable + non-git project | Skip CI, dùng Grep/Glob | 1 |
| E016 | high | CI index severely stale (>50 commits) | WARN mạnh, continue với Grep fallback | 1 |
| E019 | high | Lock acquire fail / heartbeat fail | STOP — process khác active hoặc continue không heartbeat (risky) | 1 |
| E020 | medium | Code scan empty (0 files) | WARN, continue với docs-only | 2 |
| E021 | low | Doc scan empty (0 docs) | INFO, continue | 2 |
| E022 | high | CI tools stale >20 commits | WARN, continue với Grep fallback | 2 |
| E023 | low | interface_type undetectable | Default `web`, WARN | 2 |
| E030 | medium | Profile resolve fail | Fallback profile=standard | 3 |
| E031 | high | Lock acquire fail | STOP — process khác active | 3 |
| E032 | high | Partition planner fail | Auto-generate fallback | 3 |
| E033 | high | Workload Gate aborted | UPDATE fix-status, hướng dẫn resume | 3 |
| E040 | high | Lane dispatch static probe fail | Retry x3, escalate | 4 |
| E041 | medium | Non-static probe fail | Record → probe-failures.log | 4 |
| E042 | medium | LLM probe fail | Record → probe-failures.log | 4 |
| E043 | medium | Agent report missing (sau spawn) | WARN, generate stub | 4 |
| E044 | high | Playwright launch fail | Retry x2, escalate nếu vẫn fail | 4 |
| E045 | medium | Mobile device emulation not supported | WARN, fallback desktop viewport | 4 |
| E050 | high | Phase 5 not done / Aggregator fail | Retry x3, escalate | 5 |
| E051 | high | Step verification fail (sau 3 retries) | CDG render | 5 |
| E052 | medium | Process violation detected | Ghi violation, evaluate severity | 5 |
| E053 | high | Triage spawn fail | Re-spawn x1, escalate | 5 |
| E054 | high | CDG Rejected Critical | Quay lại triage, anti-loop guard | 5 |
| E055 | high | CDG tokens pending / Safety Check blockers | CDG render, reject 2 lần → ESCALATE | 5 |
| E060 | high | Execute spawn fail | Re-spawn x1, escalate | 6 |
| E061 | high | Fix report missing/broken | Retry, escalate | 6 |
| E062 | medium | CI impact analysis / parse fail | Fallback Grep, WARN, ghi error-ledger | 6 |
| E063 | low | Dry-run preview render fail | Retry render x1 → escalate | 6 |
| E064 | medium | Docs sync report invalid JSON | Re-read từ agent output → escalate | 6 |
| E065 | low | Dashboard / fix-log update fail | Retry Atomic Write, WARN (non-critical) | 6 |
| E070 | high | CQG-1 numeric mismatch | Retry up to 3 → E001 | 7 |
| E071 | high | CQG-2 browser/integration gate fail | CDG render, max 2 reject → E001 | 7 |
| E090 | medium | Browser CDG: --show-browser + --no-browser conflict (--no-browser wins) | CDG render, --no-browser wins | 4 |
| E090b | medium | Parallel BASE_URL conflict (peer session) | AskUserQuestion 3 options, bypass MCV3_PW_ALLOW_SHARED_URL=1 | 4 |
| E091 | info | Scope recommendation: ISG suggests narrower scope | WARN log, auto-resolve (no CDG v10.3+) | 3 |
| E092 | info | Cost estimate exceeds budget: LLM scan >$1.50 | WARN log, auto-resolve (no CDG v10.3+) | 3 |
| E093 | info | Mobile recommendation: interface supports mobile but --mobile not set | WARN log, auto-resolve (no CDG v10.3+) | 3 |
| E_LEGACY_BLOCK | fatal | Legacy v6.x paths | Exit 78 | 1 |
| EDLG | high | Sub-skill không hoàn thành | LOG error, FAIL trace | 5,6 |

> **v10.3 Migration Note:** E090/E090b moved Phase 1 → Phase 4 Step 4.3 (just-in-time CDG khi PW_LANE_COUNT > 0). E091/E092/E093 auto-resolve thay vì CDG render (no user interaction needed). E100 (QD9/QD10/QD11 recommendation) deleted — duplicate với Phase 3 ISG Recommender output.

> **Auto-fix budget + escalation protocol:** Xem [_shared/05-auto-fix.md](05-auto-fix.md).
> **On Failure standard flow:** Xem [_shared/06-on-failure.md](06-on-failure.md).
