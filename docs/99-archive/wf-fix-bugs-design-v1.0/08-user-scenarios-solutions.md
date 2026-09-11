# 08 — User Scenarios & Operational Design

> **Đọc trước:** [05-execution-profiles.md](05-execution-profiles.md), [06-migration-plan.md](06-migration-plan.md)
> **Đọc tiếp:** [07-tradeoffs-adr.md](07-tradeoffs-adr.md) (các ADR sẽ được bổ sung: ADR-14 → ADR-20)
> **Trạng thái:** DRAFT — mở rộng thiết kế dựa trên 6 yêu cầu thực tế của người dùng + các góc nhìn operational bổ sung.

Tài liệu này trả lời câu hỏi: **"Khi một người dùng thật sự chạy `/wf-fix-bugs` cho một ERP module 20-30 menu, hoặc 2 dev chia nhau chạy rồi đồng bộ qua git, skill phải cư xử như thế nào?"** Nó mở rộng 7 file design trước đó bằng cách tập trung vào *operational experience* thay vì kiến trúc/contract.

Mỗi section có dạng **R# — Yêu cầu → Phân tích → Giải pháp đề xuất → Ảnh hưởng tới các file design khác**.

---

## 1. Tóm Tắt 6 Yêu Cầu Gốc

| # | Yêu cầu | Điểm cốt lõi |
|---|---------|--------------|
| **R1** | Người dùng chọn QD trước khi chạy — có bảng tick + recommend | UX-first, không bắt nhớ cú pháp flag |
| **R2** | Module lớn (20-30 menu, nhiều feature/menu) — skill tự phát hiện "đây là job lớn" + tự chia nhỏ + cho phép nhiều phiên chạy song song đạt 100% coverage | Workload estimation + partitioning + multi-session parallelism |
| **R3** | `--resume` phải dùng được **bất cứ lúc nào** — không bao giờ phải chạy lại từ đầu | Robust checkpointing mọi layer, bao gồm cả giữa một probe |
| **R4** | Song song hoá tối đa — spawn agent, parallel task | Lane parallel + intra-lane probe parallel |
| **R5** | Kiểm tra logic **chéo module** — sửa một nơi phải verify module/feature liên quan | Cross-module impact graph + cross-ref verification |
| **R6** | **Tái sử dụng kết quả phiên trước** — không scan lại những gì đã scan, đặc biệt khi 2 dev chia việc + đồng bộ qua git | Scan cache + incremental + team collaboration via git-friendly artifacts |

R6 được đánh giá **mức độ quan trọng cao nhất** — không có nó thì skill không scale được cho ERP thật.

---

## 2. Mở Rộng Góc Nhìn — 7 Scenario Bổ Sung

Ngoài 6 yêu cầu trên, các tình huống sau rất có khả năng xảy ra và cần được thiết kế sẵn:

| # | Scenario | Tại sao cần lưu ý |
|---|----------|-------------------|
| **S7** | **Crash/power loss giữa chừng** | Phiên kéo dài 45-120 phút, người dùng cần bật lại máy và tiếp tục |
| **S8** | **Progress visibility + ETA** | User không muốn nhìn thanh "thinking..." 30 phút mà không biết còn bao lâu |
| **S9** | **Token/time budget burn alert** | ERP exhaustive profile có thể tiêu tốn 200K+ token — cần cảnh báo trước khi đụng giới hạn |
| **S10** | **Scope drift khi codebase thay đổi giữa session** | User commit code mới khi phiên đang chạy → kết quả có còn đúng? |
| **S11** | **Conflict khi 2 dev cùng chạy cùng module cùng lúc** | File output có collision không? Dev nào "win"? |
| **S12** | **Partial trust của kết quả legacy** | Module legacy scan được 1 năm trước — dữ liệu cũ có còn dùng được không? |
| **S13** | **Audit trail cho compliance** | ERP tài chính cần log ai đã chạy fix gì, khi nào, thay đổi ra sao — SOX/ISO |

---

## 3. R1 — Interactive QD Selection với Recommendation

### 3.1 Phân tích UX

Cú pháp hiện đang mô tả `--dims=QD3,QD5` là power-user CLI. Trong thực tế:

- Người dùng **không nhớ** QD1..QD7 nghĩa là gì nếu không mở docs.
- Người dùng **muốn được đề xuất** — "hiện tại module của bạn mới sửa auth → nên chạy QD3 (Security)".
- Người dùng có thể muốn **khoá/mở nhiều lựa chọn** cùng lúc.

### 3.2 Giải pháp — Interactive Selection Gate (ISG)

Khi user chạy `/wf-fix-bugs` **không kèm** flag dim nào → orchestrator mở **ISG — Interactive Selection Gate** trước khi khởi chạy:

```
┌──────────────────────────────────────────────────────────────────────┐
│  /wf-fix-bugs — Chọn chiều chất lượng cần kiểm tra                   │
│                                                                      │
│  Scope phát hiện: module=finance, features=27, files_changed=14      │
│  Profile đề xuất: standard (≈15-20 phút)                             │
│                                                                      │
│  [x] QD1 Functional — spec vs behavior                    🟢 RECOMMEND│
│  [ ] QD2 Business   — domain rules (finance/ERP)          🟡 khuyến nghị│
│  [x] QD3 Security   — auth, injection, secrets             🟢 RECOMMEND│
│  [ ] QD4 Performance — CWV, query, bundle                 ⚪ tuỳ chọn  │
│  [x] QD5 UX/A11y    — WCAG, UX heuristics                 🟢 RECOMMEND│
│  [ ] QD6 Data       — validation, integrity, concurrency  🟡 khuyến nghị│
│  [ ] QD7 Compat     — browser, responsive, i18n           ⚪ tuỳ chọn  │
│                                                                      │
│  Lý do recommend:                                                    │
│   • QD1+QD5 = mặc định standard                                      │
│   • QD3 → git diff có sửa file auth/* trong 7 ngày qua               │
│   • QD6 → module `finance` nhạy với dữ liệu (nhắc tích thêm)         │
│                                                                      │
│  [Enter]=xác nhận  [a]=tích tất cả  [r]=chỉ recommend                │
│  [p]=đổi profile   [s]=skip (dùng default)  [q]=huỷ                  │
└──────────────────────────────────────────────────────────────────────┘
```

**Engine recommend** đọc các nguồn theo ưu tiên:

1. **Git diff 7 ngày** — file đụng vào `auth/`, `security/`, `crypto/` → tick QD3.
2. **Preflight report** (nếu có) — có WARN/FAIL ở dim nào → tick dim đó.
3. **Sprint tag / commit message** — có tag `perf`, `perf-optimization` → gợi ý QD4.
4. **Module metadata** — module thuộc domain `finance`/`healthcare`/`banking` → QD6 marked 🟡 khuyến nghị.
5. **LEGACY_MODE** — có `legacy-scan` → gợi ý QD6 (data integrity rủi ro cao) + QD1.
6. **Fallback** — profile default.

### 3.3 Vẫn giữ CLI-first cho power user

- `--dims=QD3,QD5` hoặc `--only=security` → **bỏ qua ISG**, chạy ngay.
- `--auto` → tự áp dụng recommend mà không hỏi.
- `--interactive` (default khi thiếu flag) → mở ISG.
- `--no-interactive` → bắt buộc dùng profile default, không hỏi.

### 3.4 Ảnh hưởng tới design khác

- **04-contracts-data-model.md §4 Profile Config** bổ sung trường `recommendation_rules` (map: trigger source → suggested dims).
- **05-execution-profiles.md §3** thêm `3.4 Interactive Selection Gate` sau §3.3 Auto-detect.
- **07-tradeoffs-adr.md** — ADR-14 "Interactive Selection Gate là default khi không có dim flag".

---

## 4. R2 — Workload Partitioning + Multi-Session Parallelism (100% Coverage)

### 4.1 Phân tích — "Phiên này có nổi không?"

Ví dụ thực tế:

- Module `finance` có 6 sub-menu, mỗi sub-menu 4-8 feature → tổng **≈35 feature**.
- Profile `deep` × 7 QD × 35 feature × runtime probe (Playwright) = **ước tính 3-5 giờ** → không khả thi trong 1 phiên.

Pipeline v6 cần tự phát hiện và đưa ra quyết định **thay vì để user đoán**.

### 4.2 Giải pháp — Workload Estimator + Partition Planner

#### 4.2.1 Workload Estimator (chạy ở Phase 0)

Sau khi chốt `scope × profile × dims`, orchestrator tính trước khi spawn lane:

```
W = Σ_d∈dims Σ_f∈features (probe_count_d × probe_cost_d(profile))
```

Nếu `W > soft_cap(profile)` (mặc định `soft_cap = 1.5 × profile.time_budget_minutes`):

→ Orchestrator **đưa ra Workload Gate** hỏi user:

```
┌────────────────────────────────────────────────────────────────────┐
│ ⚠️  Workload lớn phát hiện                                          │
│                                                                    │
│ Ước tính: 35 features × 5 dims × deep profile ≈ 210 phút           │
│ Profile budget: 45 phút (deep)                                     │
│ Tỷ lệ vượt budget: 4.7×                                            │
│                                                                    │
│ Đề xuất phân chia:                                                 │
│   Plan A — chia theo sub-menu (6 phần, mỗi phần ~35 phút)          │
│     Phù hợp: muốn chạy từng chunk theo tuần                        │
│                                                                    │
│   Plan B — chia theo dim (5 session, mỗi session 1 dim)            │
│     Phù hợp: muốn chạy song song trên nhiều máy                    │
│                                                                    │
│   Plan C — downgrade profile từ deep → standard (~60 phút)         │
│     Phù hợp: chấp nhận coverage nông hơn đổi lấy 1 phiên           │
│                                                                    │
│   Plan D — giữ nguyên (>3h một phiên — KHÔNG khuyến nghị)          │
│                                                                    │
│  Chọn: [A] [B] [C] [D]                                             │
└────────────────────────────────────────────────────────────────────┘
```

#### 4.2.2 Partition Planner — Sinh "fix-workload.json"

Nếu user chọn Plan A hoặc B, orchestrator sinh file `fix-workload.json` tại gốc module:

```json
{
  "workload_id": "wl-finance-20260420-001",
  "strategy": "sub-menu",
  "target_scope": { "system": "erp", "module": "finance" },
  "dims": ["QD1", "QD3", "QD5"],
  "profile": "deep",
  "created_by": "it@erktransport.com",
  "created_at": "2026-04-20T09:30:00+07:00",
  "chunks": [
    {
      "chunk_id": "ch-001",
      "label": "finance/ap",
      "scope": { "system": "erp", "module": "finance/ap" },
      "features": ["FEAT-FIN-AP-001", "FEAT-FIN-AP-002", "..."],
      "est_time_minutes": 35,
      "status": "pending",
      "assigned_to": null,
      "session_dir": null
    },
    { "chunk_id": "ch-002", "label": "finance/ar", "...": "..." }
  ],
  "coverage_target": "100%",
  "dedup_key_strategy": "issue_hash_v2"
}
```

