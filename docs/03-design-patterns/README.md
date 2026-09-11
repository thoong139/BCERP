# 03 — Design Patterns

> **Mức độ ràng buộc:** Tham khảo (overview) + **mỗi pattern là KHUYẾN NGHỊ mạnh** khi áp dụng đúng tình huống
> **Mục đích:** 11 patterns đã được chứng minh trong MCV3 — kèm case study từ skills thực tế (`wf-fix-bugs`, `wf-legacy-scan`, `wf-e2e-*`)

---

## 1. Patterns là gì?

**Pattern** = công thức tái sử dụng cho một vấn đề thiết kế phổ biến. Khác với:
- **Rule** (constraint cứng — phải tuân thủ)
- **Standard** (cấu trúc artifact bắt buộc)
- **Protocol** (quy ước dùng chung)

Pattern là **lựa chọn thiết kế** — nếu tình huống phù hợp, áp dụng pattern để không tự phát minh lại.

---

## 2. 11 Patterns trong MCV3

| # | Pattern | Khi nào dùng | Rule liên quan | Case study |
|---|---------|--------------|----------------|------------|
| [01](01-lazy-load-procedures.md) | Lazy-Load Procedures | Skill có >3 phases | CORE-032 | wf-fix-bugs v10.0, wf-legacy-scan v5.0 |
| [02](02-ci-first-integration.md) | CI-First Integration | Skill cần đọc code | CORE-033 | wf-fix-bugs lane QD1/QD4/QD10, wf-legacy-scan |
| [03](03-cross-skill-artifacts.md) | Cross-Skill Artifacts | Skill output được skill khác consume | CORE-036 | fix-impact.json, change-impact.json |
| [04](04-parallel-lane-dispatch.md) | Parallel Lane Dispatch | Cần phân tích đa-chiều song song | CORE-025 | wf-fix-bugs Phase 4 (11 lanes QD1-QD11) |
| [05](05-agent-prompt-template.md) | Agent Prompt Template (8 sections) | Spawn agent | CORE-037 | Mọi skill spawn agent |
| [06](06-checkpoint-resume.md) | Checkpoint + Resume | Multi-session skill có thể bị interrupt | CORE-038 | wf-fix-bugs, wf-legacy-scan, wf-implement-feature |
| [07](07-playwright-3-modes.md) | Playwright 3 Modes | Skill cần browser testing | — | wf-fix-bugs QD9, wf-e2e-* |
| [08](08-auto-detect-fallback.md) | Auto-Detect + Graceful Fallback | Tool optional, có fallback Grep/Glob | CORE-033 | Protocol 20 (GitNexus/Serena) |
| [09](09-multi-session-locking.md) | Multi-Session R/W Lock | Nhiều sessions/devs cùng access shared resource | — | wf-e2e-* (Protocol 22), CI cache lock |
| [10](10-cdg-gate.md) | CDG Gate (Critical Decision) | User cần quyết định critical | CORE-027 | 13 CDG points qua workflows |
| [11](11-bash-utility-design.md) ★ | Bash vs Python Utility | Quyết định bash hay Python cho helper | — | `_shared/` Python vs `scripts/` bash |

★ = Cải tiến kiến trúc mới (đưa thành chuẩn rõ ràng).

---

## 3. Pattern category map

### 3.1. Architecture patterns (3)

- **01 — Lazy-Load Procedures** — Skill structure
- **05 — Agent Prompt Template** — Agent contract
- **03 — Cross-Skill Artifacts** — Inter-skill communication

### 3.2. Execution patterns (3)

- **04 — Parallel Lane Dispatch** — Concurrency
- **06 — Checkpoint + Resume** — Multi-session
- **02 — CI-First Integration** — Tool integration

### 3.3. Resilience patterns (2)

- **08 — Auto-Detect + Graceful Fallback** — Tool availability
- **09 — Multi-Session R/W Lock** — Concurrent access

### 3.4. User-interaction patterns (1)

- **10 — CDG Gate** — User decision points

### 3.5. Specialized patterns (2)

- **07 — Playwright 3 Modes** — Browser testing
- **11 — Bash vs Python Utility** — Implementation choice

---

## 4. Cấu trúc 1 file pattern

Mỗi file pattern theo cấu trúc chuẩn:

```markdown
# {NN} — {Pattern Name}

> **Mức độ ràng buộc:** Tham khảo / KHUYẾN NGHỊ
> **Rule liên quan:** CORE-XXX
> **Khi nào dùng:** {1-2 câu}

## 1. Vấn đề pattern giải quyết
## 2. Pattern definition (code/schema example)
## 3. Case study từ skill thực tế (wf-fix-bugs, wf-legacy-scan, ...)
## 4. Variations / Edge cases
## 5. Anti-patterns
## 6. Checklist áp dụng
## 7. Liên kết
```

---

## 5. Khi nào áp dụng nhiều patterns cùng lúc

Nhiều skills MCV3 dùng kết hợp 5+ patterns. Ví dụ `wf-fix-bugs` v10.x:

| Pattern | Vai trò trong wf-fix-bugs |
|---------|---------------------------|
| 01 Lazy-Load Procedures | SKILL.md 332 dòng + 9 procedure files |
| 02 CI-First Integration | Phase Init Na/Nb/Nc CI PRE-GATE |
| 03 Cross-Skill Artifacts | `fix-impact.json` produces for 3 skills |
| 04 Parallel Lane Dispatch | Phase 4 spawn 11 lane agents QD1-QD11 |
| 05 Agent Prompt Template | Mọi lane agent + triage agent + execute agent |
| 06 Checkpoint + Resume | `--resume` từ fix-status.json |
| 07 Playwright 3 Modes | QD9 runtime-health 3 modes (none/assisted/full) |
| 08 Auto-Detect + Fallback | CI tools detect + Grep fallback |
| 09 Multi-Session R/W Lock | Session isolation `sessions/{id}/.lock` |
| 10 CDG Gate | CDG-08, 09, 10 trong fix workflow |
| 11 Bash vs Python | `_shared/` Python cho computation, bash cho helper |

**Insight:** Pattern KHÔNG mutually exclusive — chúng compose với nhau.

---

## 6. Anti-patterns chung cho cả nhóm

| ❌ Anti-pattern | ✅ Đúng |
|----------------|---------|
| Áp dụng pattern không phù hợp tình huống | Đọc "Khi nào dùng" trước — pattern không phải bullet list to-do |
| Copy pattern từ skill khác mà không hiểu | Đọc case study + variations |
| Phát minh lại pattern đã có | Check danh sách 11 patterns trước |
| Pattern conflict với rule | Rule > Pattern — vi phạm rule ngay cả khi pattern khuyến nghị |
| Áp dụng 11 patterns blindly cho mọi skill | Chọn theo nhu cầu — skill nhỏ chỉ cần 2-3 patterns |

---

## 7. Liên kết

- **Standards (cấu trúc bắt buộc):** [`../02-standards/`](../02-standards/)
- **Architecture overview:** [`../01-architecture/`](../01-architecture/)
- **Skill design canon:** [`../04-skill-design/`](../04-skill-design/) (W3 sẽ scaffold)
- **Source rules:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §4i-4o (CORE-032..038)
