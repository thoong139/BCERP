# 06 — Migration Plan (v5 → v6)

> **Đọc trước:** [05-execution-profiles.md](05-execution-profiles.md)
> **Đọc tiếp:** [07-tradeoffs-adr.md](07-tradeoffs-adr.md)

Tài liệu này vạch roadmap chuyển pipeline **`/wf-fix-bugs` v5.1.0 (3 sub-skill, 5-Layer discovery)** sang **v6.0.0 (7 dimension lane + shared services)**, không break user và đảm bảo mọi session đang chạy đều có đường về.

---

## 1. Nguyên Tắc Migration

| # | Nguyên tắc |
|---|------------|
| MP-1 | **User experience không gãy:** Tất cả slash command v5 vẫn chạy trong quá trình migration. |
| MP-2 | **Flag compat 100%:** Mọi flag v5 vẫn hiệu lực (map sang v6 behavior — xem [05 §5](05-execution-profiles.md)). |
| MP-3 | **Data backward-compat:** `issue-v1` (v5 schema) read được bởi v6 via migration helper. |
| MP-4 | **Phase gate:** Không merge phase sau khi phase trước chưa PASS hết acceptance criteria. |
| MP-5 | **Parallel branches:** v5 và v6 skill folder coexist; cutover chỉ ở orchestrator level. |
| MP-6 | **Feature flag:** Cho phép `--engine=v5\|v6` trong phase 2-4 để user test từ từ. |
| MP-7 | **Rollback plan:** Mỗi phase có rollback checklist. |

---

## 2. Lộ Trình Tổng

```
Phase 0 — Design Approval          (tuần 1-2)  Current
Phase 1 — Skeleton + Dim Registry  (tuần 3-4)
Phase 2 — Bellweather Lanes        (tuần 5-7)  QD1 + QD3 first
Phase 3 — Remaining Lanes          (tuần 8-11)
Phase 4 — Shared Services v6       (tuần 12-14)
Phase 5 — Cutover + Deprecation    (tuần 15-16)
Phase 6 — v5 Removal               (tuần 17+)
```

> Thời gian là ước lượng. Không ép tiến độ khi phase chưa pass acceptance.

---

## 3. Phase 0 — Design Approval

**Mục tiêu:** Đạt consensus về kiến trúc dimension-based.

**Trạng thái:** ✅ COMPLETE

**Deliverable:**

- [x] README.md + 7 file design (01-07).
- [x] Review tập thể với 3 bên: PM owner, senior engineer, QA lead.
- [x] Ghi nhận feedback vào [07-tradeoffs-adr.md](07-tradeoffs-adr.md) § Open Questions.
- [x] User sign-off tree 7 file design.

**Acceptance:**

- Tất cả CORE rule binding (CORE-004, 006, 007, 023-025, 027, 028, 030, 031) được cover.
- Schema v2 không mâu thuẫn ADR.
- Backward-compat đã verify trên giấy.

**Rollback:** Không áp dụng — chỉ là doc phase.

---

## 4. Phase 1 — Skeleton + Dim Registry

**Trạng thái:** ✅ COMPLETE (Stages B1-B4)

**Mục tiêu:** Dựng xương sống v6 mà chưa có lane nào chạy production.

**Deliverable code:**

- `.claude/skills/workflow/wf-fix-bugs/SKILL.md` — thêm flag `--engine=v5|v6` (default v5).
- `.claude/skills/workflow/wf-fix-bugs/config/dimensions.json` — empty registry.
- `.claude/skills/workflow/wf-fix-bugs/config/profiles.json` — 4 profile đầy đủ.
- `.claude/skills/workflow/wf-fix-bugs/config/schema-registry.json`.
- Schema JSON files trong `.claude/skills/workflow/wf-fix-bugs/schema/` cho mọi contract [§14.2 ở 04](04-contracts-data-model.md).
- Template `fix-status-v6.json`, `orchestrator-summary.md`, `coverage-report.md`, `phase-summary.md`.
- `_shared/signal_bus/` skeleton (README + schema references).

**Deliverable doc:**

- Cập nhật `.claude/rules/00-core.md §4b` — thêm các dòng path mới từ [04 §13.2](04-contracts-data-model.md).
- Cập nhật `CLAUDE.md` — ghi chú engine v5/v6 coexist.

**Acceptance:**

- `./.claude/scripts/validate-schema-sync.sh wf-fix-bugs` pass.
- `./.claude/scripts/skill-compliance-audit.sh wf-fix-bugs` pass.
- Chạy `/wf-fix-bugs --engine=v6 --explain` trả về error "no dimensions registered" (đúng expected).
- Chạy `/wf-fix-bugs` (không flag) vẫn route sang v5 orchestrator nguyên si.

**Rollback:**

