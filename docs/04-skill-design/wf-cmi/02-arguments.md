# 02 — Arguments

> **Mục đích file:** Đặc tả arguments của skill `wf-cmi` — type, default, validation, interactions, profile detail.

---

## 1. Bảng arguments

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `--scope` | string | `system` | Không | Phạm vi: `system` (toàn ERP), `module=<name>` (1 module), `feat=<id>` (1 feature) |
| `--profile` | enum | `standard` | Không | `quick` / `standard` / `deep` / `exhaustive` — quyết định coverage threshold + lane activation |
| `--dims` | csv string | (all) | Không | Subset lanes — vd `CD1,CD3,CD5` để chỉ chạy 3 dim |
| `--since` | git-ref | (none) | Không | Regression-aware mode: chỉ phân tích files đổi từ ref (vd `--since=main`, `--since=HEAD~10`, `--since=v1.2.0`) |
| `--from-fix-bugs` | flag | — | Không | Consume `fix-impact.json` từ wf-fix-bugs (last session) làm input seed |
| `--from-verify-sync` | flag | — | Không | Consume `verify-sync-impact.json` từ wf-verify-sync làm input seed |
| `--from-impl` | flag | — | Không | Consume `impl-status.json` từ wf-implement-feature làm input seed |
| `--auto-suggest` | flag | — | Không | Phase 7 đề xuất artifact bổ sung (test case, invariant rule, contract) qua CDG |
| `--dry-run` | flag | — | Không | Mô phỏng — KHÔNG ghi registry update, KHÔNG record CDG decisions |
| `--ci` | flag | — | Không | GitHub Action mode: read-only, không update registry, output JSON + post lên PR |
| `--resume` | flag | — | Không | Resume session đang dở (đọc `integrity-status.json` → route next phase) |
| `--status` | flag | — | Không | In trạng thái session hiện tại (không chạy phases) → exit 0 |
| `--session-id` | string | (auto) | Không | Manual session ID (format `YYYY-MM-DD-{scope}-{slug}-NN`) — dùng cho `--resume` ambigous |
| `--no-cache` | flag | — | Không | Bỏ qua scan cache + CI cache, force fresh scan |
| `--show-graphs` | flag | — | Không | Phase 8 render Mermaid diagrams cho 6 graphs vào `integrity-report.md` |

---

## 2. Argument interactions

| Combo | Behavior |
|-------|----------|
| `--resume` + `--scope` | `--scope` bị ignore (lấy từ `integrity-status.json` cũ) |
| `--resume` + `--profile` | `--profile` bị ignore (lấy từ session cũ) |
| `--scope=feat=<id>` + `--profile=exhaustive` | WARNING — exhaustive overkill cho 1 FEAT; auto-downgrade → deep |
| `--scope=system` + `--profile=quick` | WARNING — quick có thể không đủ coverage cho system; auto-upgrade → standard qua CDG E091 |
| `--dry-run` + `--auto-suggest` | OK — dry-run chỉ report đề xuất, không invoke CDG actual write |
| `--ci` + `--auto-suggest` | ERROR (E012) — CI mode không phép write CDG decisions, mutually exclusive |
| `--ci` + `--scope=system` + profile=deep/exhaustive | WARNING — CI run >30 min có thể timeout GitHub Actions; auto-downgrade → standard |
| `--since=<ref>` + `--scope=feat=<id>` | OK — chỉ check FEAT có touch files đổi từ ref không; nếu không → exit 0 với report "no changes" |
| `--dims=CD1,CD3` + `--profile=exhaustive` | OK — exhaustive áp dụng cho 2 lanes được chỉ định, các lane khác skip |
| `--from-fix-bugs` + `--from-verify-sync` | OK — consume cả 2 artifacts, merge findings (priority: fix-bugs > verify-sync) |
| `--from-fix-bugs` + `--no-cache` | OK — `--from-fix-bugs` đọc artifact cũ; `--no-cache` invalidate scan cache (orthogonal) |

---

## 3. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| `--scope` | Regex `^(system|module=[a-z0-9-]+|feat=FEAT-[A-Z]+-[A-Z0-9-]+)$` | E010 |
| `--profile` | In set {quick, standard, deep, exhaustive} | E011 |
| `--dims` | Mỗi item match `CD[1-9]|CD10` (case-insensitive, normalize uppercase) | E013 |
| `--since` | `git rev-parse --verify <ref>` PASS | E014 |
| `--session-id` | Match `YYYY-MM-DD-{scope}-{slug}-NN` exact | E015 |
| `--ci` | `$CI=true` hoặc `$GITHUB_ACTIONS=true` env set (else WARN downgrade) | E100 (non-blocking) |
| `--auto-suggest` + `--dry-run` | Conflict check: nếu cả 2 set, log INFO không error | — |
| `--auto-suggest` + `--ci` | Conflict ERROR | E012 |

