# 07 — Tradeoffs & Architecture Decision Records

> **Đọc trước:** [06-migration-plan.md](06-migration-plan.md)
> **Quay về index:** [README.md](README.md)

Tài liệu này ghi lại **các quyết định kiến trúc lớn** (ADR), **lý do chọn** phương án này thay vì phương án khác, và **câu hỏi mở** còn lại. Đây là bộ nhớ tổ chức — người implement phase sau đọc để hiểu WHY.

---

## 0. Format

Mỗi ADR có cấu trúc:

```
ADR-NN — Tiêu đề
Status:    accepted | proposed | superseded | deprecated
Context:   Vì sao phải quyết định
Decision:  Quyết định cụ thể
Alternatives: Các phương án đã xem xét
Consequences: Tích cực + tiêu cực
Followups: Hành động kèm theo
```

---

## 1. ADR-01 — Dimension là primary axis thay vì Layer

**Status:** accepted

**Context:**
Pipeline v5.1 chia discovery theo **5 Layer** (L1 Feature Completeness, L2 Feature States, L3 Runtime Symptoms, L4 Cross-Validation, L5 ERP Integration). Layer mix lẫn nhiều loại bug (chức năng, security, a11y, data) vào cùng 1 registry. Sự tăng trưởng lên 12 bug category trong plan v1.1 cho thấy cần axis mới để lane hoá.

**Decision:**
Chia discovery theo **Quality Dimension** — 7 QD orthogonal (Functional, Business, Security, Performance, UX/A11y, Data Integrity, Compatibility). Mỗi dimension tự manage probe + agent + severity riêng.

**Alternatives:**
- **Alt A:** Giữ 5-Layer, thêm sub-category flag → tiếp tục monolith, user chọn thủ công.
- **Alt B:** Chia theo Agent team (business, engineering, testing, ...) → trộn concern.
- **Alt C:** Chia theo Phase workflow (discovery/triage/fix) — v5 đã làm, không đủ.

**Consequences:**
- **+** User chạy 1 dim độc lập (`--only=security`) — khả thi mới.
- **+** Mỗi dim plug-able, dễ test isolate.
- **+** Severity aggregation MAX-across-dim giải quyết vấn đề cross-concern.
- **-** Cần Signal Bus để dedup cross-dim — thêm component.
- **-** Ban đầu phải migrate 12 category → 7 dim, risk lesser granularity (acceptable: doc mapping rõ).

**Followups:**
- Phase 2 build QD1 + QD3 làm bellweather.
- Validate mapping 12 category → 7 dim qua fixture test.

---

## 2. ADR-02 — Signal Bus là utility module, không phải skill

**Status:** accepted

**Context:**
Signal Bus cần dedup + normalize signal từ multiple lane thành Issue. Câu hỏi: có nên build là slash command (`/wf-fix-bus`)?

**Decision:**
Signal Bus là **utility module inline** trong orchestrator, gọi sau khi lane COMPLETE. Không có slash command, không có SKILL.md. Code lives trong `_shared/signal_bus/` như library.

**Alternatives:**
- **Alt A:** Build thành skill riêng — dễ test standalone, có SKILL.md + _contract.json.
- **Alt B:** Inline trong orchestrator SKILL.md — nhanh, ít boilerplate, nhưng khó test.
- **Alt C:** Build thành agent — quá nặng cho task deterministic.

**Decision rationale (chọn Alt B + patch):**
- Signal Bus luôn chạy inline sau lane — không có user story gọi riêng.
- Không cần PRE-GATE user-facing.
- Không sở hữu registry field → role NONE.
- Test standalone vẫn khả thi qua golden fixtures + CLI script riêng.

**Consequences:**
- **+** Ít boilerplate, ít file SKILL.md / _contract.json.
- **+** Không phát sinh slash command rác.
- **-** Khó test độc lập nếu không dựng script helper — cần chuẩn hoá trong Phase 2.
- **-** Người mới đọc codebase có thể miss Signal Bus nếu không có doc tốt.

**Followups:**
- Phase 1: viết `_shared/signal_bus/README.md` chi tiết.
- Phase 2: viết CLI test helper `test-signal-bus.sh` cho dev debug.

---

## 3. ADR-03 — Shared Services (Triage/Planner/Fixer/Verifier) là 4 service độc lập

**Status:** accepted

**Context:**
v5 có `/wf-fix-execute` làm hết fix + docs sync + verify + report trong 1 skill. File SKILL.md này phình to ~1000 dòng. Bug trong 1 phase kéo sập cả skill.

**Decision:**
Chia thành 4 service:
- **Triage** — enrich issue với severity + fixability.
- **Planner** — sort + batch issue.
- **Fixer** — apply patch (auto hoặc agent).
- **Verifier** — re-run probe, capture after-evidence.

Triage giữ là slash command (`/wf-fix-triage`, backward-compat). 3 còn lại là utility gọi inline.

**Alternatives:**
- **Alt A:** 4 slash command riêng — quá rối, user không bao giờ gọi `/wf-fix-planner` lẻ.
- **Alt B:** Giữ 1 skill monolith `/wf-fix-execute` — không giải được vấn đề v5.
- **Alt C:** 4 service, 1 slash command orchestrate (đã chọn).

**Consequences:**
- **+** Mỗi service ≤ 200 dòng logic, dễ debug.
- **+** Retry policy tập trung trong Verifier.
- **+** Fixer safety gate (CORE-020) rõ scope.
- **-** Phải cross-validate path giữa 4 service → tăng số dòng CORE-007.
- **-** Resume routing phức tạp hơn (per-service state).

