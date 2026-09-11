# 03 — Quyết Định Cần Xác Nhận

> **Phiên bản:** v0.1 — 2026-04-29
> **Mục đích:** 6 quyết định cần user chốt trước khi bắt đầu triển khai
> **Nguyên tắc:** "Độ chính xác trên hết" — mọi quyết định ưu tiên correctness > speed > token

---

## D1 — index.json → sessions.jsonl: Migration Strategy

### Câu hỏi

Có nên **thay thế** index.json bằng sessions.jsonl ngay trong v3.0, hay **dual-write** (cả 2)?

### Bối cảnh

- index.json là full JSON object → concurrent-unsafe (2 dev ghi cùng lúc → corruption)
- sessions.jsonl là append-only → atomic, git-friendly, concurrent-safe
- wf-fix-bugs v7.1 dùng JSONL làm primary + giữ `run-status.json` cho legacy compat
- wf-manage-change là **skill mới** → chưa có user thực tế → KHÔNG có backward-compat concern

### Đề xuất: **Dual-write ngay v3.0, index.json secondary**

| Phương án | Lợi | Hại |
|-----------|-----|-----|
| **A: Dual-write (đề xuất)** | sessions.jsonl = primary (concurrent-safe), index.json = `--status` display (human-readable) | 2 files phải sync |
| B: Chỉ sessions.jsonl | Đơn giản | `--status` phải grep JSONL → ít human-friendly |
| C: Chỉ index.json + file lock | Đơn giản | File lock không giải quyết git merge conflict |

### Chốt

**Phương án A: Dual-write.** sessions.jsonl cho session lookup + atomic append, index.json cho `--status` display. Cả 2 được update cùng lúc.

---

## D2 — Lock Mechanism: Session + Registry

### Câu hỏi

Lock ở level nào? Chỉ session lock, hay cả registry lock?

### Bối cảnh

- wf-fix-bugs: **chỉ session lock** (không ghi registry — delegate cho sub-skills)
- wf-implement-feature: **chỉ feature lock** (không cross-feature registry lock)
- wf-manage-change: **GHI registry trực tiếp** ở Phase 4a.5 (requirements, features, impl_status) → CẦN registry lock

### Đề xuất: **Cả 2 locks**

```
Session lock:  .mc-data/work/wf-manage-change/$CHANGE_ID/.session.lock
Registry lock: .mc-data/work/wf-manage-change/.locks/registry.lock
```

**Session lock:** acquire khi bắt đầu session (Phase 0), release khi complete/error.
**Registry lock:** acquire trước khi modify registry (Phase 4a.5, 4b.6), release ngay sau write.

### Lý do

- 2 developer có thể chạy 2 changes đồng thời (2 session locks riêng) → OK nếu KHÔNG chạm registry cùng lúc
- Nếu cùng chạm registry → registry lock serialize → 1 người chờ người kia xong → an toàn
- Registry lock chỉ hold trong thời gian ngắn (< 30 giây) → không block lâu

### Chốt

**Cả 2 locks.** Session lock cho lifecycle, registry lock cho critical write section.

---

## D3 — change-impact.json: Scope & Consumer Skills

### Câu hỏi

change-impact.json nên có bao nhiêu consumer skills? Opt-in hay auto-load?

### Bối cảnh

wf-fix-bugs v7.1 fix-impact.json có 3 consumers:
- `/wf-verify-sync` — qua flag `--from-fix-bugs`
- `/wf-prepare-deployment` — qua flag `--from-fix-bugs`
- `/wf-implement-feature` — Phase 0 context priming

### Đề xuất: **3 consumers, opt-in flag**

| Consumer | Flag | Khi nào dùng |
|----------|------|-------------|
| `/wf-verify-sync` | `--from-manage-change[=<id>]` | Khi muốn cross-check registry changes từ change session |
| `/wf-preflight` | (inform — scope affected files) | Khi muốn focus preflight vào files vừa change |
| `/wf-implement-feature` | (Phase 0 context priming) | Khi implement feature liên quan đến files vừa change |

**KHÔNG thêm `/wf-prepare-deployment`** vì change-manage không phải là release gate — chỉ là thay đổi feature. Deployment readiness nên verify qua preflight + verify-sync bình thường.

### Chốt

**3 consumers, opt-in.** Flag `--from-manage-change` chỉ cho wf-verify-sync. wf-preflight và wf-implement-feature consume optional context.

---

## D4 — Template phase-summary.md: Minimal hay Full?

### Câu hỏi

phase-summary.md nên có template minimal (chỉ headings + placeholders) hay full (đầy đủ nội dung mẫu)?

### Bối cảnh

