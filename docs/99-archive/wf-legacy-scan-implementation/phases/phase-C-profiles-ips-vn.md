# Phase C — Profiles + IPS + Vietnamese Keywords

> **Mục tiêu:** Add profile selection (surface/standard/deep/exhaustive) + IPS Python module 2-phase + VN keyword pool detection.
> **Duration:** 3-4 ngày
> **Dependencies:** Phase B (foundation + templates + Python skeleton)
> **Tag khi xong:** `v5.0-phase-C`
> **Rollback:** Remove profile routing, IPS is additive — default = standard → = v4.1 behaviour.

---

## Prerequisites

- [ ] Phase B tagged `v5.0-phase-B`
- [ ] `scan_state_reader.py` working
- [ ] `vietnamese-keywords.json` template exists với 14 domains
- [ ] IPS Python module skeleton importable
- [ ] Branch `feat/wf-legacy-scan-v5.0-phase-c` created

---

## Tasks Overview

| ID | Task | Priority | Duration | Status |
|----|------|----------|----------|--------|
| C.1 | Profile Resolver — CLI flag parsing + depth_map | HIGH | 3-4 giờ | ⬜ |
| C.2 | Populate `vietnamese-keywords.json` full (14 domains × ~8) | HIGH | 4-5 giờ | ⬜ |
| C.3 | Implement `vietnamese_keywords.py` matching logic | HIGH | 4-5 giờ | ⬜ |
| C.4 | Implement `domain_scorer.py` (EN + VN unified) | HIGH | 3-4 giờ | ⬜ |
| C.5 | Implement `ips_recommender.py` phase A | CRITICAL | 4-5 giờ | ⬜ |
| C.6 | Implement `ips_recommender.py` phase B | CRITICAL | 4-5 giờ | ⬜ |
| C.7 | AskUserQuestion profile selection (CDG CORE-027) | MEDIUM | 2-3 giờ | ⬜ |
| C.8 | Integration test trên 3 fixtures + VN detection | CRITICAL | 3-4 giờ | ⬜ |

---

## Task C.1 — Profile Resolver

**Priority:** HIGH · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Update `.claude/skills/workflow/wf-legacy-scan/SKILL.md`:

1. Add argument-hint với new flags:
   ```
   argument-hint: "[project-path] [--profile=surface|standard|deep|exhaustive] [--layers=L1,L2,...] [--depth=surface|standard|deep] [--session=ID] [--status] [--resume] [--re-vision] [--batch-size=N] [--incremental] [--since=<git-ref>] [--no-cache] [--cache-publish]"
   ```

2. Add Arguments table cho new flags (bám [05-profiles-ips.md §1](../../05-profiles-ips.md)).

3. Add Profile Resolver logic tại Phase 0 init:
   - Parse `--profile`, `--layers`, `--depth`.
   - Build `depth_map` từ profile:
     | Profile | L1 | L2 | L3 | L4 | L5 | L6 |
     |---------|----|----|----|----|----|-----|
     | surface | full | full | full | surface | skip | condensed |
     | standard | full | full | full | standard | standard | full |
     | deep | full | full | full | deep | deep | full+insights |
     | exhaustive | full | full | full | deep | deep | full+divergence |
   - Default = standard (= v4.1).
   - Write `depth_map` + `synthesis_mode` vào scan-state.json.

4. Add procedure file `procedures/phase0b-profile.md`:
   - Document profile resolver logic.
   - Document `--depth` override cho individual layers.
   - Document error handling khi profile invalid.

### Verify

```bash
# Test default
/wf-legacy-scan fixtures/small-en/
jq '.depth_map' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# Expected: {"L1": "full", "L2": "full", "L3": "full", "L4": "standard", "L5": "standard", "L6": "full"}

# Test surface
/wf-legacy-scan fixtures/small-en/ --profile=surface
jq '.depth_map' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# Expected: L4=surface, L5=skip, L6=condensed

# Test deep
/wf-legacy-scan fixtures/small-en/ --profile=deep
jq '.depth_map' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# Expected: L4=deep, L5=deep, L6=full+insights

# Test individual override
/wf-legacy-scan fixtures/small-en/ --profile=standard --layers=L5 --depth=deep
jq '.depth_map.L5' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# Expected: "deep"
```