**Followups:**
- Phase 4: implement Fixer/Verifier với retry 3 lần + ESCALATE.
- Write unit test cho Planner batching logic.

---

## 4. ADR-04 — Issue schema v2 extend chứ không thay thế

**Status:** accepted

**Context:**
v5 `issue-v1` đang được consume bởi nhiều consumer (`wf-fix-execute`, report, docs sync). Breaking schema sẽ làm vỡ session in-flight.

**Decision:**
- `issue-v2` **bọc** v1: mọi field v1 giữ nguyên semantic.
- Field mới (`dimension[]`, `primary_dimension`, `probe_sources[]`, `confidence`, `severity_source`, `regression_signals[]`) là **optional** khi migrate từ v1.
- Migration helper `_shared/signal_bus/migrate-v1-to-v2.sh` chạy 1 lần khi gặp session cũ.

**Alternatives:**
- **Alt A:** Breaking schema — clean slate, nhưng vỡ user session.
- **Alt B:** Duo schema coexist — v5 consumer đọc v1, v6 đọc v2 → phức tạp parser.
- **Alt C:** Extend (đã chọn) — v2 đọc được v1, v1 consumer gặp extra field bỏ qua.

**Consequences:**
- **+** User cảm thấy ít gián đoạn.
- **+** Migration helper là 1 script ngắn.
- **-** Carry field `category` (v1) → `primary_dimension` (v2) phải guard trong code 1 thời gian.
- **-** Một số field v1 không còn ý nghĩa (ví dụ `category`) vẫn phải write để backward-compat → noise.

**Followups:**
- Phase 6: remove v1 carry-over fields.

---

## 5. ADR-05 — Max 3 lane song song mặc định

**Status:** accepted

**Context:**
Trên lý thuyết chạy 7 lane song song sẽ nhanh nhất. Nhưng bị giới hạn bởi:
- Agent concurrency (security-engineer, ux-designer, ... có thể bị queue).
- Playwright browser instance (QD5, QD7 cần browser, chạy nhiều sẽ OOM).
- Debug khó khi 7 stream log trộn lẫn.

**Decision:**
Default `max_parallel_lanes=3`. Cho phép override `--max-parallel-lanes=N` với warning.

**Alternatives:**
- **Alt A:** 7 lane song song — nhanh nhất nhưng risk.
- **Alt B:** Tuần tự 7 lane — quá chậm (45m → 3h+).
- **Alt C:** Dynamic theo machine capacity — overkill cho phase đầu.

**Consequences:**
- **+** Budget predictable.
- **+** Debug log readable.
- **-** `exhaustive` profile chạy ~40-60m thay vì ~25m (nếu song song 7).

**Followups:**
- Phase 5: measure thực tế; có thể bump default lên 4 nếu infra chịu được.
- Add dynamic heuristic ở v6.x (plugin).

---

## 6. ADR-06 — Skill name convention: `wf-fix-<dim-slug>`

**Status:** accepted

**Context:**
Phải đặt tên 7 skill lane sao cho:
- User dễ gõ (`--only=security` hơn là `--only=qd3`).
- Consistent với naming `wf-*` hiện có.
- Không trùng với skill hiện tại.

**Decision:**
- Slug lowercase-kebab-case: `functional`, `business`, `security`, `performance`, `ux`, `data`, `compat`.
- Skill name: `wf-fix-<slug>`.
- Dim ID (QD1-7) vẫn dùng trong schema/log cho sort numeric.

**Alternatives:**
- **Alt A:** `wf-fix-qd<n>` — máy-friendly nhưng human-hostile.
- **Alt B:** Tên dài (`wf-fix-accessibility-ux`) — clear nhưng gõ dài.

**Consequences:**
- **+** User gõ tự nhiên.
- **+** `--only=<slug>` intuitive.
- **-** Phải maintain mapping `slug ↔ QD<n>` trong `dimensions.json`.

**Followups:**
- Phase 1: viết validator đảm bảo slug unique + khớp `dimension_id`.

---

## 7. ADR-07 — Registry role NONE cho tất cả lane + Fixer là SAFE-UPDATE duy nhất

**Status:** accepted

**Context:**
Pipeline fix-bug không nên làm SSOT bị drift. Câu hỏi: lane có được set `impl_status` không khi phát hiện feature bị gãy?

**Decision:**
- **Tất cả lane role NONE** — chỉ đọc registry cross-ref REQ-ID.
- **Signal Bus, Triage, Planner, Verifier role NONE**.
- **Chỉ Fixer có SAFE-UPDATE** trên `impl_status` — và chỉ khi fix thực sự thay đổi behavior feature (không bao giờ downgrade `done`).

**Alternatives:**
- **Alt A:** Lane được set `impl_status` = in_progress khi đang probe → sai: probe không phải implement.
- **Alt B:** Triage được SAFE-UPDATE → trộn concern: triage là phân loại, không fix.
- **Alt C:** Fixer-only SAFE-UPDATE (đã chọn).

**Consequences:**
- **+** Registry contract đơn giản, dễ audit.
- **+** Không race condition multi-lane ghi cùng field.
- **-** Cần rõ ràng định nghĩa "fix thay đổi behavior" — edge case: nếu Fixer chỉ sửa code style thì KHÔNG cần update impl_status.

**Followups:**
- Phase 4: viết rule đánh giá "behavior change" trong Fixer doc.

---