---

## 4. Examples

```bash
# Run đầy đủ system-wide standard profile (default cho daily work)
/wf-cmi

# Quick scan toàn hệ thống cho hotfix khẩn
/wf-cmi --profile=quick

# Deep scan 1 module trước release
/wf-cmi --scope=module=orders --profile=deep

# Exhaustive audit toàn hệ thống cho compliance release (~2-3h)
/wf-cmi --profile=exhaustive

# Subset 3 lanes (CD1 Business + CD3 Workflow + CD5 Event) cho focus check
/wf-cmi --dims=CD1,CD3,CD5

# Regression-aware: chỉ check files đổi từ main branch (PR review)
/wf-cmi --since=main --profile=standard

# Auto-suggest artifacts bổ sung (test/contract/invariant) qua CDG
/wf-cmi --profile=deep --auto-suggest

# Consume upstream artifacts từ wf-fix-bugs + wf-verify-sync
/wf-cmi --from-fix-bugs --from-verify-sync --profile=standard

# Resume session đang dở
/wf-cmi --resume

# Status check
/wf-cmi --status

# Dry-run xem trước, không ghi registry
/wf-cmi --profile=deep --dry-run

# GitHub Action CI mode (read-only, post lên PR)
/wf-cmi --ci --profile=standard --since=main

# Show graphs Mermaid trong report (visualize 6 graphs)
/wf-cmi --profile=standard --show-graphs

# Force fresh scan (bỏ cache)
/wf-cmi --profile=deep --no-cache
```

---

## 5. Profile detail

| Profile | Time (EUREKA 17 modules) | Coverage threshold/dim | LLM (Phase 3 invariant infer) | Playwright | Cache policy | Max concurrency |
|---------|-------------------------|------------------------|-------------------------------|------------|--------------|-----------------|
| `quick` | 5-10 min | ≥60% | Skip (heuristic + pattern only) | ❌ | Aggressive (24h TTL) | 5 sessions/máy |
| `standard` | 15-30 min | ≥80% | 1-pass (cross-module pattern) | Assisted | Normal (24h TTL) | 5 sessions/máy |
| `deep` | 45-90 min | ≥95% | 3-pass (cross-module + domain heuristic + registry gap) | Full | Selective (4h TTL) | 2 sessions/máy |
| `exhaustive` | 120-180 min | =100% | 3-pass + cross-domain conflict resolution | Full + devices | Skip cache | 2 sessions/máy |

**Default:** `standard` (cân bằng thoroughness vs cost cho daily work).

### 5.1 Lane activation matrix theo profile

| Lane | quick | standard | deep | exhaustive |
|------|:-----:|:--------:|:----:|:----------:|
| CD1 Business domain | ✅ (heuristic) | ✅ (1-pass LLM) | ✅ (3-pass LLM) | ✅ (3-pass + cross-domain) |
| CD2 Entity dependency | ✅ | ✅ | ✅ | ✅ |
| CD3 Workflow coverage | ✅ | ✅ | ✅ | ✅ |
| CD4 API contract | ✅ | ✅ | ✅ | ✅ |
| CD5 Event coverage | ❌ | ✅ | ✅ | ✅ |
| CD6 Permission/RBAC | ❌ | ✅ | ✅ | ✅ |
| CD7 Data integrity | ✅ | ✅ | ✅ | ✅ |
| CD8 Observability | ❌ | ❌ | ✅ | ✅ |
| CD9 Regression coverage | ❌ | ✅ | ✅ | ✅ |
| CD10 Documentation | ❌ | ❌ | ✅ | ✅ |

> **Detail per profile + cache policy + decision matrix:** xem [05-execution-profiles.md](05-execution-profiles.md).

### 5.2 CDG escalation rules per profile

- **quick:** coverage < 60% bất kỳ dim → E090 CDG "Coverage thấp — accept gap hay upgrade profile?"
- **standard:** coverage < 80% → E090 CDG; nếu CRITICAL invariant violation → E091 dual-approval
- **deep:** coverage < 95% → E090 CDG; nếu cross-module dependency missing > 3 → E092 CDG "System integrity degraded"
- **exhaustive:** coverage < 100% → E090 CDG bắt buộc; KHÔNG cho pass nếu vi phạm BẤT KỲ invariant `severity=MUST`

---

## 6. Liên kết

- Validation script: [`.claude/scripts/wf-cmi/validate-args.sh`](../../../.claude/scripts/) (sẽ tạo)
- Error codes detail: [05-error-codes.md](05-error-codes.md)
- Profile execution: [05-execution-profiles.md](05-execution-profiles.md)
- Phase routing: [03-phase-routing.md](03-phase-routing.md) §3 (profile dispatch)