- CORE-031 bắt buộc READ→POPULATE→WRITE cho mọi output file
- phase-summary.md hiện tại là "free-form" (template=null) → CORE-031 violation
- wf-fix-bugs cũng free-form → cũng violation
- Nội dung phase-summary.md là **tóm tắt tiếng Việt cho non-specialist** → cần linh hoạt

### Đề xuất: **Minimal template (chỉ headings + placeholder instructions)**

```markdown
# Tom tat thay doi — {CHANGE_ID}

## Da thay doi gi?
<!-- POPULATE: Mo ta cu the nhung gi da thay doi -->

## Tai sao can thay doi?
<!-- POPULATE: Copy tu user prompt -->

## Ket qua kiem tra
<!-- POPULATE: Tu phase5 verify results -->

## Nhung file bi anh huong
<!-- POPULATE: Tu metrics -->

## Buoc tiep theo
<!-- POPULATE: Tu Phase 6 Next Step Recommendation -->
```

**Lợi:**
- Tuân thủ CORE-031 (có template để READ)
- Giữ flexibility (POPULATE nội dung tự do)
- AI biết chính xác sections cần điền

### Chốt

**Minimal template.** Headings + HTML comments hướng dẫn population.

---

## D5 — Session ID Format: Giữ nguyên hay đổi?

### Câu hỏi

Session ID format `CHG-YYYYMMDD-NNN` có cần đổi không?

### Bối cảnh

- wf-fix-bugs v7.1: `YYYY-MM-DD-{scope}-{slug}-{NN}` (human-readable, có scope)
- wf-implement-feature v4.0: `{YYYY-MM-DD}-{HHMMSS}-{shorthost}` (timestamp-based, collision-safe)
- wf-scan-target v2: `YYYY-MM-DD-HHMMSS` (timestamp-based)
- wf-manage-change hiện tại: `CHG-YYYYMMDD-NNN` (prefix + date + counter)

### Phân tích

**Giữ nguyên `CHG-YYYYMMDD-NNN`** vì:
1. Đã có anti-collision check (GAP-1 fix)
2. Đã có retry loop trong mc-generate-session-id.sh (G9 fix)
3. Dễ recognize (prefix `CHG-` → ngay biết là manage-change)
4. Skill mới → chưa có sessions cũ → không cần migrate
5. Format khác với wf-fix-bugs → tránh confusion giữa 2 skills

**KHÔNG đổi sang scope-slug format** vì:
- wf-manage-change thường chạy 1-2 lần/ngày → counter NNN đủ discriminate
- Scope là optional (`--scope=all` default) → không luôn có scope để slugify

### Chốt

**Giữ nguyên `CHG-YYYYMMDD-NNN`.** Bổ sung retry loop + sleep trong script.

---

## D6 — Bash Scripts Placement

### Câu hỏi

Bash scripts đặt ở đâu? Mix với scripts của skills khác hay riêng folder?

### Bối cảnh

- wf-fix-bugs: `.claude/scripts/wf-fix-*.sh` (flat, prefix naming) — 16 scripts
- wf-implement-feature: `.claude/scripts/wf-implement-feature/*.sh` (subfolder) — 10 scripts
- wf-legacy-scan: `.claude/scripts/legacy-scan-*.sh` (flat, prefix naming) — 24 scripts

### Phân tích

**Subfolder `.claude/scripts/wf-manage-change/`** vì:
1. Đúng pattern wf-implement-feature v4.0 (best practice mới)
2. 10 scripts → đủ nhiều cho subfolder riêng
3. Prefix `mc-` (manage-change) → ngắn gọn, không trùng
4. Dễ ls/grep tất cả scripts của skill

**KHÔNG dùng flat naming `wf-manage-change-*.sh`** vì:
- Tên quá dài: `wf-manage-change-acquire-lock.sh` (31 chars)
- 10 files dài tên trong folder có 50+ scripts khác → khó scan

### Chốt

**Subfolder `.claude/scripts/wf-manage-change/` với prefix `mc-`.** Đúng pattern wf-implement-feature v4.0.

---

## Summary

| ID | Decision | Chốt |
|----|----------|------|
| D1 | index.json migration | **Dual-write** (sessions.jsonl primary + index.json display) |
| D2 | Lock mechanism | **Cả 2** (session lock + registry lock) |
| D3 | change-impact.json scope | **3 consumers, opt-in** (verify-sync, preflight, implement-feature) |
| D4 | phase-summary.md template | **Minimal template** (headings + placeholder instructions) |
| D5 | Session ID format | **Giữ nguyên** `CHG-YYYYMMDD-NNN` |
| D6 | Bash scripts placement | **Subfolder** `.claude/scripts/wf-manage-change/` với prefix `mc-` |