## 8. ADR-08 — Profiles là 4 (không 3, không 5)

**Status:** accepted

**Context:**
Bao nhiêu profile là đủ? Quá ít → user không có granularity. Quá nhiều → confuse.

**Decision:**
4 profile: `quick`, `standard`, `deep`, `exhaustive`. Mỗi cái map rõ ràng đến use case:
- `quick` — pre-commit smoke.
- `standard` — pre-PR (default).
- `deep` — pre-RC.
- `exhaustive` — pre-GA / audit.

**Alternatives:**
- **Alt A:** 3 profile (`quick`, `normal`, `full`) — thiếu "exhaustive" cho compliance.
- **Alt B:** 5+ profile (`smoke`, `quick`, `standard`, `deep`, `exhaustive`, `nightly`) — overkill.
- **Alt C:** 4 profile (đã chọn).

**Consequences:**
- **+** 4 mức hợp với 4 moment trong dev lifecycle.
- **+** Budget đủ rộng: 5m / 15m / 45m / 120m.
- **-** Không native "nightly" — nhưng có thể add sau qua §12 Profile Extension.

**Followups:**
- Monitor usage sau Phase 5 — xem có cần thêm `nightly` không.

---

## 9. ADR-09 — Evidence là bắt buộc cho mọi Signal

**Status:** accepted

**Context:**
v5 nhiều issue không có evidence cụ thể (chỉ `symptom_summary`). Gây khó verify + khó user review.

**Decision:**
Mọi Signal **bắt buộc** có ≥ 1 field `evidence.*` non-empty:
- Static probe: `code_ref` (file:line).
- Runtime probe: `screenshot` hoặc `http_trace` hoặc `log`.
- LLM probe: `code_ref` + reasoning snippet.

Nếu probe không đủ evidence → lane reject probe output + log warning.

**Alternatives:**
- **Alt A:** Evidence optional — như v5, nhưng không đảm bảo verify.
- **Alt B:** Evidence đa field bắt buộc (ví dụ code_ref + screenshot) — overkill cho static.
- **Alt C:** ≥ 1 evidence field (đã chọn).

**Consequences:**
- **+** Verifier có thể re-run probe có deterministic.
- **+** User trust cao hơn khi có "proof".
- **-** Một số heuristic probe khó có evidence — phải dùng reasoning snippet; tăng token cost.

**Followups:**
- Phase 2: checklist evidence cho mỗi probe.

---

## 10. ADR-10 — CORE-028 phase-summary per lane + per orchestrator

**Status:** accepted

**Context:**
CORE-028 yêu cầu mọi skill tạo phase-summary. Nếu 7 lane + orchestrator mỗi cái 1 file → user overload.

**Decision:**
- Mỗi **lane** ghi `$SESSION_DIR/lanes/<dim>/phase-summary.md` (≤15 dòng). Đây là technical summary cho debugging.
- **Orchestrator** ghi `$SESSION_DIR/phase-summary.md` **roll-up** từ lane summaries (≤15 dòng tiếng Việt cho non-specialist).
- User chỉ cần đọc 1 file (root phase-summary).

**Alternatives:**
- **Alt A:** Chỉ 1 summary ở orchestrator — vi phạm CORE-028 cho lane.
- **Alt B:** 7 + 1 = 8 summary — user overload.
- **Alt C:** Lane-level + orchestrator-level (đã chọn, với lane-level technical, root-level human).

**Consequences:**
- **+** Tuân thủ CORE-028 cho cả lane lẫn orchestrator.
- **+** User chỉ đọc 1 file; debugger đọc đủ 8 file.
- **-** Phải maintain 2 template.

**Followups:**
- Phase 1: viết 2 template riêng biệt.

---

## 11. ADR-11 — LEGACY_MODE không đổi dimension selection

**Status:** accepted

**Context:**
LEGACY_MODE (CORE-021) thường có code shape khác. Câu hỏi: có nên auto thêm/bớt dim trong legacy?

**Decision:**
LEGACY_MODE **không** thay đổi profile default hoặc dim selection. Chỉ ảnh hưởng cách từng probe diễn giải kết quả (sử dụng `module-code-mapping.json`, soft rule cho QD2, cross-ref DB schema cho QD6).

**Alternatives:**
- **Alt A:** Legacy auto thêm QD6 Data Integrity — nhưng user standard cũng cần.
- **Alt B:** Legacy downgrade sang profile=standard — gây ngạc nhiên user gọi `--profile=deep`.
- **Alt C:** Không đổi selection, chỉ đổi behavior probe (đã chọn).

**Consequences:**
- **+** User prediction: flag họ gõ = kết quả họ nhận.
- **+** Probe tự adapt theo LEGACY_MODE.
- **-** Mỗi probe phải implement legacy-aware logic — thêm code.

**Followups:**
- Phase 2: probes QD1, QD3 implement legacy adapter trước, làm ref cho dim khác.

---

## 12. ADR-12 — `--explain` là first-class UX feature

**Status:** accepted

**Context:**
Pipeline v6 có 3 trục quyết định (profile × dim × scope). User dễ confuse hoặc bất ngờ khi flag conflict.

**Decision:**
Flag `--explain` preview plan mà **không chạy**:
- In bảng probe per dim, estimated time/tokens.
- Highlight conflict nếu có.
- Confirm budget OK.

Orchestrator **khuyến nghị** `--explain` trong hint khi user gõ `--profile=exhaustive` hoặc `--full-test`.

