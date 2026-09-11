# 09 — Design Decisions (Locked v1.0)

> **Đọc trước:** [08-user-scenarios-solutions.md](08-user-scenarios-solutions.md)
> **Trạng thái:** LOCKED — các quyết định dưới đây đã được chốt với owner (Eureka — ERK Transport). Mọi thay đổi phải viết ADR mới trong [07-tradeoffs-adr.md](07-tradeoffs-adr.md).
> **Ngày chốt:** 2026-04-20
> **Lý do có file này:** Các tài liệu 01-08 đưa ra nhiều alternatives + open questions. File này **đóng** chúng theo ưu tiên của người dùng, để Giai đoạn B (Skeleton Implementation) có một nguồn chân lý duy nhất.

---

## 1. Nguyên Tắc Ưu Tiên Cốt Lõi (The North Star)

Mọi quyết định dưới đây đều bắt nguồn từ nguyên tắc do owner phát biểu:

> **"Người dùng quan tâm nhất tới việc đảm bảo không có lỗi logic, nghiệp vụ, và các tính năng trên giao diện phải đảm bảo hoạt động 100%. Các vấn đề khác chọn giải pháp tốt nhưng không làm cồng kềnh thiết kế."**

Dịch thành design language:

| Ưu tiên user | Dimension bị ảnh hưởng | Mức độ |
|--------------|------------------------|--------|
| Không lỗi **logic** | **QD1 Functional** | CORE — bắt buộc chạy mặc định |
| Không lỗi **nghiệp vụ** | **QD2 Business** | CORE — bắt buộc chạy mặc định |
| **UI hoạt động 100%** | **QD5 UX/A11y** | CORE — bắt buộc chạy mặc định |
| Dữ liệu đúng (trực tiếp liên quan nghiệp vụ) | **QD6 Data Integrity** | HIGH — recommend mạnh |
| An toàn (nếu có auth/secret touch) | **QD3 Security** | MED — recommend theo ngữ cảnh |
| Hiệu năng | **QD4 Performance** | LOW — opt-in |
| Tương thích browser/mobile | **QD7 Compatibility** | LOW — opt-in |

**Hệ quả trực tiếp:** default profile `standard` chuyển từ `[QD1, QD3, QD5]` (bản draft) sang **`[QD1, QD2, QD5]`** + khuyến nghị QD6 khi có dấu hiệu domain-sensitive.

---

## 2. Priority-Driven Simplification Rules

Khi gặp xung đột giữa *correctness* và *simplicity*, áp dụng theo thứ tự:

1. **Correctness wins** (CORE-023) — không giảm chất lượng kiểm tra logic/nghiệp vụ/UI để gọn thiết kế.
2. **Simplify non-core features** — cache, multi-session, concurrency tuning không phải core correctness → chọn default đơn giản, opt-in mở rộng.
3. **Default must be safe** — khi user chạy `/wf-fix-bugs` không flag, kết quả phải đảm bảo 3 chiều core.
4. **Defer complexity** — các tính năng không thiết yếu cho v6.0 dồn sang v6.1 (cache git-share, incremental auto-detect).

---

## 3. Quyết Định Cho Q14-Q23

Bảng dưới đây chốt **10 câu hỏi mở** trong [08 §13](08-user-scenarios-solutions.md).

### Q14 — Interactive Selection Gate (ISG): mặc định mở?

**Quyết định: YES — mở khi user không truyền flag dim/profile.**

- Rationale: user không chuyên cần guidance; power user có `--no-interactive` hoặc truyền `--dims=...` để bypass.
- Simplify: ISG là **single-screen** (không phải wizard nhiều bước). Chỉ 7 dòng checkbox + 4-6 dòng giải thích recommend + 1 dòng hotkey.
- Không show ISG khi: có bất kỳ flag dim-related (`--dims`, `--only`, `--skip`, `--auto`), khi `--resume`, khi `--workload`.

### Q15 — Workload Gate: ngưỡng trigger?

**Quyết định: 1.5× profile budget — GIỮ NGUYÊN, nhưng không prompt nếu W < 0.8× budget.**

- Dead-zone không prompt: `W < 0.8 × budget` → chạy thẳng, không hỏi.
- Soft zone: `0.8× ≤ W < 1.5×` → chỉ WARNING 1 dòng "ước tính X phút, trong budget Y", không gate.
- Hard zone: `W ≥ 1.5×` → Workload Gate mở.
- Rationale: tránh hỏi user liên tục; chỉ hỏi khi thực sự cần quyết định.

### Q16 — Partition Strategy Default?

**Quyết định: Sub-menu (theo module structure) — là default duy nhất được recommend.**

