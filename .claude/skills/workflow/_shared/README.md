# `_shared/` — Utility Modules Cho `wf-fix-bugs` v6.0 + Linear Skills

> **Trạng thái:** B1 Skeleton + Phase 1 Linear Modules (2026-04-23)
> **Thuộc về:** Design v1.0 — `docs/design/skills/wf-fix-bugs/` + `docs/design/skills/ADR-downstream-skills-optimization.md`
> **Registry role:** NONE cho toàn bộ module trong thư mục này (không được ghi `req-registry.json`)
> **Ngôn ngữ:** Tài liệu tiếng Việt có dấu; tên file + API English (CORE-005)

---

## 1. Vì Sao Có Thư Mục Này

Thư mục `_shared/` chứa các **module tiện ích (utility modules)** được **các skill `wf-fix-*` gọi đến** để chia sẻ logic dùng chung. Nó **không phải một skill** — không có entry point `/_shared/...`, không được user invoke trực tiếp.

Lý do tách `_shared/` (ADR-02):

- Nhiều skill QD lane (`wf-fix-functional`, `wf-fix-business`, `wf-fix-security`, …) đều cần dedup signal, quản lý concurrency, đọc/ghi cache — nếu mỗi skill tự viết lại thì sẽ drift theo thời gian.

- Orchestrator `wf-fix-bugs` v6.0 cần một nơi trung tâm để chọn chiều (ISG), ước lượng workload, chia chunk.
- Shared protocols (`.claude/skills/protocols/`) là **rules ở tầng tài liệu**; `_shared/` là **code ở tầng thực thi** — hai lớp bổ trợ, không đè nhau.

---

## 2. Danh Sách Module (B1 Scope)

| Module | Mục đích | ADR refs | Ngôn ngữ chính |
|--------|---------|---------|----------------|
| [`isg/`](isg/README.md) | Interactive Selection Gate — cho user tick QD + recommend theo git diff/preflight/domain | ADR-14, ADR-22 rule 1 | Bash prompt + Python logic |
| [`signal_bus/`](signal_bus/README.md) | Nhận Signal từ lane → dedup + normalize → emit Issue vào `issue-registry.json` | ADR-02, ADR-04, ADR-09 | Python |
| [`concurrency/`](concurrency/README.md) | 3-tier token bucket (global 12 / inter-lane 4 / intra-probe 6) | ADR-05, ADR-17 | Python (file-based locks) |
| [`scan_cache/`](scan_cache/README.md) | Content-addressable cache cho probe result, TTL 14 ngày, QD3 never cached | ADR-19, ADR-22 rule 3 | Python |
| [`workload_estimator/`](workload_estimator/README.md) | Đếm feature/file/probe theo scope → emit `fix-workload.json` | ADR-14, ADR-15 | Python |

> **Ghi chú đặt tên (2026-04-20):** Package directory + file Python dùng **snake_case** để tương thích `import` của Python (PEP 8). JSON schema, shell script và docs vẫn dùng **kebab-case** theo convention chung của repo (CORE-016/017 — áp dụng cho tên file doc/markdown, không áp dụng cho Python importable packages).

Ngoài 5 module mới, thư mục này còn giữ file có sẵn:

- `workflow-runtime-metrics.json` — metrics runtime cross-skill (không thuộc scope B1, giữ nguyên).

---

## 4. Linear Skill Modules (Phase 1 Addition — 2026-04-23)

| Module | Mục đích | ADR refs | Used by |
|--------|---------|---------|---------|
| [`profiles/`](profiles/) | Profile system 3 cấp (quick/standard/deep) cho linear authoring | ADR-OPT-06 | analyze-req, define-features, design, design-ux, plan-modules |
| [`lane/`](lane/) | Generic lane dispatch (department/system/feature lanes) | ADR-OPT-01 | 5 linear skills |
| [`partition/`](partition/) | Generic partition planner + workload gate | ADR-OPT-03 | 4 skills (trừ brainstorm) |
| [`aggregate/`](aggregate/) | Generic signal aggregator + dedup | ADR-OPT-04 | 4 skills (trừ brainstorm) |
| [`cdg/`](cdg/) | CDG handoff tokens + anti-loop guard | ADR-OPT-08 | 5 linear skills |
| [`cache/`](cache/) | Content-hash cache adapter (2-tier: session + project) | ADR-OPT-09 | 4 skills (trừ brainstorm) |