**Alternatives:**
- **Alt A:** Không có `--explain`, chỉ prompt confirm trước chạy — gắn cứng UX.
- **Alt B:** `--dry-run` bao gồm explain — nhưng `--dry-run` có nghĩa khác (chạy probe, skip fix).
- **Alt C:** `--explain` là flag riêng (đã chọn).

**Consequences:**
- **+** User confident khi chạy profile nặng.
- **+** Giảm surprise budget blow.
- **-** Thêm 1 flag — nhưng worth it.

**Followups:**
- Phase 1: `--explain` output cần đẹp + actionable.

---

## 13. ADR-13 — Auto-detect `--auto` opt-in, không default

**Status:** accepted

**Context:**
`--auto` đọc preflight + git diff → chọn dim. Tưởng tượng user chạy `/wf-fix-bugs` và bất ngờ thấy QD4 Performance chạy dù không cần.

**Decision:**
`--auto` là opt-in flag. Default selection là `profiles.standard.default_dimensions`.

**Alternatives:**
- **Alt A:** Mặc định auto-detect — convenient nhưng unpredictable.
- **Alt B:** Opt-in (đã chọn).

**Consequences:**
- **+** Predictable default.
- **+** Power user có option.
- **-** User non-tech có thể không biết `--auto` tồn tại — cần doc.

**Followups:**
- Phase 5: user research có cần đẩy `--auto` làm default không.

---

## 14. ADR-14 — Interactive Selection Gate (ISG) bật mặc định

**Status:** accepted

**Context:**
Pipeline v6 có 3 trục quyết định (profile × dimension × scope) — user dễ chạy nhầm, hoặc bị bất ngờ với `--profile=exhaustive` rồi blow budget. v5 không có điểm dừng xác nhận lựa chọn; orchestrator cứ thế kick-off.

**Decision:**
Thêm **Interactive Selection Gate (ISG)** là **1 màn hình checkbox duy nhất** ở đầu `/wf-fix-bugs`:
- Hiển thị cả 3 trục cùng 1 lúc: profile, dim, scope, estimated budget (minutes + tokens).
- Default ON (chạy ISG mặc định trừ khi flag bypass).
- Bypass flag `--no-interactive` (ví dụ khi chạy trong CI/CD hoặc scheduled task).
- `--explain` (ADR-12) và ISG là 2 cơ chế bổ trợ: `--explain` preview + quit; ISG preview + cho phép điều chỉnh trước khi chạy.

**Alternatives:**
- **Alt A:** Không có ISG — user phải học 3 flag trục và tự lo budget.
- **Alt B:** Prompt nhiều bước (wizard nhiều màn hình) — chậm, làm power-user bực.
- **Alt C:** 1 màn hình checkbox (đã chọn) — 1 beat dừng, power-user `--no-interactive` bypass được.

**Consequences:**
- **+** User non-tech an tâm: thấy rõ sẽ chạy gì.
- **+** Giảm surprise "chạy nhầm exhaustive 120m".
- **+** Power-user có exit hatch `--no-interactive`.
- **-** Thêm 1 component UI (render checkbox trong terminal).
- **-** Phải maintain template màn hình ISG song song với `--explain`.

**Followups:**
- Phase 1 (Giai đoạn B): skeleton ISG — render table + đọc user input.
- Phase 2: unit test cho ISG parser (checkbox → final plan JSON).
- Doc `_shared/isg/README.md`.

---

## 15. ADR-15 — Workload Gate + Partition Planner với dead-zone

**Status:** accepted

**Context:**
Khi workload ước tính vượt budget profile, 2 thái cực đều tệ:
- Vượt quá xa (>1.5×) → chạy sẽ blow budget → phải cắt.
- Sát budget (0.8×-1.5×) → block user mà nhiều khi vẫn chạy được → gây bực.

Câu hỏi: ngưỡng nào là block? Và khi block thì user chọn gì?

**Decision:**
- **Hard prompt (BLOCK)** khi `workload_estimate > 1.5 × budget`.
- **Dead-zone (KHÔNG prompt)** khi `workload_estimate < 0.8 × budget` — chạy luôn, không làm phiền.
- **Khoảng 0.8×-1.5×:** chạy với cảnh báo nhẹ trong `--explain`, không block.
- Khi BLOCK, **Plan A (sub-menu)** là default:
  - A1: Thu hẹp scope (chọn module/feature cụ thể).
  - A2: Hạ profile (exhaustive → deep, deep → standard, …).
  - A3: Giảm dim list (bỏ dim ít critical).
  - A4: Override — chấp nhận blow budget, ghi log.
- Sub-menu xuất hiện trên cùng màn hình ISG (reuse component).

**Alternatives:**
- **Alt A:** Hard block mọi workload > budget — quá khắt khe.
- **Alt B:** Chỉ warning, không block — user vẫn blow budget.
- **Alt C:** Hard-prompt > 1.5× + sub-menu lựa chọn (đã chọn, còn gọi là "Plan A").

**Consequences:**
- **+** User không bao giờ bị blow budget quá mức mà không hay.
- **+** Dead-zone giảm noise cho workload nhẹ.
- **+** Partition Planner có sẵn 4 option, user không phải tự nghĩ.
- **-** Cần workload estimator đủ chính xác — nếu estimate sai thì prompt sai.
- **-** Thêm file contract `fix-workload.json` (xem §4b CORE rules).

