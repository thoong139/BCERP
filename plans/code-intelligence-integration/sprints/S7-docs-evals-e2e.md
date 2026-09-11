# Sprint 7: Documentation + Evals + E2E Test + Multi-Dev Test

> **Estimate:** 2h | **Priority:** P1 | **Dependencies:** S1-S6
> **Revised v0.3:** Lock timeout 60s in eval CI-E10, 26 findings (was 17), token methodology from master plan §4.3, non-git test scenario

---

## Tasks

### Task 7.1: Update CLAUDE.md — 0.25h

**File:** `CLAUDE.md`

Thêm section về Code Intelligence integration:

```markdown
## Code Intelligence Integration

MCV3 tự động phát hiện và sử dụng GitNexus + Serena khi available trên target project.

| Tool | Purpose | When used |
|------|---------|-----------|
| GitNexus | Impact analysis, execution flows, API routes | System-level questions |
| Serena | Find definition, find references, rename symbol | Symbol-level operations |

**Auto-detection:** Skills tự động phát hiện qua `ci-detect.sh` → cache per-tool TTL.
**Index freshness:** Mỗi PRE-GATE kiểm tra index có khớp HEAD không → cảnh báo nếu stale.
**Concurrency:** Lock-protected cache write (60s stale timeout). Lock bị giữ → fallback Grep (không block).
**Graceful degradation:** Thiếu tool → tự động fallback về Grep/Glob.
**Zero-config:** Người dùng không cần làm gì để kích hoạt. Advanced: `MCV3_CI_RESCAN=1`.
```

**Acceptance criteria:**
- [ ] CI section trong CLAUDE.md
- [ ] Ngắn gọn, rõ ràng cho cả human và AI
- [ ] Đề cập đủ: auto-detect, index freshness, concurrency safety (60s lock), graceful degradation

---

### Task 7.2: Create Evals — 0.5h

**File:** `.claude/skills/protocols/evals/ci-evals.json` (new)

Tạo ≥20 test cases:

| ID | Test case | Expected |
|----|-----------|----------|
| **Detection & Per-Tool TTL** | | |
| CI-E01 | Both GitNexus + Serena available | Cache: both.available=true, per-tool checked_at + ttl_hours |
| CI-E02 | Only GitNexus available | Cache: gitnexus.available=true, serena.available=false, serena.ttl_hours=1 |
| CI-E03 | Only Serena available | Cache: gitnexus.available=false, gitnexus.ttl_hours=4, serena.available=true |
| CI-E04 | Neither available | Cache: both false, agent context not injected |
| CI-E05 | Serena absent TTL 1h | `checked_at` > 1h ago → re-scan Serena, update `checked_at` |
| CI-E06 | GitNexus present TTL 24h | `checked_at` < 24h ago → skip re-scan |
| CI-E07 | GitNexus absent TTL 4h | `checked_at` > 4h ago → re-scan GitNexus |
| CI-E08 | `MCV3_CI_RESCAN=1` | Force re-scan bất kể TTL (respects lock) |
| **Lock & Concurrency** | | |
| CI-E09 | Lock acquired | ci-detect exit 0, lock file tồn tại với PID\|host\|user |
| CI-E10 | Lock held by another session | ci-detect exit 2, không block, fallback message |
| CI-E11 | Stale lock (> 60 giây) | Break stale lock → acquire → scan → release |
| CI-E12 | 2 terminal đồng thời (cache miss) | T1: acquire → CI tools. T2: lock held → Grep fallback. Cache valid. |
| **Index Freshness** | | |
| CI-E13 | HEAD == index_commit | ci-freshness-check exit 0, status=ok, behind=0 |
| CI-E14 | HEAD ahead by 3 commits | ci-freshness-check exit 1, status=warning, level=light |
| CI-E15 | HEAD ahead by 15 commits | ci-freshness-check exit 2, status=warning, level=strong |
| CI-E16 | HEAD ahead by 50 commits | ci-freshness-check exit 3, status=warning, level=severe |
| CI-E17 | index_commit missing | ci-freshness-check exit 0, status=unknown (skip gracefully) |
| CI-E18 | Not a git repo | ci-freshness-check exit 0, status=skipped (short-circuit) |
| **Cache Migration** | | |
| CI-E19 | Cache v1 detected | Auto-migrate: force re-scan → v2 (F26) |
| **Agent Context Injection** | | |
| CI-E20 | Both tools available, no freshness issue | Both-OK template < 600 chars, no freshness warning |
| CI-E21 | Both tools + freshness severe | Both-Stale template < 700 chars, includes ⚠ severe warning |
| CI-E22 | GitNexus-only + freshness light | GitNexus template < 500 chars, includes ⚠ light warning |
| CI-E23 | Serena-only | Serena template < 400 chars, "real-time, always current" |
| **Graceful Degradation** | | |
| CI-E24 | No CI tools available | All skills fallback Grep/Glob, không ERROR |
| CI-E25 | Lock held → fallback | Skill dùng Grep, không chờ lock, không regression |
| CI-E26 | Cache corrupt | Re-scan → write valid cache |