- Revert `--engine` flag.
- Restore `config/` folder.
- Không impact user — v5 vẫn chạy.

---

## 5. Phase 2 — Bellweather Lanes (QD1 + QD2)

**Trạng thái:** ✅ COMPLETE (Stages C-D)

> **Note:** Design gốc dự định QD1+QD3 làm bellweather, nhưng do QD2 Business đã implement song song trong Stage C-D nên cả 7 lanes hoàn tất cùng lúc.

**Mục tiêu:** Implement 2 lane đầu tiên để validate lane model, signal schema, và Signal Bus logic. Chọn QD1 (functional, broad) + QD3 (security, compliance-sensitive) vì chúng cover hầu hết risk pattern.

**Deliverable code:**

- `.claude/skills/workflow/wf-fix-functional/` — skill, dimension.json, probes P1.01-P1.07 (migrate từ wf-fix-discover 5-Layer).
- `.claude/skills/workflow/wf-fix-security/` — skill, dimension.json, probes P3.01-P3.09.
- `_shared/signal_bus/` — dedup + severity aggregation logic.
- Golden fixtures cho 2 lane trong `evals/golden/`.
- Migration helper script: `_shared/signal_bus/migrate-v1-to-v2.sh`.

**Deliverable test:**

- Chạy `/wf-fix-bugs --engine=v6 --only=functional --profile=quick` trên 3 dự án mẫu (new, legacy-small, legacy-large).
- Chạy `/wf-fix-bugs --engine=v6 --only=security --profile=standard` trên 2 dự án mẫu.
- So sánh kết quả v5 vs v6 — liệt kê signal mới phát hiện, signal missing, false positive.

**Acceptance:**

- QD1 coverage ≥ 80% so với wf-fix-discover 5-Layer tương đương.
- QD3 phát hiện tối thiểu tất cả issue CRITICAL v5 từng phát hiện trên fixture.
- False positive rate < 10% (số signal sai / tổng signal).
- `phase-summary.md` ≤ 15 dòng (CORE-028).
- POST-GATE T1-T4 pass.
- Migration helper chuyển `issue-v1` → `issue-v2` trên 3 session v5 mẫu không lỗi.

**Rollback:**

- User không dùng `--engine=v6` là xong; v5 default không bị ảnh hưởng.
- Nếu lane có bug nghiêm trọng: set `registered[*].enabled=false` trong `dimensions.json`.

**Gate cho Phase 3:** QD1 + QD3 đã pass acceptance. Ghi ADR bổ sung nếu phát hiện lesson learned.

---

## 6. Phase 3 — Remaining Lanes (QD2, QD4, QD5, QD6, QD7)

**Trạng thái:** ✅ COMPLETE (Stages D-E)

**Mục tiêu:** Hoàn thiện 5 lane còn lại.

**Thứ tự đề xuất:**

1. **QD5 UX/A11y** — dùng chung runtime infra của QD1 (Playwright).
2. **QD6 Data Integrity** — migrate từ hooks validate-naming / DB probes hiện có.
3. **QD4 Performance** — mới, cần agent performance-engineer.
4. **QD2 Business Rules** — cần BA agent + domain knowledge.
5. **QD7 Compatibility** — cuối cùng, cost cao nhất (multi-browser runtime).

**Deliverable per lane:**

- Skill folder đầy đủ (tương tự Phase 2).
- Probes minimum viable (quick + standard depth) — deep/exhaustive có thể phase 3.5.
- Golden fixtures.
- Update `config/dimensions.json` đăng ký.

**Acceptance per lane:**

- Chạy được standalone qua `--only=<alias>`.
- Coverage ≥ 70% so với category v5 tương đương (nếu có).
- Signal schema v1 compliant.
- Không regress QD1 + QD3 (Signal Bus không conflict).

**Parallel development:** 5 lane này có thể implement song song BẰNG người khác nhau — tuân thủ CORE-025 vì write scope tách biệt (mỗi lane ghi `lanes/<dim>/`).

**Rollback:** Per lane — disable trong `dimensions.json`.

---

## 7. Phase 4 — Shared Services v6

**Trạng thái:** ✅ COMPLETE (Stages H-L)

> **Note:** Stage J (ISG + Partition Planner), Stage K (Contract sync), Stage L (Multi-workload integration tests) hoàn tất Phase 4. Tổng ~507 tests, 0 failures.

**Mục tiêu:** Replace logic `/wf-fix-execute` bằng 4 service nhỏ (Triage, Planner, Fixer, Verifier) theo spec [03 §2.4](03-architecture.md).

**Deliverable code:**

- `wf-fix-triage/` SKILL.md v2 — logic mở rộng: đọc `issue-v2`, enrich theo dimension.
- `_shared/fixer/` — router tới domain agents (security-engineer, ux-designer, ...).
- `_shared/fixer/auto-fix-templates/` per dimension.
- `_shared/verifier/retry-policy.md`.
- Coverage Reporter utility (gắn vào orchestrator POST-GATE).