**Followups:**
- Phase 1 (Giai đoạn B): Workload Estimator scan nhanh — đếm file/feature/dim probe dự kiến.
- Phase 2: Calibration — monitor actual vs estimate, điều chỉnh hệ số nếu drift.
- Append path contract cho `fix-workload.json` vào `.claude/rules/00-core.md §4b`.

---

## 16. ADR-16 — 4-Level Checkpoint Hierarchy

**Status:** accepted

**Context:**
v5 chỉ có checkpoint theo Phase → nếu crash giữa 1 Phase, mất nguyên phase phải làm lại. Với v6 chạy nhiều lane (tối đa 3 song song) + nhiều probe trong mỗi lane, granularity càng quan trọng: 1 OOM trong probe QD6 không nên kéo user làm lại toàn bộ QD1 + QD2 đang chạy song song.

**Decision:**
4 cấp checkpoint (L0 → L3), atomic write, append-only:
- **L0 — Phase:** Discovery / Triage / Execute boundary (giống v5).
- **L1 — Lane:** 1 lane (QD1, QD2, QD5, ...) hoàn thành tất cả probe của nó.
- **L2 — Probe:** 1 probe trong 1 lane xong (ví dụ `QD1.P1` hoàn tất, `QD1.P2` chưa chạy).
- **L3 — Intra-probe:** Probe đang chạy nhiều feature — xong feature nào ghi feature đó. Granularity thấp nhất.

Yêu cầu: **Khi resume, không bao giờ mất dữ liệu quá 1 feature.**

**Alternatives:**
- **Alt A:** Chỉ 2 cấp (Phase + Lane) — đủ cho v5 nhưng v6 multi-lane sẽ lãng phí khi 1 probe crash.
- **Alt B:** 4 cấp đầy đủ (đã chọn).
- **Alt C:** Checkpoint per-issue (cấp L4) — quá chi tiết, overhead write lớn.

**Consequences:**
- **+** User mất tối đa 1 feature khi resume, không phải 1 probe.
- **+** Multi-lane crash isolation: 1 lane crash không kéo theo lane khác.
- **+** `--resume` chính xác theo L0-L3 state.
- **-** Checkpoint file phức tạp hơn (4 levels).
- **-** Phải test kỹ resume path cho từng level.

**Followups:**
- Phase 1 (Giai đoạn B): extend `checkpoint.json` schema để chứa `level`, `lane`, `probe`, `feature_cursor`.
- Phase 2: resume logic cho mỗi level + golden fixture test.
- Chỉ lane đã COMPLETE L1 mới trigger Signal Bus merge.

---

## 17. ADR-17 — 3-Tier Concurrency Controller token-bucket

**Status:** accepted

**Context:**
ADR-05 đã cap max 3 lane song song. Nhưng trong mỗi lane còn nhiều probe, và mỗi probe còn gọi agent/file ops/Playwright. Không có controller → dễ OOM hoặc queue agent ngầm.

**Decision:**
3 tier token bucket, áp dụng đồng thời:
- **Global:** `max_inflight_tasks = 12` — tổng task chạy cùng lúc trên toàn process.
- **Per-lane:** `max_inflight_per_lane = 4` — 1 lane tối đa 4 task.
- **Per-probe:** `max_inflight_per_probe = 6` — 1 probe scan nhiều file/feature tối đa 6 task.

Task phải acquire token của cả 3 tier trước khi chạy. Release khi xong.

**Alternatives:**
- **Alt A:** 1 tier global — không control được noise trong 1 lane.
- **Alt B:** Không tier, để OS tự điều phối — dễ OOM Playwright.
- **Alt C:** 3 tier (đã chọn).

**Consequences:**
- **+** Budget RAM + agent concurrency ổn định.
- **+** Không lane nào "đói" token — fair share giữa 3 lane song song.
- **-** Thêm module `_shared/concurrency/` — token bucket implement.
- **-** Config 3 số phải đồng bộ với `max_parallel_lanes=3` (ADR-05).

**Followups:**
- Phase 1 (Giai đoạn B): implement token bucket + unit test.
- Phase 2: measure thực tế, tune 12/4/6 nếu cần.
- Expose config qua `_shared/concurrency/config.json` cho v6.1 tunable.

---

## 18. ADR-18 — Impact Graph + Verification Ripple (depth=1, strength ≥ 0.5)

**Status:** accepted

**Context:**
Khi Fixer sửa 1 feature, behavior có thể rò sang feature khác (đặc biệt cùng module hoặc có DB cross-ref). v5 chỉ verify đúng feature vừa fix → regression rò rỉ âm thầm.

**Decision:**
- Build **Impact Graph** trong Discovery Phase, lưu `$SESSION_DIR/impact-graph.json`.
- Edge giữa 2 feature có `strength ∈ [0, 1]` dựa trên shared file / shared DB table / cross REQ-ID ref / UI route parent.
- Verifier **ripple depth = 1** (chỉ neighbor trực tiếp, không transitive).
- Ripple trigger khi `strength ≥ 0.5` (hạ từ 0.7 để giảm false-negative).
- **Luôn bật** (không có flag `--no-ripple`) — đây là safety floor.

**Alternatives:**
- **Alt A:** Không ripple — giống v5, để user tự verify.
- **Alt B:** Ripple depth=2+ hoặc transitive — verify sẽ nổ.
- **Alt C:** Ripple depth=1, strength ≥ 0.7 — quá khắt khe, bỏ lỡ cross-module link.
- **Alt D:** Ripple depth=1, strength ≥ 0.5 (đã chọn).