## 5. Dual-Audience

`_shared/` phục vụ 2 nhóm skills:

- **wf-fix-\* skills** (QD-based): dùng `isg/`, `signal_bus/`, `scan_cache/`, `concurrency/`, `workload_estimator/` trực tiếp
- **wf-\* linear skills** (department/system-based): dùng `profiles/`, `lane/`, `partition/`, `aggregate/`, `cdg/`, `cache/` adapter

Không module nào xung đột — mỗi nhóm dùng sub-package riêng.

Tham chiếu chung: [`_shared.md`](_shared.md) — protocol template stripping + atomic write + import convention.

## 3. Quan Hệ Giữa Các Module

```
                  ┌──────────────────────────────┐
 User gõ          │  /wf-fix-bugs (orchestrator) │
 /wf-fix-bugs ──▶ │                              │
                  └──────────┬───────────────────┘
                             │ 1. spawn ISG (nếu không có --dims)
                             ▼
                      ┌─────────────┐
                      │    isg/     │◀────── git diff, preflight, domain hints
                      │             │
                      └──────┬──────┘
                             │ dim-selection.json
                             ▼
                  ┌──────────────────────┐
                  │ workload_estimator/  │◀─── req-registry.json + scope
                  │                      │
                  └──────────┬───────────┘
                             │ fix-workload.json
                             ▼
                  ┌──────────────────────┐
                  │ Orchestrator spawn   │
                  │ QD lane(s) song song │
                  └──────────┬───────────┘
                             │ mỗi lane acquire token
                             ▼
      ┌──────────────────────────────────────────────┐
      │                concurrency/                  │
      │  global=12 ▶ inter-lane=4 ▶ intra-probe=6    │
      └──────────────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                ▼                         ▼
         Lane probes run          Lane probes run
         (emit Signal)            (emit Signal)
                │                         │
                ▼                         ▼
             ┌─────────────────────────────┐
             │      scan_cache/            │ (opt-in --use-cache; QD3 bypass)
             │  fingerprint → hit/miss     │
             └────────────┬────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │   signal_bus/   │ ◀── all Signals aggregated
                 │  dedup+normalize│
                 └────────┬────────┘
                          │ issue-registry.json
                          ▼
                 Downstream: wf-fix-triage
```

---

## 4. Quy Tắc Chung Cho Mọi Module

### 4.1. Registry Role: NONE (BẮT BUỘC)

Không module nào trong `_shared/` được ghi `.mc-data/docs/_meta/req-registry.json`. Các module chỉ **đọc** registry (scope: `workload_estimator`, `isg`).

Ghi `impl_status` là nhiệm vụ của `/wf-fix-execute` theo quy tắc SAFE-UPDATE (xem `.claude/rules/00-core.md §4a` CORE-006/008).

### 4.2. Output Path Contract (CORE-007)

Mỗi module emit file vào path đã được khai báo trong `.claude/rules/00-core.md §4b`:

| Module | Output path | Schema file |
|--------|-------------|-------------|
| `isg/` | `$SESSION_DIR/dim-selection.json` | `isg/schemas/dim-selection.schema.json` |
| `signal_bus/` | `$SESSION_DIR/issue-registry.json` (append) | `signal_bus/schemas/issue.v2.schema.json` |
| `scan_cache/` | `.mc-data/cache/wf-fix-bugs/probes/<fingerprint>.json` | `scan_cache/schemas/cache-entry.schema.json` |
| `workload_estimator/` | `.mc-data/work/wf-fix-bugs/workloads/<workload-id>/fix-workload.json` | `workload_estimator/schemas/fix-workload.schema.json` |
| `concurrency/` | State file (ephemeral, trong `$SESSION_DIR/concurrency/`) | Không public schema |

### 4.3. Safety Defaults Non-Negotiable (ADR-22)

Mỗi module **phải** tôn trọng các default an toàn đã khoá trong [09-design-decisions.md §8](../../../../docs/design/skills/wf-fix-bugs/09-design-decisions.md). Chi tiết enforcement ở B4 (fixture tests):