**Deliverable test:**

- Run full pipeline v6 end-to-end trên 3 fixture đã test ở Phase 2-3.
- So `fix-report.md` v5 vs v6 — số issue fixed phải ≥ v5.
- Verify retry policy: 3 tries → ESCALATE.

**Acceptance:**

- Fix success rate (AUTO_FIX + AGENT_FIX, verify passed) ≥ 85% của v5.
- CDG flow chạy đúng: 3 case (secrets, schema, destructive migration) đều pause + ask user.
- `orchestrator-summary.md` + `phase-summary.md` đầy đủ.
- POST-GATE T1-T4 pass trên toàn workflow.
- `_shared/` không write sai scope.

**Gate cho Phase 5:** E2E pipeline v6 đã pass acceptance với ≥ 3 fixture đa dạng.

---

## 8. Phase 5 — Cutover + Deprecation Notice

**Trạng thái:** ✅ COMPLETE — `--engine=v6` là default, v5 deprecated

**Mục tiêu:** Chuyển default engine từ v5 → v6.

**Bước:**

1. ✅ Chạy `/wf-fix-bugs --engine=v6` không flag → đảm bảo trải nghiệm tương đương v5.
2. ✅ Cập nhật `SKILL.md` v6.0.0 — `--engine` flag đã xoá (Stage N).
3. ✅ Migration guide: không cần — Stage N xoá v5 hoàn toàn, không còn migration path.
4. ✅ Update `CLAUDE.md` — thêm 7 dimension lanes vào bảng Hỗ trợ & Quality (2026-04-21).
5. ✅ Examples + docs: design docs đã sync qua Stage M.

**Acceptance:**

- 2 tuần burn-in: monitor `session-log.json` entries → không có regression báo cáo từ user internal.
- Migration helper auto chạy khi `--resume` trên session v5 → chuyển sang v6 schema.
- `fix-history.md` merge được giữa 2 pipeline.

**Rollback:**

- Revert default về `v5` trong `SKILL.md`.
- Notify user qua CHANGELOG.

---

## 9. Phase 6 — v5 Removal

**Trạng thái:** ✅ COMPLETE — Stage N (2026-04-21)

**Điều kiện:** Sau ≥ 4 tuần từ cutover, không có bug/regression critical.

**Bước xoá:**

1. Xoá `wf-fix-discover/`, `wf-fix-execute/` (folder skill cũ).
2. Giữ `wf-fix-triage/` (đã rewrite ở Phase 4 — không phải delete).
3. Xoá `--engine` flag trong orchestrator.
4. Xoá migration helper `migrate-v1-to-v2.sh` → archive vào `docs/archives/`.
5. Update `.claude/rules/00-core.md §4b`: xoá các dòng v5 path đã deprecate.
6. Archive `issue-v1` schema vào `docs/archives/schemas/`.
7. Archive v5 plans trong `plans/coverage-expansion/` → link tới migration ADR.

**Acceptance:**

- Audit: `./.claude/scripts/skill-compliance-audit.sh --all` pass.
- Grep `v5\|--engine\|wf-fix-discover\|wf-fix-execute` repo-wide = 0 match.
- Tất cả docs không còn reference v5 paths (trừ archive).

**Rollback:** Không rollback được sau Phase 6. Đảm bảo Phase 5 burn-in đủ dài.

---

## 10. Data Migration

### 10.1 Session v5 đang chạy khi bắt đầu Phase 5

**Strategy:** Resume-only. Không auto migrate in-flight session.

```
User gọi /wf-fix-bugs --resume trên session v5:
  1. Detect schema issue-v1 → in warning
  2. Offer: "Continue with v5 engine?" (Y) hoặc "Migrate to v6?" (N)
  3. Y → route sang v5 orchestrator cũ (giữ lại tới Phase 6)
  4. N → chạy migrate-v1-to-v2 → route sang v6
```

### 10.2 `fix-history.md` format

Giữ nguyên format markdown. v6 entries thêm dimension suffix:

```
## 2026-04-20 run-017 (engine=v6, profile=standard, dims=[QD1,QD2,QD5])
- 38 issues, 31 fixed, 5 escalated, 2 skipped
- SESSION_DIR: .mc-data/work/wf-fix-bugs/run-017--20260420/
```

> Ví dụ trên minh hoạ default v1.0 (standard = QD1+QD2+QD5 — logic + nghiệp vụ + UI). Các run với `--only=security` hoặc `--auto` tick QD3 sẽ có `dims` khác tương ứng.

### 10.3 `preflight-report.md` consumption