**Consequences:**
- **+** Regression rò rỉ cross-feature bắt được trong cùng session fix.
- **+** User trust cao: fix QD1 không gây break QD2 âm thầm.
- **+** Strength threshold 0.5 balance giữa coverage và verify budget.
- **-** Tăng verify time ~20-40% (tùy mật độ Impact Graph).
- **-** Impact Graph build cost trong Discovery — cần probe P0.XREF.

**Followups:**
- Phase 1 (Giai đoạn B): probe P0.XREF build Impact Graph.
- Phase 2: tune strength threshold theo data thực tế Phase 5.
- Append path contract cho `impact-graph.json` vào `.claude/rules/00-core.md §4b`.

---

## 19. ADR-19 — Scan Cache content-addressable, v6.0 opt-in

**Status:** accepted

**Context:**
Nhiều probe (đặc biệt QD1 static scan, QD5 a11y probe không có interactive state) idempotent — cùng input → cùng output. Chạy lại giữa 2 session gần nhau tốn rất nhiều token. Nhưng cache sai cũng nguy hiểm (stale result dẫn đến miss bug thật).

**Decision:**
- **Scan Cache content-addressable** theo fingerprint: `hash(probe_id + file_path + file_sha256 + probe_version)`.
- Lưu tại `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json`.
- **TTL 14 ngày** — sau 14 ngày tự invalidate.
- **v6.0: opt-in** qua flag `--use-cache` — mặc định off để giảm rủi ro v1.
- **v6.1: default on** (sau khi có data validate từ Phase 5).
- **QD3 Security NEVER cached** — security probe phải luôn re-scan (xem ADR-22).

**Alternatives:**
- **Alt A:** Không cache — đơn giản nhưng token cost cao.
- **Alt B:** Cache luôn, default on ngay v6.0 — risk stale.
- **Alt C:** v6.0 opt-in, v6.1 default on (đã chọn) — dần dần validate.
- **Alt D:** Cache theo mtime file thay vì sha256 — dễ false-positive khi `touch` file.

**Consequences:**
- **+** Session lặp gần nhau (same commit, same config) chạy nhanh gấp 2-5×.
- **+** QD3 exemption ngăn miss security bug do cache.
- **+** Content-addressable an toàn hơn mtime.
- **-** Thêm folder `.mc-data/cache/` — cần cleanup policy.
- **-** User phải hiểu `--use-cache` khác `--incremental` (ADR-20) — doc rõ.

**Followups:**
- Phase 1 (Giai đoạn B): cache writer + reader trong `_shared/scan_cache/`.
- Phase 2: cleanup job — xoá file `> TTL`.
- Phase 5: measure cache hit rate để quyết v6.1 default on.
- Append path contract cho `.mc-data/cache/wf-fix-bugs/probes/*.json` vào §4b.

---

## 20. ADR-20 — Incremental Mode explicit (`--incremental --since=<ref>`)

**Status:** accepted

**Context:**
Dev flow phổ biến: "fix commit này rồi verify lại những gì tôi vừa sửa". Không cần scan toàn repo. Nhưng auto-detect incremental cũng nguy hiểm — dev có thể không nhận ra scope bị thu hẹp.

**Decision:**
- **Explicit flag bắt buộc:** `--incremental --since=<git-ref>`.
- `<git-ref>` mặc định `HEAD~1` nếu user gõ `--incremental` mà không có `--since`.
- **Fallback:** nếu session trước có lưu commit hash (`last_session_commit` trong checkpoint) → sử dụng làm base cho lần chạy kế tiếp.
- **KHÔNG auto-enable** — nếu user không gõ `--incremental` thì chạy full scope theo profile.

**Alternatives:**
- **Alt A:** Auto-enable khi detect có git diff — user có thể bị miss bug ngoài diff.
- **Alt B:** Không support incremental — dev phải chạy full mỗi lần.
- **Alt C:** Explicit flag với fallback (đã chọn).

**Consequences:**
- **+** Dev loop nhanh: fix → `/wf-fix-bugs --incremental` → verify trong 2-5m.
- **+** Predictable: user không bị miss scope âm thầm.
- **-** User phải biết và gõ flag — cần doc + hint.
- **-** Fallback dựa vào `last_session_commit` → phải bảo đảm checkpoint ghi đủ.

**Followups:**
- Phase 1 (Giai đoạn B): resolve `--since=<ref>` → list files changed.
- Phase 2: doc + example trong README + cheat sheet.
- CDG check: `--incremental` + `--profile=exhaustive` mâu thuẫn → cảnh báo, không block.

---

## 21. ADR-21 — Default profile shift: standard = [QD1, QD2, QD5] ★ LOCKED v1.0

**Status:** accepted ★ LOCKED v1.0 (North Star)

**Context:**
Ban đầu `standard` profile là `[QD1 Functional, QD3 Security, QD5 UX/A11y]` — follow best-practice "security mặc định". Nhưng trong nhiều session thực tế với user MCV3 (non-tech), bug được report và chặn release thường là:
- Logic không chạy đúng (QD1).
- Quy trình nghiệp vụ không match spec (QD2 Business).
- UI không truy cập được / a11y vỡ (QD5).

QD3 Security rất quan trọng nhưng ở tier "deep" — user non-tech hiếm khi fix security bug ngay trong session vá lỗi pre-PR; họ thường gọi audit riêng.

