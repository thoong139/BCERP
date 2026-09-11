# E2E Test Prompt: `/wf-fix-bugs` CI Integration trên EUREKA-2026

> **Mục đích:** Verify skill `wf-fix-bugs` (v7.4.0) hoạt động đúng với GitNexus + Serena trên dự án thật.
> Nếu phát hiện bug ở skill design → fix vào MCV3 source rồi sync lại.

## Cách dùng

1. Mở Claude Code session **trong thư mục `D:/Working/EUREKA-2026/`** (không phải MCV3)
2. Paste TOÀN BỘ block từ `===BEGIN PROMPT===` đến `===END PROMPT===` làm message đầu
3. Đọc kỹ test report cuối cùng + danh sách MCV3 files đã sửa

---

```
===BEGIN PROMPT===

# E2E Test: /wf-fix-bugs CI Integration on EUREKA-2026

## Mục tiêu

Test end-to-end skill `/wf-fix-bugs` v7.4.0 để verify integration với GitNexus + Serena hoạt động đúng. Nếu tìm thấy bug ở skill/script/procedure → fix vào MCV3 source (`D:/Working/MCV3/.claude/`) rồi sync lại EUREKA bằng `sync-claude-to-eureka.sh`.

## Bối cảnh

- **Working dir hiện tại:** `D:/Working/EUREKA-2026` (production project — phải cẩn thận)
- **MCV3 source:** `D:/Working/MCV3` (skill source — fix-back target)
- **MCP đã đăng ký** (`.mcp.json`): `gitnexus` + `serena` (không namespace)
- **GitNexus index:** đã sẵn (~174,527 nodes / 7,586 files / 300 flows) — kiểm `.gitnexus/meta.json`
- **Serena project:** đã onboarding — kiểm `.serena/project.yml`
- **Sync command (MCV3 → EUREKA):**
  `bash D:/Working/MCV3/scripts/sync-claude-to-eureka.sh`
  (Mirror 10 thư mục `.claude/`, PRESERVE `.mc-data/`, `settings.json`, `.mcignore`)
- **Test report file:** Tự sinh path `.mc-data/work/_audit/wf-fix-bugs-e2e-$(date +%Y%m%d-%H%M).md`, append findings vào đó song song với các stage.

## Constraints (BẮT BUỘC)

- **TUYỆT ĐỐI KHÔNG** chạy `/wf-fix-bugs` không có `--dry-run` (sẽ modify code production)
- **KHÔNG** đụng vào `.mc-data/docs/` của EUREKA-2026 (production data)
- **KHÔNG** rebuild GitNexus index (`npx gitnexus analyze`) trừ khi cache schema sai và user xác nhận
- **KHÔNG** fix bugs trong code app EUREKA — chỉ fix bugs trong skill/script/procedure vào MCV3
- MCP failure → log finding, KHÔNG crash, tiếp stage tiếp theo
- Context > 80% → checkpoint vào test report, kết thúc gracefully

## Acceptance Criteria

Skill PASS khi:

| # | Tiêu chí | Verify bằng |
|---|----------|-------------|
| AC1 | CI PRE-GATE detect cả GitNexus + Serena | `.mc-data/work/_meta/code-intelligence.json` có cả 2 `available: true` |
| AC2 | Cache schema khớp Protocol 20 | Có fields: `gitnexus.repo`, `symbols`, `relationships`, `execution_flows`, `serena.available`, TTL fields |
| AC3 | Freshness check trả level hợp lệ | Output `{level: ok\|light\|strong\|severe, behind: N}` |
| AC4 | Context injection sinh template "Both-OK" | Output chứa từ khóa: `impact`, `find_symbol`, `find_references`, `query`, `detect_changes` |
| AC5 | Phase 1 lane dispatch chạy được | `lanes/QD*/signals.json` ≥1 file, schema lane-signals-v1 |
| AC6 | wf-fix-triage thật sự dùng CI tools | `bug-triage.md` reference GitNexus query() / Serena find_symbol cho ≥1 issue |
| AC7 | CI context inject vào agent_dispatch prompt | Khi mode=agent_dispatch, prompt có section `## Code Intelligence` (kiểm qua trace log nếu có) |
| AC8 | Graceful degradation | Lock held → fallback Grep, không crash. Non-MCP env → vẫn chạy được |

## Plan — TodoWrite 7 stages

Tạo TodoWrite ngay với 7 items tương ứng 7 stages dưới. Mark `in_progress` khi bắt đầu mỗi stage, `completed` khi đạt PASS criteria.

---

### Stage 1 — Environment Sanity Check (read-only, ~30s)

Chạy SONG SONG (1 message, nhiều Bash calls):