- Sub-menu phù hợp mental model của user (họ nghĩ về product theo menu).
- Plan B (chia theo dim) và Plan C (downgrade profile) vẫn hiển thị nhưng không đánh dấu recommend.
- Simplification: không thêm Plan D "custom split" trong v6.0 — thêm trong v6.1 nếu có nhu cầu.

### Q17 — Scan Cache: opt-in hay default on?

**Quyết định: v6.0 opt-in (`--use-cache`); v6.1 default on sau khi validated.**

- Rationale: cache tốt cho tốc độ nhưng không phải core correctness. Phải validate cache hit không miss bug mới bật default.
- v6.0 hành vi: không cache trừ khi user truyền `--use-cache`. Khi dùng, session cache vẫn ghi để resume trong phiên (L3 checkpoint), nhưng project cache không ghi.
- v6.1 (sau 1 release cycle): default on, user có thể `--no-cache` để bypass.

### Q18 — Cache commit vào git: default on?

**Quyết định: NO — user opt-in + require lead dev approval.**

- Rationale: cache files dễ làm repo phình; một số org có policy không commit auto-generated artifacts.
- CLI: `--commit-cache` để commit từng run; `.mc-data/cache/wf-fix-bugs/.git-opt-in` là file flag — nếu có thì commit auto, không có thì chỉ session cache.
- Simplification: không tạo merge driver custom cho cache — rely on content-addressable (2 dev cùng fingerprint = nội dung identical = merge no-op).

### Q19 — Verification Ripple Depth default?

**Quyết định: depth=1 + strength threshold=0.5 (thấp hơn draft 0.7).**

- Rationale: ưu tiên "sửa chỗ này không vỡ chỗ khác" là core priority của user → cần verify rộng hơn.
- depth=1: đủ bắt đa số impact trực tiếp (FK, import chính, event subscriber).
- threshold=0.5 thay vì 0.7: bao phủ cả quan hệ "medium strength" (entity reference, shared utility) — tránh miss cross-module regression.
- Flag `--ripple-depth=2` vẫn có cho trường hợp audit kỹ; `--no-ripple` cho debug.

### Q20 — Incremental `--since` default?

**Quyết định: Không auto-enable incremental mode. User phải truyền `--since=<ref>` explicit.**

- Rationale: incremental là optimization — correctness-first nghĩa là mặc định scan full scope.
- Khi user truyền `--since` mà không có giá trị: fallback `--since=last-session` (session wf-fix-bugs thành công gần nhất), nếu chưa có session nào thì error "cần git ref explicit".
- v6.1 có thể bật auto khi cache cộng với git ref từ session trước; v6.0 không.

### Q21 — Multi-Session Max Concurrent?

**Quyết định: Không cap số lượng session — dùng file-lock trên chunk để tránh collision.**

- Rationale: cap cứng không cần thiết nếu chunk assignment atomic.
- Khuyến nghị trong docs: "≤3 cùng máy, không giới hạn khác máy" — chỉ là guideline, không enforce.
- File-lock `workload.lock` dùng `flock(LOCK_EX | LOCK_NB)` — nếu không lấy được lock trong 5s → pick chunk khác.

### Q22 — Cache TTL default?

**Quyết định: 14 ngày — GIỮ NGUYÊN.**

- Rationale: phù hợp 1 sprint cycle của most teams.
- Override: `--cache-ttl=<days>` per-run, hoặc `.mc-data/cache/wf-fix-bugs/config.json` `"ttl_days": N`.
- Cache expire → auto-delete ở start của session tiếp theo (không ở background).

### Q23 — Secrets/PII có cache không?

**Quyết định: KHÔNG — strict. Tất cả probe trong QD3 Security có `cache_policy: skip`.**

- Rationale: secrets fingerprint leak vào cache file = rủi ro bảo mật nghiêm trọng.
- Mọi probe `dimension.probes[].cache_policy: skip` → bỏ qua cache hoàn toàn, luôn rescan.
- QD3 probes default `skip`. Lane owner có thể mark cache policy per-probe.
- Signal có chứa `evidence.secret_snippet` → KHÔNG bao giờ ghi vào project cache (kể cả non-QD3 probe).

---

## 4. Default Profile Changes (★ Quan Trọng)

Bảng cũ trong [05 §2](05-execution-profiles.md):

| Profile | Dim default (cũ) | Dim default (MỚI — locked) |
|---------|------------------|----------------------------|
| `quick` | QD1, QD3 | **QD1, QD5** |
| `standard` | QD1, QD3, QD5 | **QD1, QD2, QD5** |
| `deep` | QD1-6 | **QD1, QD2, QD5, QD6, QD3** (5 dim, thêm QD4 nếu `--responsive`/`--deep` + perf flag) |
| `exhaustive` | QD1-7 | **QD1-7 (không đổi)** |