**Decision:**
- Default `standard` profile = **[QD1 Functional, QD2 Business, QD5 UX/A11y]** (đổi QD3 → QD2).
- QD3 Security **VẪN BẬT** ở profile `deep` và `exhaustive` — chỉ bị loại khỏi default `standard`.
- User vẫn có thể gọi explicit: `--profile=standard --dims=QD1,QD3,QD5` nếu muốn security trong standard.
- **North Star:** `logic + nghiệp vụ + UI` — 3 trục mà user non-tech quan tâm nhất.

**Alternatives:**
- **Alt A:** Giữ `[QD1, QD3, QD5]` — follow industry best-practice, nhưng bỏ qua QD2 Business.
- **Alt B:** `[QD1, QD2, QD5]` (đã chọn) — North Star match user MCV3.
- **Alt C:** `[QD1, QD2, QD3, QD5]` 4-dim — blow budget 15m, làm `standard` chậm.

**Consequences:**
- **+** Default match use case user non-tech — ít bị bất ngờ.
- **+** Ăn khớp với vision MCV3 (business + logic + UI là 3 trục chính).
- **+** QD3 vẫn bắt buộc ở `deep`/`exhaustive` — không mất security coverage cho pre-RC.
- **-** Risk: user chạy `standard` rồi tưởng đã check security → cần doc rõ (ADR-22 safety defaults).
- **-** Phải sync 10 file design + 1 CORE §4a (đã xong phần lớn trong session này).

**Followups:**
- Doc tuyên bố rõ "North Star" trong README + 01-vision-principles.md.
- CDG check: nếu user request GA/compliance release → auto-suggest upgrade lên `deep`/`exhaustive`.
- Phase 5: user research confirm North Star có đúng không.

---

## 22. ADR-22 — Safety Defaults Non-Negotiable ★ LOCKED v1.0

**Status:** accepted ★ LOCKED v1.0

**Context:**
ADR-21 shift default profile → nới một số default. Phải có 1 tập luật "không thương lượng" để user không thể tắt quá mức và vô tình bỏ qua bug nghiêm trọng hoặc drift registry.

**Decision:**
6 rule non-negotiable — không flag nào tắt được:

1. **Profile ≥ standard KHÔNG được phép bỏ toàn bộ [QD1, QD2, QD5].**
   - User có thể `--dims=QD1,QD5` (bỏ QD2) nhưng KHÔNG được `--dims=QD4` lone ở `standard`+.
   - Rationale: standard+ phải cover tối thiểu logic hoặc UI hoặc business.
2. **Verification Ripple luôn bật** (ADR-18) — không có flag `--no-ripple`.
3. **QD3 Security KHÔNG BAO GIỜ cache** (ADR-19) — mọi session re-scan security.
4. **CDG (Critical Decision Gate) kích hoạt tại 7 điểm** — CORE-027 — bao gồm khi Fixer sắp commit secrets, khi chuẩn bị DROP table, khi `--override-budget`, v.v.
5. **POST-GATE T1-T4 luôn chạy** — CORE-012 — không có flag `--skip-post-gate`.
6. **SAFE-UPDATE `impl_status`** — CORE-006/008 — Fixer KHÔNG BAO GIỜ downgrade `done` → state khác.

**Alternatives:**
- **Alt A:** Không có bộ safety defaults — user flex hoàn toàn, dễ drift.
- **Alt B:** Safety defaults có thể tắt qua `--unsafe` — vẫn drift được.
- **Alt C:** Non-negotiable, không tắt được (đã chọn).

**Consequences:**
- **+** Registry + security invariant bảo toàn trong mọi profile.
- **+** User mới không vô tình làm mất data / miss security.
- **+** Auditor có 6 luật hard để kiểm tra.
- **-** Một số use case edge (ví dụ rebuild registry sau corruption) có thể cần bypass — xử lý qua skill riêng `/wf-fix-registry`, không qua `--unsafe`.

**Followups:**
- Phase 1 (Giai đoạn B): guard rail trong orchestrator — reject flag combos vi phạm.
- Phase 2: test fixture — 1 suite verify từng rule trong 6 rule trên.
- Doc section "Safety Defaults Non-Negotiable" trong README.

---

## 23. ADR-23 — Partition Planner: ISG-guided vs default priority split

**Status:** accepted

**Context:**
Khi dimensions vượt `max_workload_size`, cần strategy chia workloads. ISG recommender có thể gợi ý dimensions nên group, nhưng không phải lúc nào ISG data cũng available (ví dụ `--no-interactive` hoặc CI/CD mode).

**Decision:**
Ưu tiên ISG recommendation khi có, fallback sang priority-based (core dims QD1+QD2+QD5 trước, sau đó QD3, QD4, QD6, QD7 theo thứ tự risk). Partition Planner trong `_shared/partition_planner.py`.

**Alternatives:**
- **Alt A:** Luôn dùng priority-based — bỏ qua ISG context, kém chính xác cho specific domains.
- **Alt B:** Luôn dùng ISG — fail khi không có ISG data.
- **Alt C:** ISG-guided với priority-based fallback (đã chọn).

**Consequences:**
- **+** ISG-aware partition cho kết quả tốt hơn cho specific domains.
- **+** Default strategy đảm bảo always-working fallback.
- **-** 2 code paths để maintain trong partition planner.

**Followups:**
- Stage J đã implement + test (12 tests).
- Monitor partition quality trong Phase 5 burn-in.

---

## 24. ADR-24 — AggregationStats v2 schema: dimension-level coverage fields

**Status:** accepted

**Context:**
Cần track dimension-level coverage để generate meaningful `coverage-report.md`. v1 AggregationStats chỉ có `total_signals`, `total_issues`, `by_dimension`, `errors` — không đủ để tính coverage rate.