```bash
# Check 1
cat .mcp.json
# Check 2
cat .gitnexus/meta.json
# Check 3
head -30 .serena/project.yml
# Check 4
ls .claude/scripts/ci-*.sh
# Check 5
head -20 .claude/skills/workflow/wf-fix-bugs/SKILL.md
# Check 6
git rev-parse HEAD
```

**PASS criteria:**
- `.mcp.json` có cả `gitnexus` + `serena`
- `.gitnexus/meta.json` parse được, có `stats.files > 1000`, `stats.processes > 0`
- `.serena/project.yml` có `language` và `project_name`
- 3 scripts `ci-detect.sh`, `ci-freshness-check.sh`, `ci-inject-context.sh` tồn tại
- SKILL.md có `version: 7.4.0`
- HEAD commit khác `.gitnexus/meta.json:lastCommit` không quá 20 commits

Log vào report: stage 1 PASS / FAIL + chi tiết.

---

### Stage 2 — Lock Cleanup + CI Detect

```bash
# Check stale lock (heartbeat > 60s = stale per Protocol 20)
LOCK_FILE=".mc-data/work/_meta/.ci-cache.lock"
if [ -f "$LOCK_FILE" ]; then
  LOCK_TS=$(awk -F'|' '{print $5}' "$LOCK_FILE")
  echo "Lock heartbeat: $LOCK_TS, now: $(date -Iseconds)"
fi

# Run CI detect
bash .claude/scripts/ci-detect.sh 2>&1 | tee /tmp/ci-detect-output.json

# Parse status
echo "---"
jq -r '.status, .action' /tmp/ci-detect-output.json
```

**Quyết định:**
- Nếu lock stale (> 60s) → `rm "$LOCK_FILE"` rồi rerun
- Status `all_fresh` → skip Stage 3, đi Stage 4
- Status `needs_scan` → đi Stage 3
- Status `lock_held` → log finding (lock not auto-released after stale), đợi 65s rồi retry

**PASS:** Exit 0, status thuộc {all_fresh, needs_scan}, có action field.

---

### Stage 3 — MCP Detection (chỉ chạy nếu `needs_scan`)

**A. Detect GitNexus:**
```
1. Gọi tool ListMcpResourcesTool → liệt kê resources
2. Tìm resource có URI prefix "gitnexus://"
3. Nếu có → đọc "gitnexus://repo/MCV3/context" hoặc tương đương qua ReadMcpResourceTool
   (note: repo name trong gitnexus có thể là "EUREKA-2026" hoặc tùy cấu hình — đọc từ meta.json đã có ở Stage 1)
4. Parse JSON response → lấy: repo, stats.symbols, stats.relationships, stats.processes
```

**B. Detect Serena:**
```
1. Gọi tool mcp__serena__check_onboarding_performed
2. Parse response → onboarding_performed boolean
```

**C. Build cache + Write:**
```bash
# Build JSON từ kết quả A + B (thay placeholder bằng giá trị thật)
MCP_RESULT=$(jq -n \
  --argjson gitnexus_avail true \
  --arg gitnexus_repo "EUREKA-2026" \
  --argjson gitnexus_symbols 174527 \
  --argjson gitnexus_relationships 349449 \
  --argjson gitnexus_flows 300 \
  --argjson serena_avail true \
  '{
    gitnexus_available: $gitnexus_avail,
    gitnexus_repo: $gitnexus_repo,
    gitnexus_symbols: $gitnexus_symbols,
    gitnexus_relationships: $gitnexus_relationships,
    gitnexus_flows: $gitnexus_flows,
    serena_available: $serena_avail
  }')

bash .claude/scripts/ci-detect.sh --write-cache "$MCP_RESULT"
```

**D. Verify cache:**
```bash
cat .mc-data/work/_meta/code-intelligence.json | jq '.'
```

**PASS criteria:**
- Cache file tồn tại + parse được JSON
- `.gitnexus.available == true` AND `.serena.available == true`
- `.gitnexus.symbols > 100000`
- `.gitnexus.execution_flows > 100`
- Cache có TTL fields theo Protocol 20 (`updated_at`, `gitnexus.ttl_until`, `serena.ttl_until`)

**Findings nếu fail:**
- ListMcpResourcesTool không trả gitnexus → BUG-MCP hoặc MCP server chưa chạy → KHÔNG fix MCV3, log + skip stages CI
- mcp__serena__check_onboarding_performed lỗi → BUG-MCP-SERENA → log
- Cache JSON thiếu fields → BUG-SCRIPT (`ci-detect.sh` ở MCV3) → fix vào MCV3

---

### Stage 4 — Freshness Check + Context Injection