### Acceptance Criteria

- [ ] SKILL.md argument-hint updated
- [ ] Profile resolver parse 4 profiles correctly
- [ ] depth_map written to scan-state.json
- [ ] Invalid profile → clear error message + exit
- [ ] `--layers + --depth` override works
- [ ] Default = standard (no regression)
- [ ] `phase0b-profile.md` procedure file created

---

## Task C.2 — Populate `vietnamese-keywords.json` Full

**Priority:** HIGH · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Populate `.claude/skills/workflow/_shared/ips/vietnamese-keywords.json` với **14 domains** × ~8 keywords từ [10-vietnamese-keywords.md §2](../../10-vietnamese-keywords.md).

Structure per domain:

```json
{
  "$schema": "vn-keywords-v1",
  "version": "1.0",
  "last_updated": "2026-04-22",
  "normalization": {
    "strip_diacritics": true,
    "lowercase": true,
    "d_to_d": true,
    "strip_separators": ["-", "_", "/", "."]
  },
  "domains": {
    "finance": {
      "keywords": [
        {"keyword": "hoadon", "variants": ["hoa-don", "hóa-đơn"], "weight": 0.3, "exact_only": false},
        {"keyword": "thanhtoan", "variants": ["thanh-toan", "thanh-toán"], "weight": 0.25, "exact_only": false},
        {"keyword": "congno", "weight": 0.3, "exact_only": false},
        {"keyword": "ketoan", "weight": 0.3, "exact_only": false},
        {"keyword": "thue", "weight": 0.25, "exact_only": false},
        {"keyword": "ngansach", "weight": 0.2, "exact_only": false}
      ],
      "abbreviations": [
        {"keyword": "gd", "weight": 0.2, "exact_only": true},
        {"keyword": "kt", "weight": 0.3, "exact_only": true},
        {"keyword": "nh", "weight": 0.2, "exact_only": true}
      ]
    },
    "hr": { ... },
    "sales": { ... },
    "procurement": { ... },
    "ecommerce": { ... },
    "operations": { ... },
    "compliance": { ... },
    "healthcare": { ... },
    "logistics": { ... },
    "manufacturing": { ... },
    "retail": { ... },
    "legal": { ... },
    "insurance": { ... },
    "education": { ... }
  }
}
```

Copy đầy đủ keywords từ [10-vietnamese-keywords.md §2.1 + §2.2](../../10-vietnamese-keywords.md).

### Verify

```bash
# Schema valid
jq empty .claude/skills/workflow/_shared/ips/vietnamese-keywords.json

# 14 domains
jq '.domains | keys | length' .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
# Expected: 14

# Keyword count
jq '[.domains[].keywords[], .domains[].abbreviations[]?] | length' \
   .claude/skills/workflow/_shared/ips/vietnamese-keywords.json
# Expected: 110+

# No duplicate keywords across domains (check manually for critical overlap)
jq -r '[.domains | to_entries[] | .key as $d | .value.keywords[].keyword | $d + ": " + .] | .[]' \
   .claude/skills/workflow/_shared/ips/vietnamese-keywords.json | sort -k2 -t: | uniq -f1 -d
```

### Acceptance Criteria

- [ ] 14 domains populated
- [ ] ≥ 110 total keywords
- [ ] Cross-domain duplicates flagged trong README với weight adjustment notes
- [ ] Core 7 domains có ≥ 6 keywords mỗi domain
- [ ] Optional 7 có ≥ 5 keywords mỗi domain

---

## Task C.3 — `vietnamese_keywords.py` Matching Logic

**Priority:** HIGH · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Implement full matching logic trong `.claude/skills/workflow/_shared/ips/vietnamese_keywords.py`:

```python
"""Vietnamese Keyword matching logic cho IPS domain detection.

Reference: 10-vietnamese-keywords.md §3.
"""

import json
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Any

_POOL_PATH = Path(__file__).parent / "vietnamese-keywords.json"


@dataclass
class DomainSignal:
    domain: str
    confidence: float
    signals: list[dict]
    source: str = "vn"


def normalize_vn(text: str) -> str:
    """Strip diacritics, lowercase, remove separators. See tests for examples."""
    text = text.lower()
    text = unicodedata.normalize('NFD', text)
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    text = text.replace('đ', 'd')
    text = re.sub(r'[-_/.]', '', text)
    return text


def load_pool() -> dict[str, Any]:
    with _POOL_PATH.open() as f:
        return json.load(f)


def match_module_to_domains(module_name: str, pool: dict | None = None) -> list[DomainSignal]:
    """Match module name against VN keyword pool.
    
    Returns list of DomainSignal (may be empty).
    
    Matching rules (from 10 §3.2):
    1. Exact match in normalized form → full weight
    2. Substring match → weight × 0.7
    3. Multi-signal boost: ≥3 keywords same domain → +0.15
    4. Cross-domain penalty: keyword in ≥2 domains → weight × 0.6
    5. Abbreviations (exact_only=True) match exact only
    """
    if pool is None:
        pool = load_pool()
    
    normalized = normalize_vn(module_name)
    signals = []
    
    # Track keyword → domain map for cross-domain penalty
    keyword_domains = {}
    for domain, data in pool["domains"].items():
        for kw in data.get("keywords", []) + data.get("abbreviations", []):
            keyword_domains.setdefault(kw["keyword"], []).append(domain)
    
    # Match per domain
    for domain, data in pool["domains"].items():
        keywords = data.get("keywords", []) + data.get("abbreviations", [])
        
        for kw in keywords:
            norm_kw = normalize_vn(kw["keyword"])
            weight = kw["weight"]
            exact_only = kw.get("exact_only", False)
            
            # Check match
            matched = False
            match_type = None
            if norm_kw == normalized:
                matched = True
                match_type = "exact"
            elif not exact_only and norm_kw in normalized:
                matched = True
                match_type = "substring"
                weight *= 0.7
            
            if matched:
                # Cross-domain penalty
                if len(keyword_domains.get(kw["keyword"], [])) >= 2:
                    weight *= 0.6
                
                signals.append(DomainSignal(
                    domain=domain,
                    confidence=weight,
                    signals=[{
                        "type": "directory_name",
                        "value": module_name,
                        "keyword": kw["keyword"],
                        "match_type": match_type,
                        "weight": weight,
                        "lang": "vn",
                    }],
                ))
    
    # Multi-signal boost
    signals = _apply_multi_signal_boost(signals)
    
    return signals


def _apply_multi_signal_boost(signals: list[DomainSignal]) -> list[DomainSignal]:
    """Boost confidence nếu ≥3 keyword same domain."""
    from collections import Counter
    domain_counts = Counter(s.domain for s in signals)
    
    for s in signals:
        if domain_counts[s.domain] >= 3:
            s.confidence = min(s.confidence + 0.15, 1.0)
    
    return signals


def aggregate_signals_by_domain(signals: list[DomainSignal]) -> list[dict]:
    """Aggregate signals by domain, pick max confidence per domain."""
    from collections import defaultdict
    by_domain = defaultdict(list)
    for s in signals:
        by_domain[s.domain].append(s)
    
    result = []
    for domain, sigs in by_domain.items():
        max_conf = max(s.confidence for s in sigs)
        all_signals = [sig for s in sigs for sig in s.signals]
        result.append({
            "domain": domain,
            "confidence": max_conf,
            "language": "vn",
            "signals": all_signals,
            "recommended_expert": f"{domain}-expert",
        })
    
    return sorted(result, key=lambda r: r["confidence"], reverse=True)
```

### Tests

Expand `tests/test_vietnamese_keywords.py`:

```python
class TestMatchModuleToDomains:
    def test_vn_module_sales(self):
        signals = match_module_to_domains("qlkh")
        assert any(s.domain == "sales" for s in signals)
    
    def test_vn_module_finance(self):
        signals = match_module_to_domains("hoadon")
        assert any(s.domain == "finance" for s in signals)
    
    def test_multi_signal_boost(self):
        # Module name có multiple keywords — requires directory scan in real usage
        # For unit test, simulate với module name combined
        signals = match_module_to_domains("qlkhbanhangdonhang")
        sales_sig = next((s for s in signals if s.domain == "sales"), None)
        assert sales_sig is not None
        # Boost should apply (≥3 sales keywords: qlkh, banhang, donhang)
        # Confidence likely > 0.5 after boost
    
    def test_no_match(self):
        signals = match_module_to_domains("xyznonsense")
        assert signals == []
    
    def test_diacritic_variants(self):
        # "Quản-Lý-Khách-Hàng" should match same as "qlkh" partial
        signals = match_module_to_domains("khachhang")
        assert any(s.domain == "sales" for s in signals)


class TestAggregateSignals:
    def test_aggregate_picks_max_confidence(self):
        sigs = [
            DomainSignal(domain="sales", confidence=0.5, signals=[]),
            DomainSignal(domain="sales", confidence=0.8, signals=[]),
            DomainSignal(domain="finance", confidence=0.6, signals=[]),
        ]
        result = aggregate_signals_by_domain(sigs)
        assert result[0]["domain"] == "sales"
        assert result[0]["confidence"] == 0.8
```

### Verify

```bash
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/test_vietnamese_keywords.py -v
# Expected: ≥ 10 tests pass
```

### Acceptance Criteria

- [ ] `match_module_to_domains()` implement 4 matching rules
- [ ] `aggregate_signals_by_domain()` picks max confidence per domain
- [ ] Multi-signal boost tested
- [ ] Cross-domain penalty tested
- [ ] Diacritic normalization tested
- [ ] ≥ 10 unit tests pass

---

## Task C.4 — `domain_scorer.py` (EN + VN Unified)

**Priority:** HIGH · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Implement `.claude/skills/workflow/_shared/ips/domain_scorer.py`:

- English keyword detection (bám existing v4.1 patterns).
- Combine với VN results từ `vietnamese_keywords.py`.
- Scoring via weighted signal aggregation.
- Output: list[{domain, confidence, signals[], recommended_expert}].

Sample API:

```python
def score_domains(project_profile: dict, inventory: dict | None = None) -> list[dict]:
    """Score domains từ project signals (EN + VN).
    
    Args:
        project_profile: from project-profile.json
        inventory: optional inventory/*.json (for Phase B deeper scoring)
    
    Returns:
        Sorted list by confidence desc.
    """
    en_signals = _detect_en(project_profile, inventory)
    vn_signals = _detect_vn(project_profile, inventory)
    merged = _merge_signals(en_signals, vn_signals)
    return _aggregate(merged)
```

### Tests

```python
class TestScoreDomains:
    def test_en_project(self, en_fixture):
        result = score_domains(en_fixture)
        # Expect sales domain detected
        assert result[0]["domain"] == "sales"
    
    def test_vn_project(self, vn_fixture):
        result = score_domains(vn_fixture)
        # Expect finance OR hr detected
        assert result[0]["domain"] in ("finance", "hr", "sales")
    
    def test_mixed_project(self, mixed_fixture):
        result = score_domains(mixed_fixture)
        # Multiple domains
        assert len(result) >= 2
```

### Acceptance Criteria

- [ ] `score_domains()` handles EN + VN signals
- [ ] Output sorted by confidence desc
- [ ] 3 test fixtures pass (small-en, medium-vn, large-mixed)
- [ ] Detection precision ≥80% trên fixture test

---

## Task C.5 — `ips_recommender.py` Phase A

**Priority:** CRITICAL · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Implement `run_phase_a()` trong `ips_recommender.py` theo [05-profiles-ips.md §3.2](../../05-profiles-ips.md):