**Decision:**
Thêm 6 fields vào AggregationStats:
1. `dimensions_run` — list dimensions đã chạy.
2. `dimensions_with_issues` — dimensions có issues phát hiện.
3. `dimensions_without_issues` — dimensions không có issues.
4. `coverage_rate_pct` — % dimensions có issues.
5. `dedup_ingested` — signals ingested vào bus.
6. `dedup_deduplicated` — signals removed by dedup.

**Alternatives:**
- **Alt A:** Không thêm fields — coverage report phải tính lại từ `issue-registry.json` mỗi lần.
- **Alt B:** Thêm fields (đã chọn) — pre-computed, dùng trực tiếp cho report generation.

**Consequences:**
- **+** Reports có coverage metrics sẵn, không cần recompute.
- **+** `coverage-report.md` generation nhanh hơn.
- **-** Stats object lớn hơn (thêm 6 fields).

**Followups:**
- Signal Aggregator đã populate v2 fields trong Stage J.
- Report Generator consume v2 fields cho coverage-report.

---

## 25. Open Questions

Các câu hỏi cần resolve trước khi implement (hoặc trong quá trình Phase 1-3):

### Q1. Signal Bus có nên có LLM dedup ngoài hash-based không?

- **Thế nào:** 2 signal khác dim, khác location string nhưng cùng root cause (ví dụ `/admin/reset` vs `/api/v2/admin/reset-password`).
- **Cost concern:** LLM dedup mỗi batch tốn tokens.
- **Option:** Chỉ trigger LLM dedup khi hash dedup đã chạy + vẫn có ≥ 2 signal cùng file path prefix.
- **Đáp án tạm:** Yes, but gated by heuristic. Final decision trong Phase 2 PoC.

### Q2. Golden fixtures nên ở đâu?

- **Option A:** Trong `.claude/skills/workflow/wf-fix-<dim>/evals/golden/`.
- **Option B:** Shared fixtures `.claude/skills/workflow/wf-fix-bugs/evals/fixtures/`.
- **Đáp án tạm:** Option A cho lane-specific; Option B cho cross-dim scenarios. Quy định trong Phase 2.

### Q3. Có cần plugin registry cho dimension thứ 8 không?

- **Context:** User doanh nghiệp có thể muốn QD8 Finance Compliance hoặc QD8 Healthcare PHI.
- **Option:** `config/dimensions.json` mở — bất kỳ skill `wf-fix-*` nào được register đều chạy.
- **Đáp án tạm:** Support "community dim" từ Phase 6, sau khi 7 dim core stable.

### Q4. Verifier retry tối đa 3 lần — có quá ít không?

- **Context:** Một số fix (agent reasoning) cần nhiều iteration.
- **Option:** 3 lần cố định + user override `--max-retries=N`.
- **Đáp án tạm:** 3 lần default, monitor Phase 4 actual data để điều chỉnh.

### Q5. Fixer apply code patch có cần lint tự động không?

- **Context:** Fix có thể vi phạm lint rule.
- **Option A:** Fixer chạy lint + auto fix formatting.
- **Option B:** Fixer chỉ apply, dev tự chạy lint.
- **Đáp án tạm:** Option A với lint tool detect (Prettier, ESLint, ruff...); không fail nếu lint missing.

### Q6. Dimension Manifest bản `_contract.json` vs `dimension.json` — có trùng?

- **Context:** `_contract.json` đang là convention MCV3 cho skill contract; `dimension.json` là mới.
- **Option:** Giữ cả 2 — `_contract.json` cho skill registry scope + outputs, `dimension.json` cho probe/exit/severity rule.
- **Đáp án tạm:** OK tạm thời. Nếu merge được thì merge trong v6.1.

---

## 26. Deprecated Alternatives — Note Cho Reviewer

Các option đã từ chối rõ, không nên revisit:

- ❌ Kết hợp 12 bug category plan v1.1 thành 12 sub-skill riêng — quá rối.
- ❌ Signal Bus là agent — quá nặng cho task deterministic.
- ❌ Xoá hẳn `/wf-fix-triage` và gọi logic inline — break backward-compat slash command user đã quen.
- ❌ Default max_parallel_lanes=7 — infra chưa support.

---

## 27. Checklist Cho Người Mở ADR Mới

Khi propose ADR mới (ví dụ trong Phase 3-4):

- [ ] Copy format §0.
- [ ] Đặt số tuần tự tiếp theo.
- [ ] Status bắt đầu `proposed`, chỉ chuyển `accepted` sau review.
- [ ] Liệt kê tối thiểu 2 alternatives.
- [ ] Consequences có cả tích cực + tiêu cực.
- [ ] Followups có action owner.
- [ ] Update [README.md](README.md) ADR Quick Reference table.

---

## 28. Liên kết

- Vision + Principles: [01-vision-principles.md](01-vision-principles.md)
- Quality Dimensions: [02-quality-dimensions.md](02-quality-dimensions.md)
- Architecture: [03-architecture.md](03-architecture.md)
- Schemas + Contracts: [04-contracts-data-model.md](04-contracts-data-model.md)
- Profiles: [05-execution-profiles.md](05-execution-profiles.md)
- Migration: [06-migration-plan.md](06-migration-plan.md)
- Design Decisions (Q14-Q23 rationale, LOCKED v1.0): [09-design-decisions.md](09-design-decisions.md)
- README: [README.md](README.md)