```bash
# Freshness
bash .claude/scripts/ci-freshness-check.sh 2>&1 | tee /tmp/ci-freshness.json
echo "---"
jq -r '.level, .behind' /tmp/ci-freshness.json

# Context injection
bash .claude/scripts/ci-inject-context.sh 2>&1 | tee /tmp/ci-context.txt
echo "---"
echo "Context length: $(wc -l < /tmp/ci-context.txt) lines"
```

**PASS criteria:**
- Freshness output: `level ∈ {ok,light,strong,severe}`, `behind` ≥ 0
- Context output ≥ 10 lines, chứa ÍT NHẤT 4 từ khóa: `impact`, `find_symbol`, `find_references`, `query`, `detect_changes`
- Template "Both-OK" được chọn (vì cả 2 tools available)

**Findings nếu fail:**
- Template chỉ "GitNexus-only" hoặc "Serena-only" dù cache có cả 2 → BUG-SCRIPT (`ci-inject-context.sh`) → fix MCV3
- Thiếu CI-ROUTE keyword → BUG-TEMPLATE → fix MCV3

---

### Stage 5 — Skill Smoke Test 5A: `/wf-fix-bugs --status`

Chạy lệnh slash:
```
/wf-fix-bugs --status
```

Quan sát output. **PASS criteria:**
- Lệnh trả về trong < 30s
- Có hiển thị "CI PRE-GATE" hoặc "Code Intelligence" trong output
- Không có ERROR/CRASH messages
- Session table hiển thị (kể cả empty)

Log output vào test report.

---

### Stage 6 — Skill Smoke Test 5B: `/wf-fix-bugs --dry-run` trên 1 module nhỏ

**Chọn module nhỏ nhất:**
```bash
# List modules + count files
for d in apps/backend/Eureka.Modules.*; do
  echo "$(find "$d" -name '*.cs' 2>/dev/null | wc -l) $d"
done | sort -n | head -5
```

Chọn module có **dưới 50 files** (ưu tiên Eureka.Modules.QC, Compliance, hoặc Settings nếu nhỏ). Lưu `MODULE_NAME=<chosen>`.

**Chạy dry-run:**
```
/wf-fix-bugs --dry-run --scope=module --name=<MODULE_NAME> --profile=quick
```

**Quan sát + record:**
1. **Phase 0 PRE-GATE:** Có chạy `ci-detect.sh` + `ci-freshness-check.sh` + `ci-inject-context.sh`? (Search log có chuỗi "CI PRE-GATE" / "ci-detect")
2. **Phase 1 Lane Dispatch:** Sinh được `lanes/QD*/signals.json` chưa? Bao nhiêu lanes?
3. **Bước 2 Triage:** Spawn wf-fix-triage có nhận CI context? (Đọc bug-triage.md xem có reference GitNexus query / Serena find_*)
4. **Output files:** Verify tồn tại trong `$SESSION_DIR`:
   - `fix-status.json` — phase states
   - `issue-registry.json` — issues phát hiện
   - `bug-triage.md` — triage classification
   - `fix-plan.md` — fix recommendations
   - Lane reports `lanes/QD*/lane-report.md`

**PASS criteria (AC5, AC6):**
- AC5: ≥1 lane sinh signals.json
- AC6: bug-triage.md có ÍT NHẤT 1 reference đến tool CI (grep "gitnexus\|serena\|impact()\|find_symbol\|find_references\|query()" bug-triage.md)
- Dry-run không modify file ngoài `$SESSION_DIR`

**Cleanup sau test:** KHÔNG xóa SESSION_DIR (giữ làm evidence cho report).

---

### Stage 7 — Issue Logging + Fix-Back to MCV3

Cho mỗi finding từ Stage 1-6, ghi vào test report theo format:

```markdown
## Issue {N}: {tóm tắt 1 dòng}

- **Severity:** CRITICAL | HIGH | MEDIUM | LOW
- **Stage:** {stage số}
- **Tiêu chí FAIL:** {AC số nếu liên quan}
- **Loại:** BUG-SKILL | BUG-SCRIPT | BUG-PROCEDURE | BUG-CONTRACT | BUG-MCP | BUG-DATA
- **File ở EUREKA:** {path tương đối}
- **MCV3 source path:** {path tương ứng trong MCV3 — nếu BUG-SKILL/SCRIPT/PROCEDURE/CONTRACT}
- **Root cause:** {phân tích ngắn gọn}
- **Reproduction:** {bash command/steps để reproduce}
- **Fix proposed:** {patch description hoặc diff snippet}
- **Verification command:** {bash để verify sau fix}
```

**Routing fix table:**

