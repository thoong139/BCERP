<!--
_template_notes:
  purpose: VARIANT cho skill có --profile arg (quick/standard/deep/exhaustive).
           Có thể bổ sung CHO 05-error-codes.md (không thay thế).
  populate:
    - §1 Bảng profiles + duration + scope + cost
    - §2 Phase activation matrix (phase nào chạy theo profile nào)
    - §3 Probe activation matrix (xem 02-quality-dimensions nếu có)
    - §4 Cache policy per profile
    - §5 Decision matrix khi nào dùng profile nào
    - §6 Auto-upgrade rules (skill có thể tự bump profile)
  Áp dụng: skills có --profile (wf-fix-bugs, wf-legacy-scan, wf-scan-target)
  KHÔNG dùng cho: skill quick (1 profile duy nhất) hoặc skill simple
  độ dài tham khảo: 200-350 dòng
  Khi dùng file này, ĐỔI TÊN thành 05-execution-profiles.md (xóa .alt)
-->

# 05 — Execution Profiles (Profile Variant)

> **Mục đích file:** Đặc tả 4 profiles `quick / standard / deep / exhaustive` của skill `{skill-name}` — duration, scope, phase activation, cost, decision matrix.

---

## 1. Profiles overview

| Profile | Duration | Scope | LLM calls | Playwright | Cache policy | Cost (token) |
|---------|----------|-------|-----------|------------|--------------|--------------|
| `quick` | 2-5 min | Targeted (1 module/file) | ❌ | ❌ | Aggressive (24h TTL) | ~5K |
| `standard` | 10-20 min | Full project | ❌ | Assisted (smoke) | Normal (24h TTL) | ~30K |
| `deep` | 30-60 min | Full + LLM analysis | ✅ (low concurrency) | Full (3 modes) | Selective (4h TTL probes) | ~150K |
| `exhaustive` | 60-180 min | Full + LLM + runtime | ✅ (full concurrency) | Full + cross-browser | Skip cache | ~500K |

**Default:** `standard` (cân bằng giữa thoroughness và cost).

---

## 2. Phase activation matrix

| Phase | quick | standard | deep | exhaustive |
|-------|-------|----------|------|-----------|
| 1. Init | ✅ | ✅ | ✅ | ✅ |
| 2. Static scan | ✅ | ✅ | ✅ | ✅ |
| 3. Probe dispatch (parallel) | ✅ (3 probes) | ✅ (8 probes) | ✅ (15 probes) | ✅ (all 22 probes) |
| 4. LLM enhancement | ❌ | ❌ | ✅ | ✅ |
| 5. Runtime/Playwright | ❌ | ⚪ assisted | ✅ full | ✅ full + devices |
| 6. Cross-validation | ❌ | ✅ | ✅ | ✅ |
| 7. Triage | ✅ | ✅ | ✅ | ✅ |
| 8. Report | ✅ | ✅ | ✅ | ✅ |

---

## 3. Probe activation matrix (nếu skill có probes)

Tham chiếu [`02-quality-dimensions.md`](02-quality-dimensions.md) §3 — bảng probe × profile.

---

## 4. Cache policy per profile

| Profile | GitNexus cache | Serena cache | Probe cache | Bust rules |
|---------|---------------|--------------|-------------|-----------|
| quick | Use 24h | Use 24h | Use 4h | Manual `--no-cache` |
| standard | Use 24h | Use 24h | Use 1h | HEAD changed > 5 commits |
| deep | Refresh > 12h | Refresh > 12h | Skip cache | HEAD changed > 1 commit |
| exhaustive | Skip cache | Skip cache | Skip cache | Always fresh |

---

## 5. Decision matrix — khi nào dùng profile nào

| Tình huống | Profile khuyến nghị | Rationale |
|-----------|---------------------|-----------|
| Trước commit local | `quick` | Fast feedback, focus 1 module |
| Trước PR review | `standard` | Full project, không runtime |
| Trước release/deploy | `deep` | LLM phát hiện edge cases |
| Audit định kỳ tháng/quý | `exhaustive` | Comprehensive baseline |
| Bug report cụ thể | `quick --scope=module:X` | Targeted investigation |
| Onboarding repo mới | `standard` | Hiểu tổng thể không tốn token |
| Resume sau interrupt | Same as before | Auto-detect từ session |

---

## 6. Auto-upgrade rules

Skill có thể **tự bump profile** trong các case sau (báo cho user):

| Trigger | From → To | Reason |
|---------|----------|--------|
| `--scope=all` + project >100 files | `quick` → `standard` | Quick không đủ scope |
| Phát hiện CRITICAL bug ở probe | `standard` → `deep` (cùng session) | Cần LLM xác định fix strategy |
| Cross-module dependencies detected | `quick` → `standard` | Quick không cover cross-module |

**Quy tắc:** Auto-upgrade BẮT BUỘC qua CDG (Critical Decision Gate) — user xác nhận trước khi tăng cost.

---

## 7. Profile interaction with `--scope`

| Scope | Profile compat | Note |
|-------|---------------|------|
| `--scope=all` | standard / deep / exhaustive | quick auto-bump → standard |
| `--scope=module:X` | quick / standard / deep | exhaustive overkill cho 1 module |
| `--scope=file:Y` | quick only | Profile cao hơn waste cost |

---

## 8. Liên kết

- Argument detail: [`02-arguments.md`](02-arguments.md) §1 — `--profile` row
- Phase routing: [`03-phase-routing.md`](03-phase-routing.md) §3 — profile dispatch table
- Real example: [`../wf-fix-bugs/05-execution-profiles.md`](../wf-fix-bugs/05-execution-profiles.md), [`../wf-legacy-scan/05-profiles-ips.md`](../wf-legacy-scan/05-profiles-ips.md)
- Pattern: [`../../03-design-patterns/02-ci-first-integration.md`](../../03-design-patterns/02-ci-first-integration.md) (cache TTL per profile)
