# 00 — Master Plan: Audit 7 Dimensions của `wf-fix-bugs`

## 1. Scope

### Trong phạm vi
- 7 lane skills: `wf-fix-{functional, business, security, performance, ux-a11y, data, compat}`
- 43 probes (cộng từ 7 lanes)
- Lane shared library: `_shared/lane/{dispatcher.py, pre-gate.md, post-gate.md, signal-emit.md, profile-resolver.md}`
- Profile config: `_shared/profiles.json`
- Cross-probe interactions (ví dụ: cascade skip, catalog handoff)

### Ngoài phạm vi
- Orchestrator `wf-fix-bugs` SKILL.md (đã audit phase trước)
- Sub-skills `wf-fix-triage` và `wf-fix-execute` (audit riêng)
- Workflow gates (Workload, CDG, Safety) — đã review

## 2. Mục tiêu cụ thể

| ID | Mục tiêu | Acceptance Criteria |
|---|---|---|
| **G1** | Phát hiện logic bugs trong probe implementation | Mỗi finding có file:line reference + reproducible case |
| **G2** | Đo false positive rate per probe | Có sample 10 signals/probe, đếm % không phải bug thực |
| **G3** | Đo false negative rate per probe | Tạo test fixture có known bugs, đo % skill phát hiện được |
| **G4** | Tech stack coverage gap | List ngôn ngữ/framework được/không cover bởi mỗi probe |
| **G5** | i18n / l10n bias | Phát hiện hardcoded English keywords (vd CTA detection) |
| **G6** | Edge cases bị miss | Document scenarios skill không xử lý |
| **G7** | Schema validation strictness | Verify CORE-029 spot-check có catch được issues thực sự không |
| **G8** | Improvement roadmap | Build danh sách fix với priority + effort + owner |

## 3. Deliverables chi tiết

### 3.1 Per-dimension audit report (template trong [01-audit-methodology.md](./01-audit-methodology.md))

Mỗi audit gồm 8 sections:
1. **Tổng quan dimension** — định nghĩa, mục tiêu, owner agent
2. **Liệt kê probes** — id, type, depth, severity default
3. **Per-probe analysis** — SENSE/THINK/ACT/VERIFY mechanism
4. **False positive scenarios** — kèm test case
5. **False negative scenarios** — kèm test case
6. **Tech stack & i18n bias** — bảng support/not-support
7. **Edge cases bị miss** — danh sách scenarios
8. **Recommendations** — list improvements với priority

### 3.2 Cross-cutting findings document

Tổng hợp các vấn đề **xuất hiện ở > 1 dim**:
- Stack detection bias (Node-centric)
- Hardcoded thresholds (timeout, MAX_PAGES, max_signals)
- i18n / l10n issues (English keywords)
- Schema validation strictness gaps
- Cascade skip dependency
- Cache policy inconsistency
- Severity rule overlap/conflict

### 3.3 Improvement roadmap

Format mỗi item:
```yaml
- id: IMP-001
  title: "Bổ sung .NET route detection vào P-QD1-route-config-parse"
  affected_probes: [P-QD1-route-config-parse, P-QD1-api-smoke]
  priority: P0  # P0=blocker, P1=high, P2=medium, P3=nice-to-have
  effort: M    # XS<2h, S=2-8h, M=1-3d, L=1-2w, XL=>2w
  owner: skill-author
  acceptance:
    - Probe detect được routes từ ASP.NET Core controllers ([HttpGet], [HttpPost])
    - Test fixture có .NET project → emit signals đúng
  dependencies: []
  notes: "EUREKA-2026 dùng .NET 9 backend"
```

## 4. Phương pháp đánh giá

Xem [01-audit-methodology.md](./01-audit-methodology.md) cho 5-phase framework.

Tóm tắt:
1. **Static review** — đọc dimension.json + probe procedures
2. **Code trace** — bash scripts, Python modules được probe gọi
3. **Test fixture** — tạo project nhỏ với known bugs, chạy probe, đo accuracy
4. **Cross-probe interaction** — verify cascade behavior (skip when infra down)
5. **Synthesize findings** — tổng hợp + priority

## 5. Timeline đề xuất

> **CANONICAL:** Stage architecture đầy đủ trong [11-stages-and-gates.md](./11-stages-and-gates.md). §5 này là tóm tắt.