| Loại | Fix tại | Sync lại EUREKA |
|------|---------|-----------------|
| BUG-SKILL (`SKILL.md`, `_contract.json`) | `D:/Working/MCV3/.claude/skills/workflow/wf-fix-bugs/` | `bash D:/Working/MCV3/scripts/sync-claude-to-eureka.sh` |
| BUG-SCRIPT (`ci-*.sh`, `wf-fix-*.sh`) | `D:/Working/MCV3/.claude/scripts/` | sync (như trên) |
| BUG-PROCEDURE (`procedures/*.md`) | `D:/Working/MCV3/.claude/skills/workflow/wf-fix-bugs/procedures/` | sync |
| BUG-CONTRACT (Protocol 20) | `D:/Working/MCV3/.claude/skills/protocols/20-code-intelligence.md` | sync |
| BUG-MCP (gitnexus/serena server) | KHÔNG fix MCV3, escalate cho user | — |
| BUG-DATA (cache stale, lock zombie) | Fix tại EUREKA `.mc-data/work/_meta/` | — |

**Quy tắc fix:**

1. **Đọc CLAUDE.md MCV3** + rule `00-core.md` (Safe-Write Protocol) trước khi sửa
2. **Một fix = một commit** ở MCV3 (`hanoibanhcuon` user) với message:
   `fix(wf-fix-bugs): {tóm tắt} (E2E EUREKA-2026)`
3. Sau MỖI fix:
   - Chạy `bash D:/Working/MCV3/scripts/sync-claude-to-eureka.sh --dry-run` để xem sẽ overwrite gì
   - Nếu OK → chạy không có `--dry-run`
   - Re-run stage liên quan → verify fix passed
4. Sau khi tất cả fixes apply xong:
   - Re-run TOÀN BỘ Stage 1-6 lần 2 → confirm zero regression
   - Update test report cuối: `Final result: PASS / NEEDS_MORE_WORK`

**KHÔNG fix khi:**
- Bug nằm trong app code EUREKA-2026 (không thuộc skill design)
- Bug là MCP server bug (gitnexus/serena binary)
- Bug là missing data của EUREKA (stale index, missing serena onboarding)
- User chưa xác nhận khi fix là `BREAKING_CHANGE`

---

## Output cuối cùng

Trước khi kết thúc, in ra TÓM TẮT đúng format này:

```
═══════════════════════════════════════════════
E2E TEST RESULT: /wf-fix-bugs v7.4.0 on EUREKA-2026
═══════════════════════════════════════════════

| Stage | Name                          | Status | Issues |
|-------|-------------------------------|--------|--------|
| 1     | Environment Sanity            | PASS   | 0      |
| 2     | Lock + CI Detect              | ?      | ?      |
| 3     | MCP Detection                 | ?      | ?      |
| 4     | Freshness + Context Injection | ?      | ?      |
| 5     | --status smoke                | ?      | ?      |
| 6     | --dry-run module              | ?      | ?      |
| 7     | Fix-back routing              | ?      | ?      |

Acceptance Criteria:
  AC1: ?  AC2: ?  AC3: ?  AC4: ?
  AC5: ?  AC6: ?  AC7: ?  AC8: ?

Total findings: N (CRITICAL: x, HIGH: x, MEDIUM: x, LOW: x)
MCV3 files modified: <list paths>
Sync executed: YES/NO
Final verdict: PRODUCTION-READY | NEEDS-FIX | BLOCKED

Test report: <path tới .md file>
Evidence session: <path tới SESSION_DIR>
═══════════════════════════════════════════════
```

Bắt đầu ngay bằng TodoWrite + Stage 1.

===END PROMPT===
```

---

## Ghi chú vận hành

- **Thời lượng dự kiến:** 30-60 phút (Stage 5+6 chiếm chính do dry-run multi-lane)
- **Risk:** Stage 6 dry-run vẫn tạo `$SESSION_DIR` mới trong `.mc-data/work/wf-fix-bugs/sessions/` — không production data nên an toàn
- **Nếu test fail giữa chừng:** Test report đã được append liên tục, anh có thể đọc partial result; resume bằng cách paste lại đoạn từ stage tiếp theo
- **Sync command đã verify:** Preserves `.mc-data/`, `settings.json`, `.mcignore` — fixes ở MCV3 không xoá cache CI hay session đang chạy của EUREKA
- **Sau khi xong:** Nếu có MCV3 files modified, anh review diff trước khi commit — tránh accidental scope creep

## File này

- **Path:** `D:/Working/MCV3/docs/e2e-test-wf-fix-bugs-prompt.md`
- **Maintainer:** Sửa khi skill `wf-fix-bugs` lên version mới (kiểm AC1-AC8 còn đúng không)
- **Re-run:** Có thể dùng lại nhiều lần — mỗi lần sinh test report mới với timestamp riêng