v6 lane QD1 đọc cùng file v5 dùng — không đổi path, chỉ mở rộng parser để lấy thêm hint cho dim khác (QD5 từ UI warnings).

---

## 11. CORE Rule Updates Kèm Theo

Khi Phase 1 ship, các rule cần cập nhật:

- **`.claude/rules/00-core.md §4a`** — thêm role NONE cho `wf-fix-functional`, `wf-fix-business`, `wf-fix-security`, `wf-fix-performance`, `wf-fix-ux`, `wf-fix-data`, `wf-fix-compat`. Giữ role SAFE-UPDATE cho Fixer (service, không phải skill command riêng).
- **`.claude/rules/00-core.md §4b`** — thêm các dòng path [04 §13.2](04-contracts-data-model.md).
- **`.claude/rules/00-core.md Quick Reference`** — giữ nguyên CORE IDs; không thêm mới.
- **CLAUDE.md `Workflow & Skills` table** — thêm 7 lane mới vào danh sách "Hỗ trợ & Quality" (hoặc subcategory "Fix bug lanes").

**Chuẩn bị patch:** Implementer sẽ gom tất cả thay đổi rules vào 1 PR riêng, review cùng với Phase 1 code.

---

## 12. Risk Register

| Risk | Xác suất | Tác động | Mitigation |
|------|---------|----------|-----------|
| Signal Bus dedup mis-merge | Trung bình | Miss bug | Golden fixtures + semantic dedup chỉ chạy khi cùng location |
| Lane QD4 Performance khó implement | Cao | Trễ Phase 3 | Downgrade: chỉ có quick depth ở MVP, deep sau |
| False positive nhiều ở QD2 Business | Cao | User mệt với triage | Severity default LOW cho QD2 probe mới; user opt-in |
| Migration helper bug trên large session | Thấp | Fail cutover | Dry-run migration 5 session thật trước Phase 5 |
| CDG user reject hàng loạt | Thấp | Block workflow | Triage cho phép "review later" — không block fix các issue khác |
| Agent concurrency limit | Trung bình | Lane timeout | Giới hạn max_parallel_lanes=3 + retry logic |
| Registry corruption khi fix_applied → impl_status | Thấp | SSOT broken | Safe-write + validate `jq '.'` sau mỗi ghi (CORE-006) |

---

## 13. Rollout Communication

### 13.1 Audience

- **End user (người không chuyên):** Thấy ít thay đổi. Chỉ cần biết `--engine=v6` từ Phase 1.
- **Power user + PM:** Thông báo flag mới (`--only`, `--dims`, `--explain`, `--auto`).
- **Implementer + contributor:** Đọc toàn bộ design doc + CORE rule update.

### 13.2 Channels

- CHANGELOG per phase.
- `docs/design/skills/wf-fix-bugs/` (repo).
- Nội bộ: demo mỗi phase end.

### 13.3 Sample CHANGELOG entries

```markdown
## [v5.2.0] — Phase 1 Skeleton
### Added
- `--engine=v5|v6` flag (default v5).
- New config: `config/dimensions.json`, `config/profiles.json`.
- Schema registry for v6 contracts.

## [v5.3.0] — Phase 2 QD1 + QD3 Lanes
### Added
- Lanes `wf-fix-functional`, `wf-fix-security` available via `--engine=v6`.
- Migration helper `migrate-v1-to-v2.sh`.
### Changed
- Default behavior unchanged (v5 still default).

## [v6.0.0] — Phase 5 Cutover
### Changed
- Default engine is now v6 (dimension-based).
- Flags `--only`, `--dims`, `--explain`, `--auto` available.
### Deprecated
- `--engine=v5` will be removed in v6.1.0.

## [v6.1.0] — Phase 6 Removal
### Removed
- v5 engine code (`wf-fix-discover`, `wf-fix-execute`).
- `issue-v1` schema; use migration helper (archived) for legacy sessions.
```

---

## 14. Post-Migration Review

Sau Phase 6, chạy review session với checklist:

- [ ] Metrics: time-to-fix, coverage %, false positive rate, user satisfaction trước vs sau.
- [ ] Audit: session-log.json tần suất error per lane.
- [ ] Gather feedback: điểm nào UX người dùng không thích.
- [ ] Ghi nhận vào new ADR nếu có kiến trúc change cho v6.x.
- [ ] Schedule next iteration: plugin-able dim mới?

---

## 15. Liên kết

- Tổng quan architecture: [03-architecture.md](03-architecture.md)
- Schemas/contracts: [04-contracts-data-model.md](04-contracts-data-model.md)
- Profiles + Flags: [05-execution-profiles.md](05-execution-profiles.md)
- ADRs + Open Questions: [07-tradeoffs-adr.md](07-tradeoffs-adr.md)
- README navigation: [README.md](README.md)