Mỗi chunk là một **đơn vị chạy được độc lập** trong một phiên `/wf-fix-bugs`.

#### 4.2.3 Multi-Session Parallel Execution

User chạy chunk:

```
# Máy 1 hoặc tab 1
/wf-fix-bugs --workload=wl-finance-20260420-001 --chunk=ch-001

# Máy 2 hoặc tab 2 (song song)
/wf-fix-bugs --workload=wl-finance-20260420-001 --chunk=ch-002
```

Hoặc auto-pick chunk tiếp theo:

```
/wf-fix-bugs --workload=wl-finance-20260420-001 --chunk=next
```

- Mỗi chunk khi bắt đầu → set `status=in_progress` + `assigned_to=<user>@<host>` + `session_dir=<path>` (atomic via file-lock).
- Kết thúc → `status=done` + append `issue_count`, `fixed_count` vào chunk record.
- Chunk fail/crash → timeout 2× est_time thì `status=stale` (cho phép session khác pick lại).

#### 4.2.4 Workload Aggregator

Sau khi toàn bộ chunks `done`, user chạy:

```
/wf-fix-bugs --workload=wl-finance-20260420-001 --aggregate
```

→ Orchestrator gộp `issue-registry.json` từ mọi chunk → sinh `workload-report.md` (coverage 100%, cross-chunk dedup, cross-module impact list).

### 4.3 Ảnh hưởng tới design khác

- **04-contracts-data-model.md** — thêm §15 `fix-workload.json` schema v1.
- **05-execution-profiles.md** — thêm §15 Workload Gate + Multi-Session Workflow.
- **00-core.md §4b** — thêm path: `.mc-data/work/wf-fix-bugs/workloads/<workload-id>/fix-workload.json`.
- **07-tradeoffs-adr.md** — ADR-15 "Workload Gate + Partition Planner (strategy: sub-menu / dim / file)".

---

## 5. R3 — Resume Everywhere (Bất Cứ Lúc Nào)

### 5.1 Phân tích — 4 cấp resume

V5 đã có `--resume` nhưng chỉ ở cấp phase. V6 cần **4 cấp checkpoint**:

| Cấp | Đối tượng | File | Granularity |
|-----|-----------|------|-------------|
| **L0 Phase** | Discovery/Triage/Fix/Verify | `fix-status.json` | Resume vào đúng phase |
| **L1 Lane** | Per-dimension lane | `lanes/<dim>/lane-status.json` | Resume vào đúng lane |
| **L2 Probe** | Probe trong lane | `lanes/<dim>/probe-progress.json` | Resume vào probe chưa chạy |
| **L3 Intra-probe** | Feature/file đang scan | `lanes/<dim>/probes/<probe-id>/partial.json` | Resume vào feature/file kế tiếp |

### 5.2 Giải pháp — Hierarchical Checkpoint

Mỗi layer ghi checkpoint theo rule:

- **Tần suất ghi:** sau mỗi unit of work (1 feature, 1 file, 1 URL). Throttle: tối thiểu 5 giây giữa hai lần ghi để không I/O storm.
- **Atomic write:** `write temp → fsync → rename` (CORE-030).
- **Format:** đơn giản, JSON flat, tối đa 2 tầng — để resume logic dễ diff.

`fix-status.json v6` trường mới:

```json
{
  "schema": "fix-status-v6",
  "active_phase": "lanes_running",
  "resume_pointer": {
    "level": "L3",
    "lane": "QD3",
    "probe_id": "P3.02-semgrep",
    "scanned_features": ["FEAT-FIN-AP-001", "FEAT-FIN-AP-002"],
    "next_feature": "FEAT-FIN-AP-003",
    "last_checkpoint_at": "2026-04-20T09:42:11Z"
  },
  "lanes": {
    "QD1": { "status": "done", "finished_at": "..." },
    "QD3": { "status": "partial", "last_probe": "P3.02-semgrep" },
    "QD5": { "status": "pending" }
  }
}
```

### 5.3 Resume Routing Chi Tiết

```
/wf-fix-bugs --resume
   │
   ├─ [L0] đọc active_phase → jump vào đúng phase
   │    │
   │    └─ nếu lanes_running:
   │         ├─ [L1] for each lane in lanes:
   │         │    ├─ status=done → skip
   │         │    ├─ status=partial → goto L2
   │         │    └─ status=pending → start từ đầu
   │         │
   │         └─ [L2] load probe-progress.json:
   │              ├─ probe_done[] → skip
   │              ├─ probe_partial → goto L3
   │              └─ probe_pending → chạy từ đầu probe
   │
   └─ [L3] load partial.json → next_feature → tiếp tục
```

### 5.4 Nguyên tắc "never lose more than 1 unit"

Checkpoint bắt buộc sau mỗi:
- Hoàn thành 1 feature (intra-probe).
- Hoàn thành 1 probe (intra-lane).
- Hoàn thành 1 lane (inter-lane).
- Signal Bus flush (inter-lane aggregation).