**Giải thích:**
- `quick` shift QD3 → QD5: smoke check ưu tiên "UI còn chạy không" hơn "có secret rò rỉ không" (QD3 cần nhiều thời gian + CDG) — QD3 dời sang `standard`+.
- `standard` shift QD3 → QD2: ưu tiên business correctness.
- `deep` đưa QD6 lên cùng QD1+QD2+QD5, QD3 giữ. QD4 không trong deep default vì perf không phải core priority của user.
- `exhaustive` không đổi (toàn bộ 7 dim).

---

## 5. Recommendation Engine — Heuristics Cập Nhật

[08 §3.2 ISG recommend] điều chỉnh theo priority mới:

```
Mặc định tick: QD1 + QD2 + QD5  (core correctness)

Thêm recommend (🟢) khi:
  - Module metadata = finance|accounting|healthcare|banking|logistics
      → tick QD6 (data integrity)
  - Git diff 7 ngày touch auth|crypto|secret|token
      → tick QD3 (security)

Gợi ý (🟡) khi:
  - Git diff touch DB migration|schema
      → QD6
  - Branch name chứa 'perf' hoặc sprint tag 'performance'
      → QD4
  - File mobile/responsive thay đổi
      → QD7

Không tick tự động (⚪):
  - QD4, QD7 mặc định để user chủ động nếu cần
```

**Lý do:** user ưu tiên correctness → recommend nghiêng nhiều hơn về QD liên quan logic/business/UI thay vì performance/compat.

---

## 6. Simplification Scope — Những Gì Được Giữ Gọn

Theo chỉ thị "không làm cồng kềnh", các thành phần sau được **giữ tối giản** trong v6.0:

| Component | Simplification |
|-----------|----------------|
| **ISG** | Single-screen checkbox, không có wizard multi-step, không có advanced settings modal |
| **Workload Gate** | Chỉ show khi W ≥ 1.5× budget; 3 plan A/B/C — không Plan D custom |
| **Scan Cache** | v6.0 opt-in; không có cache manager UI; invalidation đơn giản (hash-based, không dependency graph cache) |
| **Incremental** | User truyền explicit `--since=<ref>`; không auto-detect |
| **Concurrency Controller** | Default caps hardcoded (12/4/6), không expose flag trừ `--max-parallel-lanes` |
| **Git cache sharing** | Opt-in qua flag file `.git-opt-in`; không custom merge driver |
| **Budget alert** | 3 mức (70%/90%/100%) — không thêm intermediate |
| **Audit trail** | `fix-history.md` append-only đủ dùng; không build audit viewer/query tool |

**Những gì KHÔNG được simplify (vì liên quan correctness):**

| Component | Giữ nguyên độ chi tiết |
|-----------|------------------------|
| **4-Level Checkpoint** | Đầy đủ 4 cấp — crash = mất ≤1 feature. Thiết yếu cho long-running ERP job. |
| **Impact Graph + Ripple** | Giữ đầy đủ; threshold=0.5 thay vì 0.7 để verify rộng hơn |
| **Signal Bus dedup** | Giữ đầy đủ; dedup chính xác quan trọng để không báo trùng/miss |
| **QD1/QD2/QD5 probes** | Không cắt probe; phải đủ để phát hiện đầy đủ logic/business/UI bugs |
| **CDG integration** | Giữ nguyên 7 CDG points |
| **POST-GATE T1-T4** | Giữ nguyên — bắt buộc bởi CORE-012 |

---

## 7. v6.0 vs v6.1 Scope

Để v6.0 ship được nhanh + vẫn đủ correctness, các feature non-core dồn sang v6.1:

| Feature | v6.0 | v6.1 |
|---------|------|------|
| Core 7 dimensions lanes | ✅ | ✅ |
| ISG (interactive selection) | ✅ simple | ✅ enhanced |
| Workload Gate + chunks | ✅ | ✅ |
| 4-Level checkpoint | ✅ | ✅ |
| Concurrency controller | ✅ | ✅ |
| Impact Graph + Ripple | ✅ | ✅ |
| Scan Cache — session level | ✅ | ✅ |
| Scan Cache — project level | ⚠️ opt-in via `--use-cache` | ✅ default on |
| Cache git-sharing | ⚠️ opt-in via flag file | ✅ streamlined |
| Incremental `--since` | ⚠️ manual only | ✅ auto-suggest |
| Custom partition plans | ❌ (A/B/C only) | ⚠️ optional Plan D |
| Cache manager CLI | ❌ | ⚠️ if needed |

---

## 8. Safety Defaults — Bất Di Bất Dịch

Dù simplify, các default sau KHÔNG được đổi:

1. **selected_dims phải ≥ QD1+QD2+QD5** khi chạy `standard` hoặc cao hơn — nếu user `--skip` cả 3 → ERROR ("cannot skip all core correctness dims; use `--dims` explicit nếu thật sự muốn").
2. **Verification Ripple luôn ON** (depth≥1) — không có default tắt ripple. User phải truyền `--no-ripple` để tắt.
3. **CDG luôn enforce** — không flag bypass.
4. **POST-GATE T1-T4** luôn chạy — không skip được.
5. **QD3 Security probes không cache** — mandatory.
6. **SAFE-UPDATE impl_status** — Fixer không được downgrade done.

---

## 9. Open Questions Đã Được Close

Ngoài Q14-Q23, các OQ từ [07 §14](07-tradeoffs-adr.md) cũng được chốt:

| OQ gốc | Quyết định |
|--------|------------|
| OQ-A: Gộp QD1+QD2? | KHÔNG — giữ tách vì QD2 cần domain expert agent khác QD1 |
| OQ-B: Signal Bus skill hay utility? | Utility (đã close trong ADR-02) |
| OQ-C: `exhaustive` có bắt buộc đủ 7 dim? | Có — định nghĩa hardcoded |
| OQ-D: Migration 2 release hay 1? | 2 release (v6.0 + v6.1), đã có trong 06 |
| OQ-E: Golden fixture location | `.claude/skills/workflow/wf-fix-<dim>/evals/golden/` |
| OQ-F: LLM semantic dedup cho Signal Bus | DEFER sang v6.1 — v6.0 dùng hash-based dedup |

---

## 10. ADR Sẽ Được Thêm Vào 07

Các quyết định trên sinh ra ADR-14 → ADR-20 (theo sequence trong 08 §11) + ADR-21, ADR-22 mới:

| ADR | Chủ đề |
|-----|--------|
| ADR-14 | Interactive Selection Gate (single-screen, recommend-driven) |
| ADR-15 | Workload Gate + Partition Planner (sub-menu default) |
| ADR-16 | 4-Level Checkpoint Hierarchy (never-lose-more-than-1) |
| ADR-17 | 3-Tier Concurrency Controller (12/4/6 hardcoded) |
| ADR-18 | Impact Graph + Verification Ripple (depth=1, threshold=0.5) |
| ADR-19 | Scan Cache (content-addressable, v6.0 opt-in) |
| ADR-20 | Incremental Mode (explicit `--since`, no auto-detect v6.0) |
| **ADR-21** (mới) | Default Profile Dim Shift — QD1+QD2+QD5 cho standard |
| **ADR-22** (mới) | Safety Defaults — không skip QD1+QD2+QD5; Ripple luôn on; QD3 no-cache |

---

## 11. Impact lên Giai Đoạn A (Design Closure)

Sau khi lock các quyết định, Giai đoạn A rút gọn còn:

1. **A1** — Update 01-08 để reflect các quyết định (đặc biệt 05 default profile + 08 §13 answers). (Done phần lớn trong session này.)
2. **A2** — Viết ADR-14 → ADR-22 vào 07.
3. **A3** — Patch `.claude/rules/00-core.md §4b` với path mới:
   - `.mc-data/work/wf-fix-bugs/workloads/<workload-id>/fix-workload.json`
   - `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json` (project cache, opt-in)
   - `$SESSION_DIR/impact-graph.json`
4. **A4** — Owner sign-off.

Bỏ **A2 (resolve OQ)** vì đã close trong file này; bỏ **A4 (update 01-07 toàn diện)** vì chỉ cần minimal update.

Deliverable Giai đoạn A: **Design v1.0 locked** — rút xuống **1 tuần** (từ 1-2 tuần).

---

## 12. Checklist Trước Khi Bắt Đầu Giai Đoạn B

- [x] Priority owner xác nhận (logic + nghiệp vụ + UI hoạt động 100%)
- [x] Default profile shift sang QD1+QD2+QD5 cho `standard`
- [x] 10 câu hỏi Q14-Q23 có answer
- [x] 6 OQ từ 07 đã close
- [x] Simplification scope rõ (section 6)
- [x] v6.0 vs v6.1 phân định (section 7)
- [x] Safety defaults bất di bất dịch (section 8)
- [ ] ADR-14 → ADR-22 viết vào 07 (Giai đoạn A2)
- [ ] Path contract patch vào `00-core.md §4b` (Giai đoạn A3)
- [ ] Owner sign-off final (Giai đoạn A4)

---

## 13. Liên kết

- [README.md](README.md) — Overview
- [05-execution-profiles.md](05-execution-profiles.md) — Sẽ được update: default profile dims
- [07-tradeoffs-adr.md](07-tradeoffs-adr.md) — Sẽ được update: ADR-14 → ADR-22
- [08-user-scenarios-solutions.md](08-user-scenarios-solutions.md) — Sẽ được update: §13 với answers
- `.claude/rules/00-core.md` — Sẽ được update: §4b path contract bổ sung