**Acceptance criteria:**
- [ ] ≥20 evals defined
- [ ] Cover tất cả 4 CI scenarios (both, gitnexus-only, serena-only, none)
- [ ] Cover per-tool TTL logic (bao gồm GitNexus-absent 4h)
- [ ] Cover lock acquire + held + stale (60s timeout) scenarios
- [ ] Cover freshness check 4 mức + edge cases + git short-circuit
- [ ] Cover cache schema migration v1→v2 (F26)
- [ ] Cover agent injection 4 templates (Both-OK, Both-Stale, GitNexus-only, Serena-only)
- [ ] Cover graceful degradation
- [ ] Cover multi-dev concurrency scenario (CI-E12)

---

### Task 7.3: E2E Test trên EUREKA-2026 — 0.5h

1. Chạy `ci-detect.sh` → verify cache file (schema v2, per-tool TTL, index_commit, repo)
2. Chạy `ci-freshness-check.sh` → verify OK khi HEAD == index_commit
3. Chạy `wf-implement-feature` MODIFY → verify impact analysis + freshness check
4. Chạy `wf-fix-bugs` → verify orchestrator passes CI context → `wf-fix-triage` dùng `gitnexus_query()` + `wf-fix-execute` dùng `gitnexus_impact()`
5. Chạy `wf-legacy-scan` → verify token reduction (measure per methodology in master plan §4.3)
6. Verify không có user prompt nào về CI tools
7. Verify lock file được tạo và release đúng (60s stale timeout)

**Token measurement methodology (from master plan §4.3):**
- Đo context token usage bằng `claude_code_session_info` hoặc manual estimate từ conversation length
- Baseline: Grep/Glob approach (không CI) cho cùng task → token usage = B
- CI approach: GitNexus/Serena → token usage = C
- Target: C ≤ 0.7 × B (-30% minimum)

**Acceptance criteria:**
- [ ] E2E trên EUREKA-2026 PASS (cả 7 steps)
- [ ] Graceful degradation test trên project không CI PASS
- [ ] Zero user prompt về CI tools
- [ ] Lock acquire/release cycle hoàn chỉnh (60s timeout)
- [ ] Token reduction ≥30% (đo bằng methodology trên)

---

### Task 7.4: Multi-Dev & Concurrency Test — 0.5h

Đây là phần test mới (từ peer review F15-F17) — kiểm tra các scenario song song và team.

**Test 1: 2 terminal, cùng skill, cache miss đồng thời**
```
Terminal 1: /wf-implement-feature Checkout  (cache miss)
Terminal 2: /wf-implement-feature Payment   (cache miss, gần như đồng thời)

Expected:
- Terminal 1: acquire lock → scan → dùng CI tools ✓
- Terminal 2: lock held → fallback Grep → hoạt động bình thường ✓
- Cache file: valid JSON, không corrupt ✓
```