Crash / Ctrl+C / network drop → mất **tối đa 1 feature** (vài chục giây công việc).

### 5.5 Ảnh hưởng tới design khác

- **03-architecture.md** — mở rộng sequence diagram với checkpoint hooks.
- **04-contracts-data-model.md §9** — bổ sung `probe-progress.json` + `partial.json` schemas.
- **07-tradeoffs-adr.md** — ADR-16 "4-level checkpoint hierarchy + never-lose-more-than-1 rule".

---

## 6. R4 — Parallel Agent Spawning Strategy

### 6.1 Phân tích — 3 trục song song

Pipeline v6 có thể song song ở **3 trục độc lập**:

| Trục | Ví dụ | Giới hạn hợp lý |
|------|-------|-----------------|
| **Inter-lane** | Chạy QD1 + QD3 + QD5 cùng lúc | 3 (ADR-05) |
| **Intra-lane probe** | Trong QD5, chạy static + runtime + agent-review song song | 2-4 per lane |
| **Intra-probe fanout** | Trong probe P1.03 "spec-vs-code diff", fanout 10 feature → 10 sub-task | 5-8 per probe |

Tối đa lý thuyết: 3 lane × 3 probe × 5 fanout = **45 concurrent task**. Thực tế nên capped ở **10-15** để agent/context không vỡ.

### 6.2 Giải pháp — 3-Tier Concurrency Controller

Thêm module `_shared/concurrency-controller.js` quản lý:

```yaml
global_max: 12           # hard cap, không vượt được
per_lane_max: 4          # mỗi lane tối đa 4 parallel task
per_probe_max: 6         # mỗi probe fanout tối đa 6
reserved_for_fixer: 2    # luôn giữ 2 slot cho Fixer (verify loop)
```

Controller dùng **token bucket** — mỗi spawn tốn 1 token; complete trả lại. Nếu cạn → queue + FIFO.

### 6.3 Điều kiện spawn (CORE-025 compliance)

Một probe được phép spawn parallel **chỉ khi**:

1. `probe.manifest.parallel_safe: true` (declare trong `dimension.json`).
2. Write scope tách biệt — mỗi sub-task ghi vào `lanes/<dim>/probes/<pid>/shards/<idx>.json`.
3. Shard không đọc lẫn nhau trong khi ghi.
4. Có aggregator verify sau khi merge (Signal Bus POST-GATE).

Probe `parallel_safe: false` (ví dụ: E2E flow cần state) → luôn sequential.

### 6.4 Progress reporting

Mỗi task spawn → publish event vào `lanes/<dim>/events.jsonl`:

```
{"ts":"...","event":"spawn","task":"...","parent":"..."}
{"ts":"...","event":"complete","task":"...","duration_ms":1234}
```

Dashboard/CLI đọc stream này để render thanh tiến độ real-time.

### 6.5 Ảnh hưởng tới design khác

- **03-architecture.md** — thêm concurrency controller vào component diagram.
- **04-contracts-data-model.md §4** — `profiles.json` thêm field `concurrency_caps`.
- **07-tradeoffs-adr.md** — ADR-17 "3-tier concurrency (inter-lane/intra-lane/intra-probe) với token bucket".

---

## 7. R5 — Cross-Module Impact Analysis

### 7.1 Phân tích — "Sửa một nơi, vỡ nơi khác"

Ví dụ ERP: sửa `CustomerService` trong module `crm/customer` → ảnh hưởng tới `order/invoice` (đọc customer_id), `finance/ar` (aging), `reporting/sales` (join customer).

Pipeline v5 chỉ verify trong phạm vi scope đang fix. V6 cần:

- **Discover giai đoạn** — build **Impact Graph** từ registry + code (import/export, DB relationship, event subscription, REQ-ID cross-ref).
- **Triage giai đoạn** — mỗi Issue được tag `impact_fanout: [module:feature, ...]`.
- **Fix giai đoạn** — sau fix, Verifier bắt buộc re-run probes **cho cả impact fanout**, không chỉ feature bị fix.

### 7.2 Giải pháp — Impact Graph + Verification Ripple

#### 7.2.1 Impact Graph Builder (Discovery Phase 1c)

Một probe mới `P0.XREF` (cross-reference) chạy ở Discovery, sinh `impact-graph.json`:

```json
{
  "schema": "impact-graph-v1",
  "nodes": [
    { "id": "FEAT-CRM-CUST-001", "module": "crm/customer", "files": ["..."] }
  ],
  "edges": [
    {
      "from": "FEAT-CRM-CUST-001",
      "to": "FEAT-FIN-AR-003",
      "relation": "data_dependency",
      "evidence": "invoice.customer_id FK → customer.id",
      "strength": 0.9
    },
    {
      "from": "FEAT-CRM-CUST-001",
      "to": "FEAT-REPORT-SALES-002",
      "relation": "entity_reference",
      "strength": 0.6
    }
  ]
}
```

Quan hệ detect bằng:
- **Code import/export** — AST parse.
- **REQ-ID cross-ref** — `// REQ-ID: REQ-A; USES: REQ-B`.
- **DB schema** — FK relationship.
- **Event bus subscription** — đọc config/decorators.
- **API call** — runtime trace (optional).

#### 7.2.2 Verification Ripple

Khi Fixer sửa Issue cho feature F:

1. Lookup `impact-graph.json` → lấy neighbors {F', F'', ...}.
2. Verifier re-run probes của neighbors (scope giới hạn bởi selected_dims).
3. Nếu neighbor issue xuất hiện mới → `ripple_regression: true` → upgrade severity + ghi `fix-log.json`.

#### 7.2.3 User-facing flag

- `--no-ripple` → tắt (debug/quick).
- `--ripple-depth=N` → giới hạn tầng ripple (default 1).
- `--ripple-strength=0.7` → chỉ verify edge có strength ≥ threshold.

### 7.3 Ảnh hưởng tới design khác

- **02-quality-dimensions.md** — thêm "cross-dimension probe" P0.XREF thuộc shared utility.
- **04-contracts-data-model.md** — thêm §16 `impact-graph.json` schema.
- **07-tradeoffs-adr.md** — ADR-18 "Cross-module impact graph + verification ripple (default depth=1)".

---

## 8. R6 — Scan Cache + Incremental + Team Collaboration (★ Quan trọng nhất)

### 8.1 Phân tích thực tế

Câu chuyện user đưa ra:
- Lần 1: chạy module `finance` cho sub-menu A, B, C.
- Lần 2 (2 ngày sau): muốn chạy sub-menu D, E, F nhưng code A, B, C không đổi.
- Lần 3: dev khác chạy lại A, B, C để verify — không nên scan lại từ đầu nếu không có code change.
- Lần 4: 2 dev chia việc chạy A, B, C / D, E, F → push git → dev 3 pull → chạy aggregate.

Mấu chốt: **chi phí scan lại code không đổi = 0 lợi ích, 100% lãng phí**.

### 8.2 Giải pháp — Scan Fingerprint Cache + Git-Friendly Artifacts

#### 8.2.1 Scan Fingerprint (content-addressable)

Mỗi probe khi hoàn thành trên input X sinh:

```
fingerprint = SHA256(
  probe_id || probe_version ||
  profile_depth || probe_config_hash ||
  input_hash(X) || dependency_closure_hash(X)
)
```

Trong đó:
- `input_hash(X)` = SHA256 của file/feature content.
- `dependency_closure_hash(X)` = hash của toàn bộ file mà X import transitively (tối đa 2 tầng, whitelist extensions).

Kết quả probe được cache vào `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json`:

```json
{
  "fingerprint": "sha256:ab12cd...",
  "probe_id": "P3.02-semgrep",
  "input": { "feature": "FEAT-FIN-AP-003", "files": ["..."] },
  "signals": [...],
  "produced_at": "2026-04-20T09:45:00Z",
  "produced_by": "it@erktransport.com@host-01",
  "ttl_days": 14,
  "invalidation_hints": ["file_hash_change", "probe_config_change"]
}
```

Khi probe sắp chạy:

```
fingerprint = compute()
IF cache_hit AND not expired AND not user --no-cache:
  → emit cached signals
  → ghi log "cache_hit: probe=P3.02 feature=FEAT-FIN-AP-003"
  → tiết kiệm thời gian
ELSE:
  → chạy probe, ghi cache
```

#### 8.2.2 Invalidation Rules

Cache tự invalidate khi:

1. **File hash đổi** — input file SHA khác.
2. **Dependency closure đổi** — file imported thay đổi.
3. **Probe version bump** — `dimension.json` của lane bump version.
4. **Probe config hash đổi** — rule set / threshold thay đổi.
5. **TTL expire** — mặc định 14 ngày.
6. **User force** — `--no-cache` hoặc `--invalidate-cache=<pattern>`.

#### 8.2.3 Git-Friendly Cache (team collaboration)

Cache store ở **2 tầng**:

| Tầng | Vị trí | Git | Đối tượng |
|------|--------|-----|-----------|
| **Session cache** | `.mc-data/work/wf-fix-bugs/sessions/.../cache/` | Trong `.gitignore` | Per-session, ephemeral |
| **Project cache** | `.mc-data/cache/wf-fix-bugs/` | **Commit vào git** (opt-in) | Shared team artifacts |

Project cache được thiết kế **git-friendly**:
- Một file per fingerprint → diff nhỏ.
- Không có timestamp trong filename (đã có trong content).
- Không có absolute path (dùng relative từ repo root).
- Deterministic JSON key order (stable sort).

Khi dev A push cache, dev B pull:

```
dev A: /wf-fix-bugs --scope=module --name=finance/ap --dims=QD1,QD3
       → cache filled at .mc-data/cache/wf-fix-bugs/probes/*.json
       → git add .mc-data/cache/wf-fix-bugs/
       → git commit -m "fix-bugs cache: finance/ap QD1+QD3"
       → git push

dev B: git pull
       /wf-fix-bugs --scope=module --name=finance/ar --dims=QD1,QD3
       → detect cache hits cho code chưa đổi (có thể scanner shared utility đã scan)
       → skip probes không cần thiết
       → scan chỉ finance/ar thật sự
```

#### 8.2.4 Workload-aware cache (liên kết với R2)

Kết hợp cache với `fix-workload.json`:

```
/wf-fix-bugs --workload=wl-finance-20260420-001 --aggregate --use-cache
```

- Aggregate step query toàn bộ fingerprint đã run trong workload này.
- Detect "overlap" giữa chunks (nếu có shared files).
- Emit `workload-report.md` với mục "cache utilization: X% probe calls served from cache".

#### 8.2.5 Incremental mode

User có thể chạy:

```
/wf-fix-bugs --incremental --since=HEAD~5
```

→ Orchestrator:
1. `git diff HEAD~5 HEAD --name-only` → lấy file changed.
2. Build input set = features touching these files (via `impact-graph.json`).
3. Chạy probes chỉ cho input set này.
4. Merge kết quả với cache cũ cho các phần không đổi.
5. Sinh report đầy đủ (covers 100% coverage target trong module dù chỉ scan phần diff).

#### 8.2.6 Merge strategy cho 2 dev conflict

Nếu dev A và dev B cùng update cache cho cùng fingerprint:

- **CRDT-friendly**: fingerprint trùng → nội dung **phải** trùng (content-addressable by design). Nếu conflict hash-level → lỗi → cảnh báo probe không deterministic.
- **fix-history.md** merge: append-only + sort theo timestamp → git rất dễ merge.
- **workload registry**: chunk ownership dùng file lock trên `.mc-data/work/.../workload.lock` → CLI hint: "dev B đang chạy chunk ch-003, hãy chọn chunk khác".

### 8.3 Audit + Privacy

- Cache có thể chứa code snippets. Dev lead chọn opt-in commit vào git.
- File cache có `privacy_scope: public|internal|secret`. Secrets-related signals (e.g., P3.01) **không** cache → luôn rescan.
- Audit trail: `fix-history.md` ghi ai đã tạo/đọc cache entry.

### 8.4 Ảnh hưởng tới design khác

- **00-core.md §4b** — thêm path contract:
  - `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json` (project cache)
  - `.mc-data/work/wf-fix-bugs/workloads/<workload-id>/fix-workload.json`
- **04-contracts-data-model.md** — thêm §17 Scan Cache Schema + §18 Invalidation Rules.
- **06-migration-plan.md** — thêm Phase 4.5 "Scan Cache Enablement" (opt-in trong v6.0, default on trong v6.1).
- **07-tradeoffs-adr.md** — ADR-19 "Scan Cache with content-addressable fingerprint + git-friendly storage" + ADR-20 "Incremental mode via --since=<git-ref>".

---

## 9. S7-S13 — Giải Pháp Ngắn Cho Scenario Bổ Sung

| # | Scenario | Giải pháp tóm tắt |
|---|----------|-------------------|
| **S7** | Crash/power loss | Checkpoint hierarchy (§5) + atomic write + `--resume` auto-discover latest session |
| **S8** | Progress + ETA | Events stream `events.jsonl` → CLI live renderer; ETA = remaining_tasks × moving_avg_duration |
| **S9** | Budget burn alert | Budget Guard (05 §2.2) expanded: soft alert 70%, hard prompt 90%, block 100%; user có thể approve extend |
| **S10** | Scope drift mid-session | Orchestrator ghi `repo_hash` ở start; nếu user commit code giữa phiên → warning + offer restart scope hoặc accept drift |
| **S11** | 2 dev cùng module cùng lúc | File lock trên `workload.lock`; chunk assignment atomic; chunk đang `in_progress` không pick được |
| **S12** | Stale legacy scan | Cache TTL + `--invalidate-cache="legacy-*"`; option `--refresh-stale` |
| **S13** | Audit trail | `fix-history.md` append-only; mỗi entry có `user`, `host`, `git_commit`, `session_id`, `actions[]` — đủ cho SOX/ISO audit |

---

## 10. Tổng Hợp Components Mới

So với design 01-07, tài liệu này giới thiệu thêm các components:

| Component | Vị trí dự kiến | Mục đích |
|-----------|----------------|----------|
| **Interactive Selection Gate (ISG)** | Orchestrator preamble | UX chọn QD + profile trước khi chạy |
| **Recommendation Engine** | `_shared/reco-engine/` | Sinh recommend dựa trên git/preflight/domain |
| **Workload Estimator** | Orchestrator Phase 0 | Ước tính W, trigger Workload Gate |
| **Workload Gate (UI)** | Orchestrator preamble | User pick partition plan |
| **Partition Planner** | `_shared/partition-planner/` | Sinh `fix-workload.json` |
| **Workload Aggregator** | Orchestrator (aggregate mode) | Gộp kết quả multi-chunk |
| **4-Level Checkpoint Writer** | Mọi lane + orchestrator | Hierarchical resume |
| **Concurrency Controller** | `_shared/concurrency/` | 3-tier token bucket |
| **Impact Graph Builder** | Shared probe P0.XREF | Cross-module relationship |
| **Verification Ripple** | Verifier service extension | Re-run probes theo graph |
| **Scan Cache** | `_shared/scan_cache/` + `.mc-data/cache/` | Content-addressable result cache |
| **Incremental Runner** | Orchestrator mode | Scan diff-only + merge với cache |

---

## 11. Tác Động Lên Các File Design Hiện Tại

| File | Cần cập nhật | Chi tiết |
|------|--------------|----------|
| **README.md** | Mục lục, Quick Ref, Next Actions | Thêm 08 vào toc, thêm ISG/Workload/Cache vào §4 |
| **01-vision-principles.md** | Thêm P12 "Cache + Reuse First" | Không scan lại những gì đã scan |
| **02-quality-dimensions.md** | Thêm probe P0.XREF (shared) | Cross-module impact |
| **03-architecture.md** | Thêm component diagrams cho ISG/Workload/Cache/Ripple | Update sequence |
| **04-contracts-data-model.md** | Thêm §15-§18 schemas | fix-workload, impact-graph, scan-cache, invalidation |
| **05-execution-profiles.md** | Thêm §3.4 ISG, §15 Workload, §16 Incremental | Chi tiết UX flows |
| **06-migration-plan.md** | Thêm Phase 4.5 Cache enablement | Sequence rollout |
| **07-tradeoffs-adr.md** | Thêm ADR-14 → ADR-20 | 7 ADR mới (ISG, Workload, Checkpoint, Concurrency, Impact, Cache, Incremental) |
| **.claude/rules/00-core.md §4b** | Thêm path contracts | 3-4 dòng mới (workload, cache, impact-graph) |

---

## 12. Roadmap — Công Việc Tiếp Theo Sau Design

Design phase (tổng 8 file) đã đủ để **fix ngữ nghĩa và contract**. Các giai đoạn kế tiếp:

### Giai đoạn A — Design Closure (1-2 tuần)

- **A1**: Review toàn bộ 8 file, resolve 6 Open Questions trong 07 §14 + các OQ mới từ 08 (ISG auto vs prompt, cache opt-in default, ripple depth).
- **A2**: Cập nhật các file 01-07 theo tác động từ 08 (§11 bảng trên).
- **A3**: Cập nhật `.claude/rules/00-core.md §4b` với các path contract mới (workload, cache, impact-graph).
- **A4**: Sign-off từ owner (Eureka + DEVKIT core team).
- **Deliverable**: Design v1.0 (từ v0.1 DRAFT).

### Giai đoạn B — Skeleton Implementation (2-3 tuần)

- **B1**: Tạo skeleton folder `.claude/skills/workflow/wf-fix-functional/` + `wf-fix-security/` + `_shared/` (chưa cần logic thật).
- **B2**: Impl `_shared/signal_bus/` với schema signal-v1 + dedup + POST-GATE.
- **B3**: Impl `_shared/concurrency-controller/` (token bucket).
- **B4**: Impl `_shared/scan_cache/` core (compute fingerprint + get/put).
- **B5**: Impl orchestrator v6 preamble: ISG + Workload Gate + Budget Guard.
- **B6**: Impl 4-level checkpoint writer utility.
- **Deliverable**: Framework chạy được nhưng chưa phát hiện bug thực — mock probe.

### Giai đoạn C — Bellweather Lanes (2-3 tuần)

- **C1**: Impl `wf-fix-functional` (QD1) full — 5-7 probes, golden fixture.
- **C2**: Impl `wf-fix-security` (QD3) full — 4-6 probes, CDG integration.
- **C3**: Tích hợp Impact Graph Builder (probe P0.XREF) + Verification Ripple.
- **C4**: End-to-end test trên project MCV3 tự thân + 1 ERP module mẫu.
- **Deliverable**: v6.0-alpha — 2/7 lane hoạt động thực.

### Giai đoạn D — Remaining Lanes + Parallel Features (3-4 tuần)

- **D1-D5**: Impl QD5 → QD6 → QD4 → QD2 → QD7 (theo priority trong 06 §3).
- **D6**: Impl Workload Partition Planner + Aggregator.
- **D7**: Impl Incremental Mode (`--since=<git-ref>`).
- **D8**: Impl Scan Cache git-friendly layer + opt-in commit.
- **Deliverable**: v6.0-beta — full 7 lane + multi-session + cache.

### Giai đoạn E — Golden Suite + Evaluation (parallel với C + D)

- **E1**: Build golden fixtures per dimension (50+ bug injected).
- **E2**: Eval harness (`/wf-fix-bugs --golden=<fixture>`) → đo M1-M8 trong README §7.
- **E3**: Baseline measurement vs v5.1.0.
- **E4**: CI job chạy golden suite mỗi PR.
- **Deliverable**: Quality bar quantified.

### Giai đoạn F — Migration + Cutover (1-2 tuần)

- **F1**: Migration helper `migrate-v1-to-v2.sh` (issue-registry).
- **F2**: v5→v6 wrapper: `--engine=v5|v6`, default v5 → chuyển default v6.
- **F3**: Update `wf-fix-bugs` orchestrator delegate sang v6.
- **F4**: Deprecate + remove `wf-fix-discover`, `wf-fix-triage`, `wf-fix-execute` (v6.2.0).
- **F5**: Update user docs trong `docs/project-description.md` + `CLAUDE.md`.
- **Deliverable**: v6.1 stable.

### Giai đoạn G — Documentation + Training (parallel với F)

- **G1**: User guide cho non-technical (hướng dẫn ISG, Workload, cache).
- **G2**: Dev guide cho plugin author ("thêm dimension mới trong 2 ngày").
- **G3**: Troubleshooting runbook cho 10 tình huống thường gặp.
- **G4**: Migration guide cho existing users.
- **Deliverable**: Docs complete.

### Timeline tổng

```
Tháng 1 (W1-W2):  A1-A4 (Design closure)
Tháng 1 (W3-W4):  B1-B6 (Skeleton)
Tháng 2 (W5-W6):  C1-C4 (Bellweather)
Tháng 2 (W7-W8):  E1-E2 start + D1-D2
Tháng 3 (W9-W10): D3-D5
Tháng 3 (W11-W12): D6-D8 + E3-E4
Tháng 4 (W13-W14): F1-F5 + G1-G4
```

Tổng ước lượng: **14 tuần** từ design closure tới v6.1 stable.

---

## 13. Quick Decision Matrix — Đã Khoá (v1.0)

★ **Trạng thái:** Tất cả Q14-Q23 đã được chốt. Chi tiết căn cứ và rationale xem [09-design-decisions.md §3](09-design-decisions.md).

Quyết định được lấy theo **North Star** (lời người dùng): *"Ưu tiên đảm bảo không có lỗi logics, nghiệp vụ, và các tính năng trên giao diện phải đảm bảo hoạt động 100%. Các vấn đề khác phân tích và lựa chọn giải pháp tốt, nhưng không làm quá cồng kềnh."*

| # | Câu hỏi | **Quyết định (LOCKED v1.0)** | Ghi chú |
|---|---------|------------------------------|---------|
| **Q14** | ISG mở mặc định hay chỉ khi `--interactive`? | ✅ **Mặc định ON** (single-screen); `--no-interactive` bypass | CLI-friendly cho non-tech |
| **Q15** | Workload Gate trigger ở ngưỡng nào? | ✅ **Hard prompt ở 1.5× budget**; dead-zone < 0.8× (không prompt); soft 0.8-1.5× (warning only) | Tránh interrupt spurious |
| **Q16** | Partition strategy mặc định? | ✅ **Plan A — sub-menu** (dễ hiểu nhất). Plan B dim-split = option. **Plan D custom defer v6.1** | Giữ đơn giản |
| **Q17** | Scan cache opt-in hay default on? | ✅ **v6.0 opt-in qua `--use-cache`**; **v6.1 default on** | Correctness > speed trong v6.0 |
| **Q18** | Cache commit vào git có default không? | ✅ **Không** — opt-in qua file flag `.mc-data/cache/.git-opt-in` hoặc `--commit-cache` | Tránh leak + merge noise |
| **Q19** | Ripple depth + strength threshold? | ✅ **depth = 1, strength ≥ 0.5** (giảm từ 0.7). **Ripple always on — không cho tắt default** | Cross-module correctness là core priority |
| **Q20** | Incremental `--since` default? | ✅ **Không auto-enable**. Dùng `--incremental --since=<ref>`; nếu không có `--since` → fallback last session git hash, không có → error | User chủ động quyết định scope |
| **Q21** | Multi-session max concurrent? | ✅ **Không hard cap**. `flock(LOCK_EX \| LOCK_NB)` per SESSION_DIR lo collision; timeout 5s | Dev chia máy tự do |
| **Q22** | Cache TTL mặc định? | ✅ **14 ngày** | Đủ 1 sprint |
| **Q23** | Secrets/PII có được cache không? | ✅ **KHÔNG** — QD3 all probes `cache_policy: skip`; `evidence.secret_snippet` never cached | Safety Default non-negotiable |

**Thêm quyết định về default profile (★ ADR-21 trong 07):**

| Profile | Dim default (cũ) | **Dim default (MỚI — LOCKED)** |
|---------|------------------|--------------------------------|
| `quick` | QD1, QD3 | **QD1, QD5** |
| `standard` | QD1, QD3, QD5 | **QD1, QD2, QD5** ★ |
| `deep` | QD1-6 | **QD1, QD2, QD5, QD6, QD3** (5 dim) |
| `exhaustive` | QD1-7 | **QD1-7** (không đổi) |

**Safety Defaults non-negotiable (ADR-22):** Profile ≥ `standard` KHÔNG được phép skip toàn bộ QD1+QD2+QD5; Ripple always on; QD3 probes never cached; CDG enforced cho secrets auto-fix. Xem [09 §8](09-design-decisions.md).

---

## 14. Checklist Trước Khi Chuyển Giai Đoạn B (Skeleton)

- [x] 08 review xong.
- [x] 10 câu hỏi Q14-Q23 đã có câu trả lời (xem §13 + [09](09-design-decisions.md)).
- [x] Default profile shift (QD1+QD2+QD5) đã sync vào [05 §2](05-execution-profiles.md).
- [x] Safety Defaults non-negotiable đã khoá (xem [09 §8](09-design-decisions.md)).
- [ ] 01-07 updated minimal theo §11 (chủ yếu chỉ 05 — đã xong; 02/03/04 không đổi nội dung core).
- [ ] ADR-14 → ADR-22 đã viết vào 07 (**9 ADR** — ADR-21 default profile + ADR-22 safety defaults là mới).
- [ ] `.claude/rules/00-core.md §4b` đã patch thêm paths: `fix-workload.json`, `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json`, `$SESSION_DIR/impact-graph.json`.
- [ ] `_contract.json` skeleton cho `wf-fix-discover` / `wf-fix-triage` / `wf-fix-execute` đã cập nhật theo v6 schemas.
- [ ] Owner sign-off design v1.0.

---

## 15. Liên kết

- [README.md](README.md) — Overview + nav
- [05-execution-profiles.md](05-execution-profiles.md) — Profiles + flag mapping (đã sync default v1.0)
- [06-migration-plan.md](06-migration-plan.md) — v5→v6 roadmap
- [07-tradeoffs-adr.md](07-tradeoffs-adr.md) — ADRs (ADR-14 → ADR-22 sẽ được thêm)
- [09-design-decisions.md](09-design-decisions.md) — **Design decisions đã khoá (v1.0)** — North Star + Q14-Q23 + default profile shift + safety defaults
- `.claude/rules/00-core.md` — CORE-004/006/007/023-025/027/028/030/031
- `plans/coverage-expansion/08-erp-module-strategy.md` — Nguồn tham khảo cho multi-session ERP