```python
def run_phase_a(project_profile_path: Path, assessment_path: Path, output_path: Path) -> dict:
    """IPS Phase A — after L2 Assessment.
    
    1. Read project-profile.json + assessment-report.json
    2. Score domains via domain_scorer
    3. Recommend profile based on:
       - maturity_level
       - file count
       - detected domain count + confidence
       - code/doc quality scores
    4. Write scan-state.ips.phase_a
    """
    profile = json.loads(project_profile_path.read_text())
    assessment = json.loads(assessment_path.read_text())
    
    from .domain_scorer import score_domains
    detected = score_domains(profile)
    
    # Profile recommendation logic
    maturity = assessment["maturity_level"]
    file_count = profile["file_counts"]["total"]
    code_quality = assessment["scores"]["code_quality"]
    doc_quality = assessment["scores"]["doc_quality"]
    
    if maturity == "NEAR_COMPLETE":
        rec_profile = "surface"
        reasoning = "Project well-documented, only need overview"
    elif file_count > 1000 or len(detected) >= 2:
        rec_profile = "deep"
        reasoning = f"Large/complex project ({file_count} files, {len(detected)} domains)"
    elif detected and detected[0]["confidence"] >= 0.75:
        rec_profile = "deep"
        reasoning = f"Strong domain match: {detected[0]['domain']} ({detected[0]['confidence']:.2f})"
    elif code_quality >= 70 and doc_quality >= 50:
        rec_profile = "standard"
        reasoning = "Healthy project, standard onboarding"
    else:
        rec_profile = "standard"
        reasoning = "Default"
    
    result = {
        "run_at": _now_iso(),
        "recommended_profile": rec_profile,
        "profile_reasoning": reasoning,
        "detected_domains": detected[:5],  # top 5
        "unresolved_patterns": _find_unresolved(profile),
        "warnings": _check_warnings(profile, detected),
        "user_overrode_profile": False,
    }
    
    output_path.write_text(json.dumps(result, indent=2, ensure_ascii=False))
    return result
```

### Tests

```python
class TestRunPhaseA:
    def test_small_en_project_recommends_standard(self, small_en_fixture, tmp_path):
        result = run_phase_a(
            small_en_fixture / "project-profile.json",
            small_en_fixture / "assessment-report.json",
            tmp_path / "ips-a.json"
        )
        assert result["recommended_profile"] in ("standard", "surface")
    
    def test_large_mixed_recommends_deep(self, large_mixed_fixture, tmp_path):
        result = run_phase_a(
            large_mixed_fixture / "project-profile.json",
            large_mixed_fixture / "assessment-report.json",
            tmp_path / "ips-a.json"
        )
        assert result["recommended_profile"] == "deep"
    
    def test_detected_domains_populated(self, medium_vn_fixture, tmp_path):
        result = run_phase_a(
            medium_vn_fixture / "project-profile.json",
            medium_vn_fixture / "assessment-report.json",
            tmp_path / "ips-a.json"
        )
        assert len(result["detected_domains"]) >= 1
        # VN fixture should detect core 7 domains
```

### Acceptance Criteria

- [ ] `run_phase_a()` reads + writes correct schemas
- [ ] Profile recommendation logic matches design §3.2
- [ ] Detected domains sorted by confidence
- [ ] 3 fixture tests pass
- [ ] Output validates against `domain-hints.json` schema

---

## Task C.6 — `ips_recommender.py` Phase B

**Priority:** CRITICAL · **Duration:** 4-5 giờ · **Status:** ⬜

### Actions

Implement `run_phase_b()` theo [05-profiles-ips.md §3.3](../../05-profiles-ips.md):