| Stage | Tuần | Nội dung | Gate | Output |
|---|---|---|---|---|
| **Stage 0** Charter | 1 | 4 decisions + fixtures skeleton + pytest infra | G0 | 12, 13, fixtures/, tests/ |
| **Stage 1** Audit | 2-5 | QD1→QD3→QD6→QD2→QD4→QD5→QD7 | G1 | 02-08 audit reports + 7 fixtures |
| **Stage 2** Consolidation | 6 | Cross-cutting + roadmap lock + sync evals | G2 | 09, 10 locked |
| **Stage 3** Implementation | 7-13 | Sprint impl theo P0→P1→P2→P3 | G3 | Code + CHANGELOG |
| **Stage 4** Re-audit | 14 | Re-run audit, compare baseline | — | improvement-report.md |

**Total:** ~14 tuần (1 owner) hoặc ~9 tuần (3 owners parallel — DEC-002).

**Quy tắc:** Stage N+1 KHÔNG START đến khi Gate N artifact đầy đủ + signed off (tuân CORE-024).

## 6. Các quyết định quan trọng (DECIDED)

| Quyết định | Lý do |
|---|---|
| Pre-seed QD1 audit với findings từ phân tích trước | Đã có data, không cần làm lại |
| Audit theo thứ tự rủi ro (QD3, QD6 trước) | Bug security/data integrity tác động nặng nhất |
| KHÔNG sửa code skill trong plan này | Plan chỉ là audit + roadmap, fix là sprint sau |
| Test fixtures dùng EUREKA-2026 + sample projects | EUREKA-2026 là real-world .NET case, sample là controlled |
| Roadmap dùng P0/P1/P2/P3 priority | Align với DEVKIT convention |

## 7. Decisions (đã chốt — xem [12-decisions-log.md](./12-decisions-log.md))

| Decision | Choice |
|---|---|
| DEC-001 Phương án thực thi | **D — Phased Plan with Evidence Gates** |
| DEC-002 Số owner audit | **1 owner sequential, parallel-ready** |
| DEC-003 Performance benchmark | **Selective** (probes cost ≥60s hoặc agent type) |
| DEC-004 Regression test suite | **Yes — pytest** |
| DEC-005 Output format roadmap | **MD primary với YAML frontmatter per IMP** |
| DEC-006 Sync evals/ | **Yes — sync sau G2** |

## 8. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Audit không hoàn thành đúng timeline | TB | TB | Chia parallel theo dim |
| Test fixture không representative | Cao | Cao | Dùng cả EUREKA real-world + sample |
| Findings quá nhiều → roadmap khổng lồ | Cao | TB | Strict priority filter, drop P3 |
| Sửa probe gây regression | TB | Cao | Bắt buộc unit test trước fix |
| Stack bias không khắc phục được hết | Cao | TB | Document workaround cho user thay vì rewrite |

## 9. Success metric

Plan thành công khi (xem [13-definition-of-done.md](./13-definition-of-done.md) cho criteria chi tiết):
- ✅ **Gate G0/G1/G2/G3 pass** đúng thứ tự (không skip stage)
- ✅ 7 dim đều có audit report đầy đủ 8 sections
- ✅ ≥ 30 findings tổng cộng với file:line evidence
- ✅ ≥ 80% findings có reproducible test case (fixtures/)
- ✅ Roadmap có ≥ 10 P0/P1 IMPs với `evidence_status: verified`
- ✅ Cross-cutting issues consolidate ≥ 5 themes verified từ ≥2 dim per theme
- ✅ Stage 4 re-audit cho thấy precision/recall improvement
- ✅ Sync vào `wf-fix-{dim}/evals/evals.json` xong (DEC-006)

## 10. Liên quan

- [01-audit-methodology.md](./01-audit-methodology.md) — Phương pháp luận 5 phase
- [11-stages-and-gates.md](./11-stages-and-gates.md) — Stage architecture canonical
- [12-decisions-log.md](./12-decisions-log.md) — Quyết định DEC-001 đến DEC-006
- [13-definition-of-done.md](./13-definition-of-done.md) — DoD criteria per gate
- [fixtures/README.md](./fixtures/README.md) — Test fixture catalog
- [progress.md](./progress.md) — Tracker tiến độ
- Original skill plan: `plans/wf-fix-bugs-v7/`
- ADRs: `plans/wf-fix-bugs-v7/02-target-architecture.md`