1. Profile ≥ `standard` không được bỏ toàn bộ QD1+QD2+QD5 → `isg/` enforce.
2. Verification Ripple always on → `signal_bus/` không drop Issue chỉ vì không có neighbor.
3. QD3 không bao giờ cache → `scan_cache/is_cacheable()` return False cho QD3.
4. CDG 7 điểm (Critical Decision Gate) — áp dụng cho `isg/` khi user chọn bỏ QD3/QD5 ở profile `deep`.
5. POST-GATE T1-T4 — áp dụng cho `signal_bus/` khi emit `issue-registry.json`.
6. SAFE-UPDATE `impl_status` — không áp dụng trực tiếp (mọi module role NONE), nhưng `signal_bus/` không được tự ý set impl_status.

### 4.4. Language & Style

- **Docstring + comment:** tiếng Việt có dấu.
- **Tên hàm, biến, tên file code:** English (snake_case cho Python, kebab-case cho shell).
- **Error messages hướng đến user:** tiếng Việt có dấu.
- **Error messages hướng đến log/dev:** English ngắn gọn.

---

## 5. Kiểm Thử (Testing)

### 5.1. B1 (phiên này)

Skeleton chỉ chứa **signatures + TODO**. Chưa có eval/unit test. File `.claude/skills/workflow/_shared/<module>/tests/` **để trống** hoặc không tồn tại.

### 5.2. B3 (Bellweather)

Khi `wf-fix-functional` và `wf-fix-business` gọi các module này, eval `≥3 case` per skill (theo spec Cowork plugin) sẽ bao cover indirectly.

### 5.3. B4 (Safety fixtures)

Viết 6 fixture test riêng trong `.claude/skills/workflow/_shared/_tests/safety-defaults/` để verify 6 rule ADR-22. Mỗi fixture là 1 input + expected behavior + assertion script.

---

## 6. Versioning

Mỗi module có `_contract.json` riêng với field `version` theo SemVer:

- v0.x.y — skeleton (B1-B2)
- v1.0.0 — GA khi `wf-fix-bugs` v6.0 cutover

Bump version khi:

- Breaking schema change → major
- Add optional field / new public function → minor
- Internal refactor + bugfix → patch

---

## 7. Troubleshooting Chung

| Triệu chứng | Nguyên nhân có thể | Xử lý |
|-------------|---------------------|-------|
| ImportError khi lane gọi module | Python path chưa thêm `_shared/` vào `PYTHONPATH` | Bootstrap script trong `wf-fix-bugs` orchestrator phải `sys.path.insert(0, ".claude/skills/workflow/_shared")` |
| `dim-selection.json` trống | ISG bị ESC mà chưa chọn | Tôn trọng profile default; enforce safety floor |
| Cache hit rate = 0 | QD3 trong scope (no-cache) hoặc fingerprint không stable | Kiểm tra `is_cacheable()`; dump fingerprint components |
| Token bucket deadlock | Process chết giữ lock không release | File lock phải có TTL (5 phút); auto-reclaim khi expire |

---

## 8. Tham Chiếu

- Design docs: [`docs/design/skills/wf-fix-bugs/`](../../../../docs/design/skills/wf-fix-bugs/README.md)
- ADR-01 → ADR-22: [`07-tradeoffs-adr.md`](../../../../docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md)
- Locked decisions Q14-Q23: [`09-design-decisions.md`](../../../../docs/design/skills/wf-fix-bugs/09-design-decisions.md)
- Core rules: [`.claude/rules/00-core.md`](../../../rules/00-core.md) — CORE-006/007/022/027
- Protocols: [`.claude/skills/protocols/`](../../protocols/README.md)

---

## 9. Next Steps (sau B1)

- **B2** — Extend `checkpoint.json` schema cho 4-level hierarchy (L0 Phase / L1 Lane / L2 Probe / L3 Intra-probe). Spec: ADR-16.
- **B3** — Implement `wf-fix-functional` + `wf-fix-business` bellweather, call module `_shared/*`.
- **B4** — Fixture test 6 safety defaults ADR-22.
- **C** — Impact Graph Builder + Verification Ripple (dùng `signal_bus/` + `scan_cache/`).