- Read inventory/*.json (source-files, dependency-graph, screens, api-endpoints)
- Cluster files by directory → estimate modules
- Compute coupling via dependency graph edges
- Identify hotspots (top 20% by size or coupling)
- Refine module → domain routing
- Workload estimate (total_features_est, est_time_min)
- Check workload gate thresholds

### Tests

- Test module clustering correctness
- Test hotspot detection
- Test workload estimate accuracy
- Test fixture VN routing correct

### Acceptance Criteria

- [ ] `run_phase_b()` implement đủ steps theo design
- [ ] Module → domain routing accurate ≥80% trên fixtures
- [ ] Workload estimate within ±30% of actual (measured post-hoc)
- [ ] Integration test với Phase A works

---

## Task C.7 — AskUserQuestion Profile Selection

**Priority:** MEDIUM · **Duration:** 2-3 giờ · **Status:** ⬜

### Actions

Update `procedures/phase0b-profile.md`:

- Khi `--profile` KHÔNG được chỉ định:
  - Chạy IPS Phase A.
  - Hiển thị UI theo [03-architecture §4.3](../../03-architecture.md).
  - AskUserQuestion với 4 profile options + IPS recommendation highlighted.
  - CDG (CORE-027) — user phải explicit confirm.

### UI Format

```
📊 Phân tích ban đầu hoàn tất

Dự án: <name>
Kích thước: <N> files (<languages>)
Maturity: <level>
Domain phát hiện: <domain1> (<conf1>), <domain2> (<conf2>)

Khuyến nghị: <profile>
  Lý do: <reasoning>

Chọn profile scan:
  [ ] surface — Overview nhanh (~X min)
  [ ] standard — Onboarding chuẩn (~Y min)
  [x] deep — Phân tích chuyên sâu (~Z min) ← Khuyến nghị
  [ ] exhaustive — Audit toàn diện (~W min + divergence)

[Enter]=xác nhận | [p]=đổi profile | [s]=skip (dùng standard default) | [q]=huỷ
```

### Verify

- Manual test trên medium-vn fixture without `--profile` flag → prompt xuất hiện
- Test với `--profile=standard` → skip prompt, use specified

### Acceptance Criteria

- [ ] AskUserQuestion integration works
- [ ] IPS recommendation highlighted
- [ ] User override preserves in scan-state.ips.phase_a.user_overrode_profile = true
- [ ] `--profile` flag skips prompt

---

## Task C.8 — Integration Test trên 3 Fixtures

**Priority:** CRITICAL · **Duration:** 3-4 giờ · **Status:** ⬜

### Actions

Run full scan với IPS trên 3 fixtures + verify:

```bash
# Test 1: small-en với default profile
/wf-legacy-scan fixtures/small-en/ --profile=standard
jq '.ips.phase_a' .mc-data/work/legacy-scan/sessions/*/scan-state.json
# Expect: detected_domains non-empty, recommended_profile reasonable

# Test 2: medium-vn với auto profile (IPS recommend)
/wf-legacy-scan fixtures/medium-vn/
# Expect: prompt xuất hiện, IPS detect VN domains (qlkh → sales, hoadon → finance, ...)
jq '.ips.phase_a.detected_domains[] | {domain, confidence, language}' \
   .mc-data/work/legacy-scan/sessions/*/scan-state.json

# Test 3: large-mixed với deep profile
/wf-legacy-scan fixtures/large-mixed/ --profile=deep
# Expect: IPS Phase B run, module_routing populated
jq '.ips.phase_b.module_routing' .mc-data/work/legacy-scan/sessions/*/scan-state.json
jq '.ips.phase_b.workload_estimate' .mc-data/work/legacy-scan/sessions/*/scan-state.json
```

### Acceptance Criteria

- [ ] 3 fixture runs complete without error
- [ ] VN domain detection precision ≥ 80% (manual review domain-hints.json)
- [ ] Profile recommendation consistent (same fixture → same recommendation)
- [ ] Module routing populated cho ≥ 70% modules in medium-vn + large-mixed
- [ ] Workload estimate accurate ±30% vs actual (compare to v4.1 wall-clock)

---

## Post-Phase Verification

```bash
# 1. Python tests
cd .claude/skills/workflow
python -m pytest _shared/ips/tests/ -v
# Expected: 20+ tests pass

# 2. Compliance + schema
powershell -ExecutionPolicy Bypass -File .claude/scripts/run-devkit-bash.ps1 \
  .claude/scripts/skill-compliance-audit.sh wf-legacy-scan

# 3. Tag
git tag -a v5.0-phase-C -m "Phase C Profiles + IPS + VN complete"
```

## Exit Criteria

- [ ] All 8 tasks ✅
- [ ] IPS Python module: ≥20 tests pass
- [ ] VN keyword pool: 14 domains × ≥8 keywords
- [ ] 3 fixture integration tests PASS
- [ ] Domain detection precision ≥80% trên VN fixture
- [ ] Profile resolver works cho 4 profiles
- [ ] AskUserQuestion CDG integration works
- [ ] `v5.0-phase-C` tag pushed
- [ ] MIGRATION-PROGRESS.md updated

## Next Phase

→ [phase-D-agents-submigration.md](phase-D-agents-submigration.md)