**Test 2: 2 terminal, khác skill, cách nhau 10 giây**
```
Terminal 1: /wf-implement-feature Cart      (cache miss, scan, write, release)
Terminal 2: /wf-fix-bugs "login crash"      (chạy sau 10s)

Expected:
- Terminal 1: acquire lock → scan → dùng CI tools ✓
- Terminal 2: cache HIT (do Terminal 1 vừa ghi) → dùng CI tools ✓
```

**Test 3: Index stale sau git pull**
```
1. git checkout old-commit → gitnexus analyze (index cũ)
2. git checkout main (HEAD mới, index cũ)
3. /wf-implement-feature Test
Expected:
- freshness check: behind = N commits → WARNING hiển thị ✓
- gitnexus_impact() vẫn chạy, kèm caveat ✓
- Không block execution ✓
```

**Test 4: Serena cài giữa phiên**
```
1. cache: serena.available=false, checked_at = 2h ago, ttl_hours=1
2. /wf-implement-feature Test
Expected:
- Serena TTL 1h → "stale" → re-check Serena ✓
- Nếu Serena giờ đã available → cache updated with serena.available=true, ttl_hours=24 ✓
- Agent được inject Serena context ✓
```

**Test 5: Non-git project (short-circuit)**
```
1. cd non-git-project/
2. /wf-implement-feature Test
Expected:
- ci-detect.sh exit 1 (no git remote → can't resolve GitNexus repo)
- ci-freshness-check.sh exit 0 (status=skipped — short-circuit)
- Skill tiếp tục với Grep/Glob, không ERROR ✓
```

**Acceptance criteria:**
- [ ] Test 1: 2 terminal đồng thời → lock hoạt động, không corrupt
- [ ] Test 2: terminal sau (10s) → dùng CI tools từ cache
- [ ] Test 3: git pull → freshness warning, không block
- [ ] Test 4: Serena absent TTL 1h → re-check → update cache
- [ ] Test 5: Non-git → short-circuit, không ERROR

---

### Task 7.5: Compliance Audit — 0.25h

Chạy compliance audit cho tất cả modified skills:

```bash
./.claude/scripts/skill-compliance-audit.sh wf-implement-feature
./.claude/scripts/skill-compliance-audit.sh wf-fix-bugs
./.claude/scripts/skill-compliance-audit.sh wf-fix-triage
./.claude/scripts/skill-compliance-audit.sh wf-fix-execute
./.claude/scripts/skill-compliance-audit.sh wf-manage-change
./.claude/scripts/skill-compliance-audit.sh wf-legacy-scan
./.claude/scripts/skill-compliance-audit.sh wf-design
./.claude/scripts/skill-compliance-audit.sh wf-verify-sync
./.claude/scripts/skill-compliance-audit.sh wf-plan-modules
```

Và schema sync:
```bash
./.claude/scripts/validate-schema-sync.sh --all
```

**Acceptance criteria:**
- [ ] Tất cả modified skills PASS compliance audit
- [ ] Schema sync PASS cho tất cả skills
- [ ] Fix mọi CRITICAL/REQUIRED issues nếu có

---

## Sprint 7 DoD

- [ ] CLAUDE.md updated với CI section (auto-detect, freshness, concurrency 60s, degradation)
- [ ] ≥20 evals defined + documented (detection, lock, freshness, migration, injection, degradation, concurrency)
- [ ] E2E test trên EUREKA-2026 PASS
- [ ] Multi-dev & concurrency tests PASS (5 scenarios including non-git)
- [ ] Graceful degradation test PASS
- [ ] Token reduction measured + documented (≥30%, per methodology in master plan §4.3)
- [ ] All compliance audits PASS
- [ ] Schema sync PASS
- [ ] All 26 findings addressed (6 P0, 11 P1, 8 P2, 1 P3)
