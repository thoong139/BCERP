# QD3 — Security Vulnerabilities: Audit Report

> **Status:** ✅ Phase 1+2+3+4+5 done — **QD3 AUDIT COMPLETE (HIGH PRIORITY, audit thứ 2 sau QD1)**
> **Owner audit:** Phiên 10-13 (2026-05-08)
> **Last update:** 2026-05-08 — Phase 5 Synthesize (Phiên 14): §8 expanded 8→12 IMPs, §8.1 4-layer rationale, IMP-QD3-002 promoted L0 (standard=40% OWASP FALSE GUARANTEE), 3 MERGE confirmed. QD3 COMPLETE.

## 1. Tổng quan

| Trường | Giá trị |
|---|---|
| Dimension ID | QD3 |
| Tên | Security Vulnerabilities (& Privacy) |
| Owner agent | `security` (engineering team) |
| Số probes | 7 (cùng QD1, QD5 — lane lớn nhất sau QD2/QD4) |
| Profile chạy | quick / standard / deep / exhaustive |
| Lane skill | `wf-fix-security` v2.0.0-alpha.s4 |
| Dimension version | 1.0.0 |
| Cache policy | **NEVER (ADR-22 Rule 6)** — security probes always re-scan |
| **DISCREPANCY-1 (architectural)** | 3/7 probe specs (`dependency-vuln-scan`, `cors-policy-check`, `security-header-audit`) ghi "Cache allowed (1h/24h TTL)" trong B2/B3 → MÂU THUẪN với ADR-22 Rule 6 + `_shared.md §2` + `SKILL.md PRE-GATE step 8`. Tương tự dual-schema fork QD1 nhưng nhẹ hơn (không phá data shape). Có thể được override at runtime nếu PRE-GATE force `--use-cache=false`. **Cần Phase 2 verify bash actually skip cache hay không.** |

### Workflow position
```
/wf-fix-bugs (orchestrator v7) → spawn QD3 lane (parallel với QD1/QD2/QD4-7)
  → SENSE: 4 static probes (secret, vuln-scan, deserialize, owasp)
  → ACT: 3 runtime/agent probes (auth-flow, cors, headers)
  → VERIFY → Signal Bus → CDG-SECURITY-LIVE escalate (CRITICAL)
```

## 2. Liệt kê probes

> Nguồn: `dimension.json` (canonical) + `_shared.md §4` (profile resolver). Cột "SKILL.md routing" để lộ DISCREPANCY-2 (xem dưới).

| # | Probe ID | Type | quick | standard | deep | exhaustive | Severity default | CDG (dim.json) | Tool | Cost (s/tok) |
|---|---|---|:-:|:-:|:-:|:-:|---|:-:|---|---|
| 1 | `P-QD3-dependency-vuln-scan` | static+runtime | ✅ | ✅ | ✅ | ✅ | HIGH | ❌ | bash+jq+(npm/pip audit) | 60s/3K |
| 2 | `P-QD3-owasp-top-ten` | static (agent-assisted) | ✅ | ✅ | ✅ | ✅ | HIGH | ❌ | grep+jq | 45s/4K |
| 3 | `P-QD3-dangerous-deserialize` | static | ✅ | ✅ | ✅ | ✅ | HIGH | ❌ | grep+jq | 30s/2K |
| 4 | `P-QD3-secret-detection` | static | ❌ | ✅ | ✅ | ✅ | **CRITICAL** | ✅ | bash script (`wf-fix-probe-static-secret.sh`) | 30s/2K |
| 5 | `P-QD3-auth-flow-verify` | runtime+agent | ❌ | ✅ | ✅ | ✅ | **CRITICAL** | ❌ | grep + curl + agent (security) | 120s/10K |
| 6 | `P-QD3-cors-policy-check` | runtime (+static) | ❌ | ✅ | ✅ | ✅ | MEDIUM | ❌ | bash+curl | 30s/1.5K |
| 7 | `P-QD3-security-header-audit` | runtime (+static) | ❌ | ❌ | ✅ | ✅ | MEDIUM | ❌ | bash+curl | 30s/1.5K |

**Total wall-clock (sequential, deep profile):** 345s. **Total tokens (deep):** ~24.5K.

### DISCREPANCY-2: Routing — dimension.json vs profile-resolver.md (Phase 2 CONFIRMED)

> **Phase 2 finding:** `profile-resolver.md` (`.claude/skills/workflow/_shared/lane/profile-resolver.md`, line 156: "S3 chi document mapping. Lane skill PRE-GATE dung Pattern A inline") là **runtime source of truth**. Phase 1 so sánh SKILL.md vs dimension.json — Phase 2 xác nhận: profile-resolver.md **đồng thuận với SKILL.md** và **mâu thuẫn với dimension.json** tại 6 cells. → **dimension.json là outlier, không phải SKILL.md**.

| Probe | dim.json quick | resolver quick | Match? | dim.json standard | resolver standard | Match? |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| `secret-detection` | ❌ | ✅ | ❌ MISMATCH | ✅ | ✅ | ✅ |
| `dependency-vuln-scan` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `dangerous-deserialize` | ✅ | ❌ | ❌ MISMATCH | ✅ | ✅ | ✅ |
| `cors-policy-check` | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| `security-header-audit` | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ MISMATCH |
| `auth-flow-verify` | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ MISMATCH |
| `owasp-top-ten` | ✅ | ❌ | ❌ MISMATCH | ✅ | ❌ | ❌ MISMATCH |

**6 cells mismatch** (không phải 2 như Phase 1 ước tính). Critical security gaps:
- `owasp-top-ten`: dim.json nói standard=✅ nhưng runtime chỉ chạy deep+ → user dùng `--profile=standard` KHÔNG có OWASP scan!
- `auth-flow-verify`: dim.json nói standard=✅ nhưng runtime chỉ deep+ → auth checks bị skip ở standard!
- `security-header-audit`: dim.json nói standard=❌ nhưng runtime chạy standard=✅ → over-coverage (không nguy hiểm nhưng không đúng spec).
- `secret-detection`: dim.json nói quick=❌ nhưng runtime chạy quick=✅ → secret scan ngay cả quick mode (tốt cho security, wrong theo spec).

**Severity:** HIGH — standard profile security gap cho 2 critical probes (OWASP + auth-flow-verify).

**Recommended fix:** Update dimension.json để khớp profile-resolver.md (6 cells), NOT ngược lại (profile-resolver.md là live code).

**Bonus DISCREPANCY-2b:** profile-resolver.md Override rule 2 (line 162): "Cache miss: Probe có cache hit → run light, KHÔNG hit → run full" — contradicts ADR-22 Rule 6 (QD3 NEVER cache in any profile). Rule này vô hiệu cho QD3 nhưng vẫn là doc contradiction.

### DISCREPANCY-3: CDG flag policy

`dimension.json` chỉ có 1 probe `cdg=true` (secret-detection). Nhưng **6/7 probe specs** tự attach `cdg_flags: ["CDG-SECURITY-LIVE"]` cho CRITICAL signals (xem THINK/ACT block của từng probe). Nếu probe spec authoritative → 6 probes có CDG runtime. Nếu dimension.json authoritative → chỉ secret-detection có CDG. Cần Phase 2 verify `_shared/lane/signal-emit.md` xem có filter CDG flag theo `dimension.json` cdg field không.

### Tóm tắt severity rules (từ dimension.json `severity_rules`)

- **CRITICAL triggers:** secret exposed, auth bypass, SQL/command injection
- **HIGH triggers:** XSS/CSRF pattern, unsafe dynamic exec, known CVE with exploit
- **MEDIUM triggers:** missing security header, overly permissive CORS
- **Aggregation:** `max_aggregation: true` → multi-probe same-file → max severity

## 3. Per-probe Analysis

> **Phương pháp:** SENSE/THINK/ACT/VERIFY mỗi probe. Phase 1 verdict mặc định **TRUST_SPEC** — Phase 2 sẽ confirm hoặc đổi sang MISMATCH/PARTIAL.

### Probe 1: `P-QD3-dependency-vuln-scan`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Tìm 5 manifests (`package.json`, `requirements.txt`, `pom.xml`, `Gemfile`, `go.mod`) qua `find . ! -path "*/node_modules/*"`. Parse name+version. Exhaustive: gọi `npm audit --json` + `pip-audit --json`. | (i) Hardcoded CVE checklist 17 packages (express<4.18, lodash<4.17.21, log4j-core<2.17.1, ...) — list cứng, không update từ NVD. (ii) Parse package.json bằng regex `"[a-zA-Z0-9_@/-]+"\s*:\s*"[0-9]"` → có thể miss scoped packages có version range `^4.18.0`. |
| **THINK** | Severity by CVE type: RCE → CRITICAL+CDG, XSS/SSRF/auth-bypass → HIGH, moderate → MEDIUM. MITRE mapping (T1190, T1059.007, T1550.004). | Severity mismatch: dimension.json severity_default=HIGH, nhưng probe spec có CRITICAL cho RCE CVEs → max_aggregation lane-level resolves. |
| **ACT** | Emit signals format `CVE-{package}-{severity}`, `cdg_flags: ["CDG-SECURITY-LIVE"]` cho CRITICAL CVEs. | DISCREPANCY-3: probe gắn CDG nhưng dimension.json `cdg=false` cho probe này. |
| **VERIFY** | Mỗi CRITICAL signal có CDG, mỗi signal có dimension_id=QD3 + domain=security + remediation specific upgrade. | (i) "CACHING: verify cache TTL ton tai (24h)" — DISCREPANCY-1 với ADR-22. (ii) Pip-audit failure path emit metadata, không block. |
| **Verdict Phase 1→2** | **SPEC-ONLY** (no bash implementation found). | Spec has known contradiction: cache "24h" vs ADR-22 NEVER. All findings are spec-level. |

**Spec ↔ Implementation (Phase 2):**

| # | Aspect | Spec | Impl (bash/runtime) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | Implied (steps describe `npm audit`, `pip-audit`, `grep`) | NOT FOUND — no `wf-fix-probe-*vuln*.sh` | HIGH | SPEC-ONLY |
| D2 | Cache policy | B2: "CACHING: verify cache TTL (24h)" | N/A — no impl; spec contradicts ADR-22 Rule 6 | MEDIUM | SPEC-DRIFT |
| D3 | CDG flag | `cdg_flags: ["CDG-SECURITY-LIVE"]` for CRITICAL CVEs | N/A — no impl; dimension.json cdg=false | MEDIUM | SPEC-UNRESOLVABLE |
| D4 | Profile routing | dim.json: quick=✅, standard=✅ | profile-resolver: quick=✅, standard=✅ | — | ✅ MATCH |
| D5 | Hardcoded CVE list | 17 packages hard-coded (express<4.18, lodash<4.17.21, ...) | N/A | MEDIUM | STALE-RISK |

### Probe 2: `P-QD3-owasp-top-ten`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Scan files theo profile depth: standard A01+A03+A07, deep +A02+A04+A05+A10, exhaustive full A01-A10. Find 200 files max. | Hardcoded `src/` (không nhận `--source-dir` argument như P-QD1-static-xref). Monorepo `apps/backend/src` sẽ miss. |
| **THINK** | A01 (Broken Access Control): grep route handlers `app.get/post/...` rồi filter những endpoint KHÔNG có `auth\|authGuard\|middleware\|verifyToken`. A03 (SQL/NoSQL/OS injection): grep concat patterns `SELECT.*FROM.*+`, `$where`, `exec(`. A07: jwt alg=none, hardcoded JWT secret. | Pattern A01 dễ false-positive cao: route `/public/*` filtered nhưng `/api/internal/*` (no public path) bị flag. |
| **ACT** | Agent (security) classify grep results thành confirmed/suspected/false_positive ở deep+exhaustive. Signal `OWASP-{category}-{file_hash8}`. CDG cho injection + access control CRITICAL. | Standard profile KHÔNG có agent classification → raw grep results. False positive rate cao nhất ở standard. |
| **VERIFY** | Mỗi CRITICAL có CDG, evidence non-empty, dimension=QD3, standard không có A08/A09/A10 signals. | Standard profile output is unverified by agent → reliability low. |
| **Verdict Phase 1→2** | **MISMATCH** (routing D4 critical — standard profile missing owasp-top-ten!). | No bash implementation. Agent token cost unspecified. |

**Spec ↔ Implementation (Phase 2):**

| # | Aspect | Spec | Impl (bash/runtime) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | Implied (inline grep trong .md) | NOT FOUND — SPEC-ONLY; không thể test độc lập | HIGH | SPEC-ONLY |
| D2 | Cache policy | Không đề cập | N/A | — | N/A |
| D3 | CDG flag | CDG-SECURITY-LIVE cho injection/access-control CRITICAL | N/A — no impl; dimension.json cdg=false | MEDIUM | SPEC-UNRESOLVABLE |
| D4 | Profile routing | dim.json: quick=✅, standard=✅ | **profile-resolver: quick=❌, standard=❌** (deep+ only) | **HIGH** | ❌ MISMATCH — 2 cells off |
| D5 | Source dir | Hardcoded `src/` | N/A | LOW | SPEC-DRIFT |

### Probe 3: `P-QD3-dangerous-deserialize`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Detect language (TS/JS/PY/JAVA/CS/PHP). Scan: JS eval/Function/setTimeout-string/JSON.parse-no-try-catch/innerHTML/dangerouslySetInnerHTML/v-html. Python pickle/yaml.load (unsafe)/marshal/joblib. Java ObjectInputStream/readObject. C# BinaryFormatter/JavaScriptSerializer. PHP unserialize. | Standard profile JS/TS only; deep+exhaustive scan Python/Java/C#. Hardcoded `src/` (cùng issue Probe 2). |
| **THINK** | CRITICAL: eval/Function/pickle/yaml.load/ObjectInputStream/BinaryFormatter/PHP unserialize. HIGH: JSON.parse no try/catch, innerHTML, marshal/joblib. MITRE T1059.006/007, T1203, T1499. | (i) `setTimeout(string, ...)` flagged nhưng `setTimeout(() => {...})` an toàn — regex không phân biệt. (ii) `JSON.parse without try/catch` quá rộng — sẽ flag mọi `JSON.parse(req.body)` kể cả khi có error middleware. |
| **ACT** | Signal `DESER-{language}-{pattern}-{file_hash8}`, CDG-SECURITY-LIVE cho CRITICAL. Remediation language-specific. | DISCREPANCY-3: probe gắn CDG nhưng dimension.json `cdg=false`. |
| **VERIFY** | CRITICAL có CDG, target.file_path + line_range, no cache calls (ADR-22 audit), language tag matches actual project. | "Standard profile khong co Java/C# signals" — verify rule. |
| **Verdict Phase 1→2** | **PARTIAL_MISMATCH** (D4 routing: dim.json quick=✅ nhưng profile-resolver quick=❌). | No bash implementation. FP risk `JSON.parse` remains. |

**Spec ↔ Implementation (Phase 2):**

| # | Aspect | Spec | Impl (bash/runtime) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | Implied (inline grep trong .md) | NOT FOUND — SPEC-ONLY | HIGH | SPEC-ONLY |
| D2 | Cache policy | Không đề cập | N/A | — | N/A |
| D3 | CDG flag | CDG-SECURITY-LIVE cho CRITICAL patterns | N/A — no impl; dimension.json cdg=false | MEDIUM | SPEC-UNRESOLVABLE |
| D4 | Profile routing | dim.json: quick=✅, standard=✅ | **profile-resolver: quick=❌**, standard=✅ | MEDIUM | ❌ MISMATCH (quick 1 cell) |
| D5 | Source dir | Hardcoded `src/` | N/A | LOW | SPEC-DRIFT |

### Probe 4: `P-QD3-secret-detection`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Delegate đến `wf-fix-probe-static-secret.sh` (bash script độc lập — UNIQUE trong lane này, cùng pattern QD1 P1 static-xref). 14 patterns: AWS/Google/GitHub/Slack/Stripe keys, JWT, private keys, generic API/password, DB URL, Bearer, hex hash 64+. | Filter file types: skip test/fixture/mock/example/docs/node_modules. Comment lines `(example/placeholder/TODO/FIXME)` skipped. Source-dir argument: `--source-dir "${SOURCE_DIR:-src/}"` → flexible (UNIQUE — chỉ probe này có). |
| **THINK** | Severity by pattern type: production keys (AWS/GitHub/Stripe Live/private keys) → CRITICAL+CDG. JWT/generic API key/password/DB URL/Bearer → HIGH. Hex hash 64+ → MEDIUM. | (i) Universal regex coverage strong (14 patterns). (ii) **Confidence 0.95** từ `_shared.md §3`. |
| **ACT** | Signal schema signal-v2, CDG-SECURITY-LIVE attached cho TẤT CẢ signals (không phân biệt severity). Domain=security, fixability=agent_fix. | dimension.json `cdg=true` ↔ probe spec authoritative ↔ matched. ✓ |
| **VERIFY** | Mỗi signal có evidence + CDG + domain + dimension_id, no cache calls audit. | Bash script là single source of truth — Phase 2 đọc script để verify. |
| **Verdict Phase 1→2** | ✅ **CONFIRMED** (bash verified, D5 fingerprint anomaly noted). | Best-engineered probe QD3. 14 patterns ✓, cache NEVER ✓, CDG correct ✓. D5 fingerprint 3-way split (cross-cutting). |

**Spec ↔ Implementation (Phase 2):** — *Probe này có bash script: so sánh đầy đủ nhất trong lane*

| # | Aspect | Spec | Bash actual (`wf-fix-probe-static-secret.sh`) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | `wf-fix-probe-static-secret.sh` | EXISTS, 153 lines, `set -euo pipefail` | — | ✅ CONFIRMED |
| D2 | Cache policy | ADR-22 Rule 6: NEVER | Line 8: `# Cache policy: NEVER` — 0 `cache_lookup`/`cache_store` calls | — | ✅ CONFIRMED |
| D3 | CDG flag | dimension.json cdg=true; spec: all signals get CDG | Line 131: `cdg_flags: ["CDG-SECURITY-LIVE"]` hard-coded (ALL signals, not per-severity) | — | ✅ CONFIRMED (three-way match: dim.json ✓ + spec ✓ + bash ✓) |
| D4 | Profile routing | profile-resolver: quick=✅, standard=✅ | Bash is routing-agnostic (orchestrator decides); no profile filter in script | — | ✅ N/A (no issue) |
| D5 | Fingerprint | `_shared.md §1` comment: **4 tokens** (dim+file+line+probe); `signal-emit.md` generate_fingerprint: **5 tokens** (+sig_type) | Line 105: **6 tokens** (`"QD3\|$file\|$line\|$PROBE_ID\|secret\|$label"`) | MEDIUM | ❌ 3-WAY SPLIT: spec=4, protocol=5, bash=6 |
| D6 | Pattern count | 14 patterns (14 credential types) | Lines 61-76: exactly 14 entries in `PATTERNS[]` ✓ | — | ✅ CONFIRMED |
| D7 | Schema output | lane-signals-v1 (envelope) + signal-v2 (signal) | Lines 51/119: `"$schema": "lane-signals-v1"` (envelope) + `"$schema": "signal-v2"` (signal) — fields match lane-local schema (`_shared.md §1`): `severity` ✓, `location` ✓, `evidence:[array]` ✓, `fingerprint` ✓, `detected_at` ✓ | — | ✅ CONFIRMED (lane-local schema, NOT bus schema) |

### Probe 5: `P-QD3-auth-flow-verify`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Static: grep JWT verify patterns, session config, RBAC patterns, password policy, weak hash (md5/sha1), token expiry. Runtime (deep+exhaustive): curl protected endpoint without/with-invalid token (expect 401). Exhaustive: check `/auth/login` endpoint. | (i) Tech stack: chỉ TS/TSX/JS/PY (4 stacks) — KHÔNG cover Java/Go/C#/PHP. (ii) Hardcoded `src/`. (iii) Runtime scope hẹp: chỉ test `/api/protected` + `/auth/login` — không discover endpoints. |
| **THINK** | Phân tích 4 trục: JWT lifecycle, session security, RBAC coverage, password hygiene. CRITICAL: protected endpoint trả 200 không token, JWT alg=none. HIGH: hardcoded JWT secret, missing cookie flags, missing RBAC, weak hash. | Pattern `jwt|token|bearer|authorization` quá rộng → false-positive cao (UI labels, comments). |
| **ACT** | Signal `AUTH-{category}-{file_hash8}`. CDG-SECURITY-LIVE cho missing auth/token forgery (CRITICAL). MITRE T1550.004, T1529, T1078, T1110.002. | DISCREPANCY-3: dimension.json `cdg=false` nhưng probe spec gắn CDG-SECURITY-LIVE. |
| **VERIFY** | CRITICAL có CDG, runtime signals có evidence.type=http_response, static signals có target.file_path+line_range. | Runtime test rất hẹp (2 endpoints). Cần discovery layer (browse OpenAPI spec, route map từ GitNexus). |
| **Verdict Phase 1→2** | **MISMATCH** (D4 routing critical — standard profile skips auth-flow-verify!). | SPEC-ONLY. Tech stack gap (4/7) remains. CDG risk if using signal-emit.md helper without post-emit step. |

**Spec ↔ Implementation (Phase 2):**

| # | Aspect | Spec | Impl (bash/runtime) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | Implied (grep+curl+agent steps) | NOT FOUND — SPEC-ONLY | HIGH | SPEC-ONLY |
| D2 | Cache policy | Không đề cập | N/A | — | N/A |
| D3 | CDG flag | CDG-SECURITY-LIVE cho CRITICAL (missing_auth, token_forgery) | N/A — if using `signal-emit.md` helper: `cdg_flags: []` by default (post-emit step needed) → **CDG sẽ bị lost nếu implementer quên bước attach** | HIGH | ❌ CDG-RISK |
| D4 | Profile routing | dim.json: quick=❌, standard=✅ | **profile-resolver: quick=❌, standard=❌** (deep+ only) | **HIGH** | ❌ MISMATCH — standard coverage gap |
| D5 | Tech stack | 4 stacks only (TS/JS/PY + grep pattern) | N/A | HIGH | COVERAGE-GAP |

### Probe 6: `P-QD3-cors-policy-check`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Static grep: wildcard `Access-Control-Allow-Origin: *`, `credentials: true`, permissive methods/headers, env config (CORS_ORIGIN), maxAge, expose-headers, sameSite. Runtime (deep+exhaustive): `curl -X OPTIONS -H "Origin: https://evil.com\|attacker.io\|null"`. | Tech stack: TS/TSX/JS/PY/GO/YAML/YML/JSON/conf — broader than auth-flow-verify. Hardcoded `src/`. Skip `node_modules\|.test.\|example\|template`. |
| **THINK** | CRITICAL: wildcard origin + credentials:true (T1557.001). HIGH: missing CORS middleware. MEDIUM: wildcard alone, permissive methods/headers, missing sameSite, expose-headers leak. | DISCREPANCY-1: B3 ghi "Cache allowed (1h TTL)" mâu thuẫn ADR-22 Rule 6. |
| **ACT** | Signal `CORS-{category}-{file_hash8}`. CDG-SECURITY-LIVE chỉ cho wildcard+credentials. | DISCREPANCY-3 nhẹ hơn (chỉ 1 case CRITICAL có CDG, các case khác không gắn). |
| **VERIFY** | wildcard+credentials có CDG, runtime status codes verified, cache TTL=1h "khong violate ADR-22" — **logic flawed**: ADR-22 Rule 6 nói NEVER cache. | Spec internal contradiction. |
| **Verdict Phase 1→2** | **SPEC-ONLY + SPEC-DRIFT** (D2 cache, D4 routing confirmed correct). | No bash. Cache mention dead code at impl level. Runtime test 3 fixed origins. |

**Spec ↔ Implementation (Phase 2):**

| # | Aspect | Spec | Impl (bash/runtime) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | Implied (grep+curl steps) | NOT FOUND — SPEC-ONLY | HIGH | SPEC-ONLY |
| D2 | Cache policy | B3: "Cache allowed for static grep (1h TTL)" | N/A — 0 bash cache calls; spec contradicts ADR-22 NEVER | MEDIUM | ❌ SPEC-DRIFT |
| D3 | CDG flag | cdg_flags=[] (no CDG — weaker than other probes) | N/A | — | N/A (no CDG = OK per dim.json cdg=false) |
| D4 | Profile routing | dim.json: quick=❌, standard=✅ | **profile-resolver: quick=❌, standard=✅** | — | ✅ MATCH |
| D5 | Source dir | Hardcoded `src/` | N/A | LOW | SPEC-DRIFT |

### Probe 7: `P-QD3-security-header-audit`

| Phase | Mô tả từ probe spec | Notes/Discrepancy |
|---|---|---|
| **SENSE** | Static grep: helmet detection, CSP config, CSP unsafe-inline/eval, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy. Django SecurityMiddleware patterns. Runtime (deep+exhaustive): `curl -D -` rồi grep response headers. | Tech stack: TS/TSX/JS/PY/GO/YAML/YML/JSON/conf — broader. **Profile mismatch:** dimension.json `depth=["deep","exhaustive"]` (chỉ 2 profiles). _shared.md §4 standard không list probe này. SKILL.md routing table standard ❌. dimension.json exit_criteria.standard không bao gồm probe này. ✓ KHỚP. |
| **THINK** | HIGH: missing CSP/HSTS/X-Content-Type-Options. MEDIUM: missing X-Frame-Options/Referrer-Policy/Permissions-Policy, CSP unsafe-inline/eval. CDG: chỉ CRITICAL (full CSP missing on production). | (i) "Multiple production headers missing >=3 required" → cumulative HIGH — interesting heuristic. (ii) DISCREPANCY-1: B3 "Cache allowed for static grep (1h TTL). Runtime NEVER cached." — cache split policy mâu thuẫn ADR-22 Rule 6. |
| **ACT** | Signal `HEADER-{name}-{action}`. cdg_flags=[] (không CDG cho any). Static evidence=grep_match, runtime=http_response_header. | DISCREPANCY-3 NOT applicable (probe này không gắn CDG). |
| **VERIFY** | Runtime missing-header signal có evidence.type=http_response_header, static có target. **Caching: static 1h, runtime no-cache** — vi phạm ADR-22. | Spec self-contradiction: VERIFY check "static co cache TTL (1h)" nhưng ADR-22 Rule 6 NEVER cache. |
| **Verdict Phase 1→2** | **PARTIAL_MISMATCH** CONFIRMED (D2 cache spec-drift, D4 routing: dim.json standard=❌ nhưng profile-resolver standard=✅). | No bash. Cache mention is spec-level contradiction only (no impl). |

**Spec ↔ Implementation (Phase 2):**

| # | Aspect | Spec | Impl (bash/runtime) | Severity | Status |
|---|---|---|---|:-:|:-:|
| D1 | Bash script | Implied (grep+curl steps) | NOT FOUND — SPEC-ONLY | HIGH | SPEC-ONLY |
| D2 | Cache policy | B3: "Cache allowed for static grep (1h TTL). Runtime NEVER cached." — split policy | N/A — 0 bash cache calls; split policy contradicts ADR-22 NEVER | MEDIUM | ❌ SPEC-DRIFT (cache split) |
| D3 | CDG flag | cdg_flags=[] for all (even CRITICAL — spec says CRITICAL only when "full CSP missing on production") | N/A | LOW | N/A (consistent with dim.json cdg=false) |
| D4 | Profile routing | dim.json: quick=❌, standard=❌ (deep+) | **profile-resolver: quick=❌, standard=✅** | MEDIUM | ❌ MISMATCH — resolver more permissive than dim.json |
| D5 | Helm/Django detection | TS/PY/GO/YAML/YML — broader than auth-flow-verify | N/A | — | N/A |

### §3 Summary (Phase 1+2)

7 probes: **1 CONFIRMED (Probe 4 bash verified) + 2 MISMATCH (Probe 2 owasp routing, Probe 5 auth-flow routing) + 2 PARTIAL_MISMATCH (Probe 3 deserialize quick, Probe 7 security-header cache+routing) + 2 SPEC-ONLY (Probe 1 dep-vuln, Probe 6 cors)**.

Phase 2 verdict summary (7 per-probe tables added, DoD ≥4 ✅):

| Probe | Phase 1 | Phase 2 | Key finding |
|---|---|---|---|
| Probe 1 (dependency-vuln-scan) | TRUST_SPEC | SPEC-ONLY | No bash; cache spec drift (D2) |
| Probe 2 (owasp-top-ten) | TRUST_SPEC | MISMATCH | Routing: standard=❌ runtime but spec says ✅ (security gap!) |
| Probe 3 (dangerous-deserialize) | TRUST_SPEC | PARTIAL_MISMATCH | Routing: quick=❌ runtime but dim.json says ✅ |
| Probe 4 (secret-detection) | TRUST_SPEC | CONFIRMED ✅ | Bash verified; D5 fingerprint 3-way split |
| Probe 5 (auth-flow-verify) | TRUST_SPEC | MISMATCH | Routing: standard=❌ runtime (security gap!) + CDG-RISK |
| Probe 6 (cors-policy-check) | TRUST_SPEC | SPEC-ONLY | No bash; cache spec drift (D2) |
| Probe 7 (security-header-audit) | PARTIAL_MISMATCH | PARTIAL_MISMATCH | Cache spec drift + routing D4 mismatch confirmed |

**Phase 2 upgraded findings vs Phase 1:**
- Phase 1 had 3 architectural discrepancies (cache, routing, CDG). Phase 2 confirmed + upgraded:
  1. **DISCREPANCY-1**: SPEC-CONFIRMED / IMPL-REFUTED — no bash cache calls exist; spec drift only
  2. **DISCREPANCY-2**: 6 cells mismatch (not 2); dimension.json is outlier; MISMATCH includes security-critical probes
  3. **DISCREPANCY-3**: CDG hard-coded in bash (correct for Probe 4); 6 other probes: CDG risk if using `signal-emit.md` helper without post-emit attachment step
  4. **DISCREPANCY-6**: Fingerprint 3-way split confirmed: spec=4 tokens, protocol=5, bash=6

---

## §Phase 2 Code Trace Summary

> **Phiên 11, 2026-05-08.** Đọc 5 file: `wf-fix-probe-static-secret.sh` (153 dòng) + `profile-resolver.md` (189 dòng) + `signal-emit.md` (228 dòng) + `_shared.md §1` (80 dòng) + grep bash scripts (7 scripts, 0 cache calls).

### Architectural Findings (Phase 2)

**AF-QD3-01: Only 1/7 probes has a bash implementation (CRITICAL coverage gap)**
- Only `wf-fix-probe-static-secret.sh` exists. 6/7 probes are SPEC-ONLY with no runnable implementation.
- Risk: Spec discrepancies in those 6 probes (cache, CDG, routing) cannot be verified at implementation level → all remain theoretical until implemented.
- Link: IMP-QD3-001 (cache), IMP-QD3-003 (CDG), IMP-QD3-004 (tech stack).

**AF-QD3-02: Fingerprint 3-way split (upgrades QD1 Phase 2 finding)**
- `_shared.md §1` comment: 4 tokens (`dim|file|line|probe`).
- `signal-emit.md` `generate_fingerprint()`: 5 tokens (adds `sig_type`).
- `wf-fix-probe-static-secret.sh` line 105: 6 tokens (adds `label` = pattern name).
- Impact: dedup between bash output and `signal-emit.md` helper will miss duplicates (different fingerprints for same physical issue). QD1 Phase 2 found 5 vs 6 — QD3 confirms PLUS adds `_shared.md §1` 4-token spec → 3-way confirmed.
- Cross-dim: strengthens IMP-QD1-007 + IMP-QD3-006 → **MERGE candidate at Stage 2 G2**.

**AF-QD3-03: DISCREPANCY-1 — SPEC-LEVEL ONLY (not implementation bug)**
- Bash `wf-fix-probe-static-secret.sh` correctly enforces `# Cache policy: NEVER` (line 8). Zero cache calls across all 7 bash probe scripts (grep confirmed).
- The 3 probe specs with "Cache allowed" mentions (dep-vuln-scan B2, cors-policy-check B3, security-header-audit B3) are ASPIRATIONAL DOCUMENTATION — not backed by any bash implementation.
- Risk MEDIUM: Future implementers of those 6 probes could follow the spec and introduce cache → ADR-22 violation at implementation time. Spec must be corrected NOW (before implementation).
- Recommendation: Update IMP-QD3-001 priority to P0 CONFIRMED (was P0 tentative Phase 1).

**AF-QD3-04: DISCREPANCY-2 reversed — dimension.json is the outlier (6 cells)**
- Phase 1 assumed SKILL.md was wrong vs dimension.json. Phase 2 found: profile-resolver.md (runtime Pattern A inline) agrees with SKILL.md for the 2 originally-noted cells.
- Full scope: 6 cells mismatch between dimension.json and profile-resolver.md (secret-detection quick, dangerous-deserialize quick, security-header-audit standard, auth-flow-verify standard, owasp-top-ten quick+standard).
- **Critical security gap:** owasp-top-ten and auth-flow-verify excluded from standard profile at runtime, though dimension.json claims they run in standard. Users doing `--profile=standard` get NO OWASP scan and NO auth-flow check.
- Recommendation: Fix dimension.json (6 cells) to match profile-resolver.md — dimension.json is the outdated doc. IMP-QD3-002 severity upgrade: P1 → P0 (security gap).

**AF-QD3-05: DISCREPANCY-3 — CDG implementation split (bash vs protocol vs dimension.json)**
- `wf-fix-probe-static-secret.sh` line 131: `cdg_flags: ["CDG-SECURITY-LIVE"]` inline in signal JSON (correct for Probe 4, matches dimension.json cdg=true).
- `signal-emit.md` helper: emits `cdg_flags: []` by default → CDG attachment requires SEPARATE post-emit jq step (lines 209-213).
- 6 other probes (no bash): CDG-SECURITY-LIVE claims in spec are UNIMPLEMENTED. If future implementers use `signal-emit.md` helper without explicit CDG attachment, all 6 probes lose CDG → users NOT warned before auto-fix.
- Severity: HIGH. IMP-QD3-003 confirmed P0.

**AF-QD3-06: Probe 4 (secret-detection) validates design pattern — template for other probes**
- Probe 4 demonstrates the correct implementation pattern:
  - Independent bash script with `--source-dir` configurable arg
  - `# Cache policy: NEVER` documented at script top
  - CDG hard-coded inline (not relying on separate post-emit step)
  - 6-token fingerprint (dimension+file+line+probe+type+label — most specific)
  - Schema output: lane-signals-v1 (envelope) + signal-v2 (signal) with lane-local fields
- **Recommendation:** All 6 SPEC-ONLY probes should follow this bash template when implemented. IMP-QD3-005 (`--source-dir` adoption) confirmed correct.

### Phase 2 Discrepancy Cross-Reference

| DISCREPANCY | Phase 1 verdict | Phase 2 verdict | Severity change | IMP affected |
|---|---|---|:-:|---|
| DISCREPANCY-1 (cache policy) | Architectural conflict — verify bash | SPEC-LEVEL ONLY (bash correct) | P0 maintained | IMP-QD3-001 confirmed (fix spec docs) |
| DISCREPANCY-2 (routing) | 2 cells SKILL.md vs dim.json | **6 cells dim.json vs profile-resolver.md** (dim.json outlier) | P1 → **P0** | IMP-QD3-002 upgraded |
| DISCREPANCY-3 (CDG policy) | 6/7 specs override dim.json | Bash correct; 6 probes CDG-RISK at implementation time | P0 maintained | IMP-QD3-003 confirmed |
| DISCREPANCY-6 (schema fork) | Likely MERGE with QD1-007 | 3-way split confirmed (4/5/6 tokens) | P1 maintained | IMP-QD3-006 → MERGE IMP-QD1-007 confirmed |
| **DISCREPANCY-7 (NEW)** | N/A | profile-resolver.md Override rule 2 contradicts ADR-22 for QD3 | MEDIUM | New finding: IMP-QD3-002 scope expanded |

## 4. False Positive Scenarios (pre-seed Phase 1)

> **Phase 3 sẽ build fixtures `negative/` để reproduce/refute từng FP.**

| ID | Scenario | Probe affected | Severity expected | Mitigation hint |
|---|---|---|:-:|---|
| **FP-QD3-001** | `.env.example` / `.env.sample` chứa placeholder API keys | secret-detection | LOW | Filter file extension `.example\|.sample` (probe đã filter). Verify Phase 2 bash. |
| **FP-QD3-002** | UUID v4 hoặc base64 hash 64+ chars trong test fixture | secret-detection (hex hash 64+) | MEDIUM | Filter test/__mocks__/fixtures path. Probe đã filter `.test.\|fixtures\|mocks\|examples`. |
| **FP-QD3-003** | Parameterized SQL `db.query("SELECT * FROM users WHERE id = ?", [id])` flagged thành SQLi | owasp-top-ten A03 | HIGH | Probe filter `(?\|$1\|%s\|:param\|@param)` đã có. Verify regex chính xác Phase 2. |
| **FP-QD3-004** | `dangerouslySetInnerHTML={__html: sanitize(content)}` (đã sanitize) | dangerous-deserialize | HIGH | Cần data flow analysis — grep chỉ thấy pattern, không biết sanitization. → Need taint analysis hoặc agent classify. |
| **FP-QD3-005** | `JSON.parse(req.body)` trong Express middleware có error handler global | dangerous-deserialize | HIGH | Probe filter `try\s*\{\|catch` nhưng global error middleware không có local try-catch → false positive. |
| **FP-QD3-006** | Wildcard CORS `*` trong dev environment file (`config.dev.json`) | cors-policy-check | MEDIUM | Filter `dev\|local\|staging` filenames hoặc env=development. Probe chưa filter. |
| **FP-QD3-007** | `eval(jsonString)` chỉ gọi với constant đã hardcoded (no user input) | dangerous-deserialize | CRITICAL | Cần data flow — grep miss. Agent classify mới phân biệt được (deep+exhaustive only). |
| **FP-QD3-008** | `md5(filename)` dùng cho cache busting (không phải password hash) | owasp-top-ten A02 | HIGH | Probe filter `(?:password\|passwd\|pwd)` nhưng A02 grep không link `md5(.*pass)` đến password contextually. |

## 5. False Negative Scenarios (pre-seed Phase 1)

| ID | Scenario | Probe expected to catch | Reason FN | Severity if missed |
|---|---|---|---|:-:|
| **FN-QD3-001** | Secret encoded base64 (vd `Buffer.from('AKIA...', 'base64').toString()`) | secret-detection | 14 regex patterns chỉ match raw form. Encoded bypass. | CRITICAL |
| **FN-QD3-002** | SQL injection qua ORM raw query: `User.raw('SELECT * FROM users WHERE id = ' + userId)` | owasp-top-ten A03 | Probe grep `SELECT.*FROM.*+` có thể match nhưng filter `(?\|$1\|%s)` có thể skip nếu literal `+` không có placeholder. | CRITICAL |
| **FN-QD3-003** | Auth bypass qua middleware ordering (auth registered AFTER route) | auth-flow-verify | Static grep không phát hiện ordering bug. Chỉ runtime test endpoint mới catch (deep+exhaustive only). | CRITICAL |
| **FN-QD3-004** | JWT alg=none truyền qua header `{"alg":"none"}` runtime | owasp-top-ten A07 / auth-flow-verify | Pattern grep `algorithm.*none` chỉ match nếu hardcoded trong source. Header forgery missed. | CRITICAL |
| **FN-QD3-005** | Mass assignment vulnerabilities (POST handler `User.update(req.body)`) | owasp-top-ten | Không có pattern dedicated. Có thể match A01 broadly nhưng confidence thấp. | HIGH |
| **FN-QD3-006** | Server-Side Request Forgery qua URL redirect chain (302 → internal IP) | owasp-top-ten A10 | A10 grep `fetch\(\|axios` filter `("https?://[^$]\|'https?://[^$])` → chỉ catch user-controlled URLs trong literal string. Redirect chain missed. | HIGH |
| **FN-QD3-007** | XML External Entity (XXE) attack | owasp-top-ten | KHÔNG có probe dedicated XXE. Chỉ generic A03 injection có thể match `parseXML\|DocumentBuilder` nhưng confidence thấp. | HIGH |
| **FN-QD3-008** | Race condition (TOCTOU) trong file upload validation | (none) | KHÔNG có probe dedicated. Owasp A04 design issue mention nhưng không có pattern. | HIGH |
| **FN-QD3-009** | Open redirect `res.redirect(req.query.next)` không validate | owasp-top-ten A01 | Pattern `req.query.` flagged nhưng không link `redirect()` contextually. | MEDIUM |
| **FN-QD3-010** | Subdomain takeover (CNAME pointer to abandoned cloud bucket) | (none) | Infrastructure-level vuln. Lane này không scan DNS. | MEDIUM |

## 6. Tech Stack & i18n Bias

### 6.1 Tech stack support matrix (per probe)

| Probe | Node/JS/TS | Python | Java | C# / .NET | Go | PHP | Ruby | Mức coverage |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|---|
| `dependency-vuln-scan` (manifests) | ✅ package.json | ✅ requirements.txt | ✅ pom.xml | ❌ csproj | ✅ go.mod | ❌ composer.json | ✅ Gemfile | 5/7 — missing .NET, PHP |
| `owasp-top-ten` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 7/7 — strongest |
| `dangerous-deserialize` | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | 5/7 — missing Go, Ruby |
| `secret-detection` (regex universal) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 7/7 — language-agnostic |
| `auth-flow-verify` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | **2/7 — weakest, blocker** |
| `cors-policy-check` | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | 3/7 |
| `security-header-audit` | ✅ helmet | ✅ Django | ❌ | ❌ | ✅ | ❌ | ❌ | 3/7 |

→ **Coverage uneven:** owasp-top-ten + secret-detection (7/7) >> auth-flow-verify (2/7). .NET projects sẽ có blind spot lớn (dependency-vuln-scan, auth-flow-verify, cors-policy-check, security-header-audit đều miss .NET).

### 6.2 i18n bias

| Phrase pattern | Latin-only? | Risk |
|---|:-:|---|
| `password\|passwd\|pwd` (auth-flow-verify) | ✅ Latin | Miss `mat-khau`, `mật khẩu`, `암호`, `пароль`, `كلمة المرور` |
| `admin.*admin\|password.*password\|admin.*123456\|root.*toor` (owasp A05) | ✅ Latin | Miss localized default credentials |
| Comment filter `(example\|placeholder\|TODO\|FIXME)` (secret-detection) | ✅ EN | Miss `chú thích`, `пример`, `예제`, `示例`, `مثال` |
| Login form text grep `jwt\|token\|bearer` | ✅ EN-tech | Token + bearer là chuẩn HTTP, ít i18n risk |
| Error message detection (none — no probe scan response body) | N/A | — |

**i18n risk level:** MEDIUM. Affects FP rate (Vietnamese/Russian/Asian projects) hơn FN rate. Scope ngoài lane này — comment language không phải security-critical.

## 7. Edge Cases bị miss

| EC-ID | Edge case | Probe nào (nếu có) | Severity if exploited | Lý do miss |
|---|---|---|:-:|---|
| **EC-QD3-001** | JWT key confusion (HS256 ↔ RS256 attack via header alg switch) | (none — needs runtime) | CRITICAL | Static grep không thấy. Auth-flow-verify runtime hẹp. |
| **EC-QD3-002** | Mass assignment via `Object.assign(user, req.body)` overwriting `isAdmin` | (none) | HIGH | Không có probe dedicated. Generic A01 pattern không link contextually. |
| **EC-QD3-003** | Cookie SameSite=None without Secure flag | auth-flow-verify (partial) | HIGH | Probe grep `sameSite` nhưng không link với `secure: true`. |
| **EC-QD3-004** | GraphQL introspection enabled in production | (none) | MEDIUM | Lane không scan GraphQL config files (`apollo.config.js`, schema introspection flag). |
| **EC-QD3-005** | Session fixation (reuse pre-auth session ID post-login) | auth-flow-verify (partial) | HIGH | Probe không phát hiện session regenerate pattern. Cần dynamic test. |
| **EC-QD3-006** | TOCTOU race condition (file upload validation → use) | (none) | HIGH | Không có probe TOCTOU. |
| **EC-QD3-007** | Open redirect `res.redirect(userInput)` | owasp A01 (partial) | MEDIUM | Probe không link `redirect()` với user input contextually. |
| **EC-QD3-008** | Server-Side Template Injection (SSTI) `{{ user.input }}` rendered | (none) | CRITICAL | Không có probe SSTI. |
| **EC-QD3-009** | LDAP injection `cn=' + username` | (none) | HIGH | Không có probe LDAP. |
| **EC-QD3-010** | Insecure JWT in localStorage (XSS-stealable) | (none — needs UI scan) | HIGH | Lane không scan client-side storage. Có thể bridge qua QD5 UX. |
| **EC-QD3-011** | Path traversal `..` qua user input filename | owasp A01 (partial) | HIGH | Pattern không có dedicated, generic A01 broad. |
| **EC-QD3-012** | Cryptography: Math.random() dùng cho token generation | owasp A02 (partial) | HIGH | A02 grep `MD4\|MD5\|SHA1\|...` nhưng không có `Math.random` cho crypto context. |
| **EC-QD3-013** | Subdomain takeover (CNAME → abandoned bucket) | (none) | HIGH | Infrastructure-level. Out of scope. |
| **EC-QD3-014** | Webhook signature verification missing (`X-Hub-Signature` header check) | (none) | HIGH | Không có probe webhook auth. |
| **EC-QD3-015** | XXE qua XML parser (`new DocumentBuilder()`, no DOCTYPE disabled) | (partial owasp) | HIGH | Generic A03 broad pattern, không dedicated. |

## 8. Recommendations — IMP candidates Phase 1 (pre-seed)

> **Note:** Pre-seed dựa trên Phase 1 static review. Sẽ refine ở Phase 4 (cross-probe) + Phase 5 (synthesize). Mọi IMP-QD3-NNN là **dim-local namespace** (không clash với global IMP-NNN ở `10-improvement-roadmap.md`). Stage 2 G2 sẽ MERGE hoặc add new.

| ID | Recommendation | Priority | Effort | Owner | Evidence (Phase 1) |
|---|---|:-:|:-:|---|---|
| **IMP-QD3-001** | **Resolve cache policy spec drift.** 3 probe specs (`dependency-vuln-scan` B2, `cors-policy-check` B3, `security-header-audit` B3) ghi "Cache allowed (1h/24h TTL)" mâu thuẫn ADR-22 Rule 6 + `_shared.md §2` + `SKILL.md PRE-GATE step 8`. → Hoặc xóa cache mention khỏi 3 probe specs (ADR-22 thắng), hoặc relax ADR-22 cho non-secret probes (có justification riêng). | P0 | M | architect + security | §3 Probe 1/6/7, §1 DISCREPANCY-1 |
| **IMP-QD3-002** | **Fix dimension.json routing — 6 cells mismatch vs profile-resolver.md (Phase 2 UPGRADED P1→P0).** Phase 2 confirmed: dimension.json là outlier (profile-resolver.md + SKILL.md đồng thuận). `owasp-top-ten` và `auth-flow-verify` chỉ chạy deep+ ở runtime nhưng dim.json nói standard → user dùng `--profile=standard` KHÔNG có OWASP scan và auth-flow check. Security gap nghiêm trọng. Fix: update 6 cells trong dimension.json → {secret-detection quick=✅, dangerous-deserialize quick=❌, security-header-audit standard=✅, auth-flow-verify standard=❌, owasp-top-ten quick=❌ standard=❌}. Also fix profile-resolver.md Override rule 2 caveat cho QD3 (ADR-22 NEVER cache, rule vô hiệu). | **P0** | S | wf-fix-bugs author + architect | §2 DISCREPANCY-2, §Phase 2 AF-QD3-04 |
| **IMP-QD3-003** | **Clarify CDG flag policy: dimension.json vs probe specs.** dimension.json chỉ secret-detection `cdg=true`. Nhưng 6/7 probe specs (dependency-vuln-scan, owasp-top-ten, dangerous-deserialize, auth-flow-verify, cors-policy-check) tự attach `CDG-SECURITY-LIVE` cho CRITICAL signals. Cần định nghĩa rõ: probe spec authoritative (per-signal CDG decision) hay dimension.json gate (whole-probe enable/disable). Recommend: per-signal CDG (probe spec wins) + dimension.json `cdg` chỉ là default trigger flag. | P0 | S | architect + wf-fix-bugs author | §2 DISCREPANCY-3, §3 Probes 1-6 |
| **IMP-QD3-004** | **Expand tech stack coverage cho `auth-flow-verify` + `cors-policy-check` + `security-header-audit`.** auth-flow-verify chỉ cover 2/7 stacks (Node + Python), miss Java/Spring Security, .NET Identity, Go gin/echo, PHP Laravel. cors-policy-check + security-header-audit cover 3/7. → Add patterns cho .NET (Microsoft.AspNetCore.Cors, Microsoft.AspNetCore.Authentication), Java (Spring Security `@PreAuthorize`, `WebSecurityConfigurerAdapter`, CorsConfigurationSource), Go (chi-cors, fiber-cors). | P1 | L | security agent + per-stack experts | §6.1 — auth-flow-verify 2/7, cors 3/7, headers 3/7 |
| **IMP-QD3-005** | **Hardcoded `src/` path → `--source-dir` argument.** 6/7 probes (only secret-detection có `--source-dir "${SOURCE_DIR:-src/}"`) hardcoded `src/` trong grep. Monorepo (`apps/backend/src`, `packages/shared/src`) sẽ scan miss. Cần unify: tất cả probes accept `--source-dir` argument từ orchestrator (tương tự P-QD1-static-xref). | P1 | M | wf-fix-security author | §3 Probes 2/3/5/6/7, §6.1 |
| **IMP-QD3-006** | **Probe spec ↔ schema fork (similar to QD1-007).** `_shared.md §1` định nghĩa signal schema cũ (fields: `target.kind`, `evidence: {dict}`, `dedup_hints`, `suggested_severity`, `emitted_at`) — giống schema bus signal-v2 nhưng không khớp lane-signals-v1 mà bash output. Cần verify Phase 2 actual schema runtime. Có thể MERGE với IMP-QD1-007 ở Stage 2 G2 (cross-cutting cho mọi lane). | P1 | M | architect | §3 Probe spec schema vs `lane-signals-v1` (bash output) |
| **IMP-QD3-007** | **Add taint analysis hoặc agent classify cho FP reduction.** FP-QD3-004 (`dangerouslySetInnerHTML` đã sanitize), FP-QD3-005 (`JSON.parse` có global error handler), FP-QD3-007 (`eval` với constant), FP-QD3-008 (`md5(filename)` cho cache busting). Grep không phân biệt context → false positive cao. Recommend: agent classify ở deep+exhaustive (đã có cho `owasp-top-ten`); apply pattern này cho `dangerous-deserialize`. | P2 | L | security agent author | §4 FP-QD3-004/005/007/008 |
| **IMP-QD3-008** | **Add 4 missing probe categories cho high-impact FN.** EC-QD3-002 (mass assignment), EC-QD3-006 (TOCTOU), EC-QD3-008 (SSTI), EC-QD3-014 (webhook signature). Mỗi category có pattern signature đủ rõ để static grep với confidence cao. → Đề xuất `P-QD3-mass-assignment-detect`, `P-QD3-ssti-detect`, `P-QD3-webhook-sig-verify`. (TOCTOU stays in EC-only — runtime detection complex.) | P2 | L | security agent + architect | §7 EC-QD3-002/006/008/014 |
| **IMP-QD3-009** | **Add `execution_order` / `parallel_groups` field trong `dimension.json` QD3.** Khai báo 3-layer DAG machine-readable: (1) static layer — parallel-safe (code input only): SEC, DVS, DES, OWA; (2) runtime layer — parallel (needs base_url); serialize COR→HDR hoặc dùng shared curl result để tránh parallel race (REDUN-QD3-003); (3) agent layer — sequential last, pre-check phase3-architecture tồn tại TRƯỚC khi spawn agent (E044 early-fail với visible warning thay vì silent skip). Thiếu field này: orchestrator naive-serialize 7 probes = 375s deep vs DAG-optimized 195s (Phase 4 §4.8 quantified -48%). Cùng gap với IMP-QD1-008 (QD1 dimension.json). **MERGE candidate** với IMP-QD1-008 tại Stage 2 G2 → unified cross-dim fix cho tất cả `dimension.json` files. | P1 | S | architect + wf-fix-bugs author | §Phase 4 §4.6 ORDER-QD3-001, §4.8 wall-clock (375s→195s = -48%), CASCADE-QD3-003 |
| **IMP-QD3-010** | **auth-flow-verify early-warning + partial fallback khi `phase3-architecture` docs missing.** Hiện tại: E044 fire → SILENT SKIP ghi vào `lane-status.json` nhưng KHÔNG hiển thị trong `lane-report.md` → user tin auth đã được kiểm tra khi thực ra bị skip. auth-flow-verify là **probe DUY NHẤT** trong QD3 catching auth bypass CRITICAL + JWT alg=none + missing RBAC + hardcoded JWT secret + password policy gaps (CASCADE-QD3-003). Fix 2-part: (1) Emit WARN signal `AUTH-FLOW-SKIP-NO-ARCH` into lane-report.md visible section với guidance "Run /wf-design first"; (2) Partial fallback mode: chạy JWT/RBAC static grep không cần arch docs (detect `alg:none`, hardcoded JWT secret, missing `@PreAuthorize` / `verifyToken` patterns) → cover ~40% của full auth-flow-verify scope mà không cần Phase 3 docs. | P1 | S | wf-fix-security author | §Phase 4 §4.4 CASCADE-QD3-003, §4.3 E5 (DOC GATE unique — chỉ probe này có), §3 Probe 5 Verdict |
| **IMP-QD3-011** | **Cross-probe dedup namespace cho 3 overlapping signal type pairs.** (1) `CVE-{pkg}-{sev}` (dep-vuln-scan) ↔ `OWASP-A06-{hash8}` (owasp-top-ten) — cùng CVE package = 2 signals, inflated count, false severity escalation via `max_aggregation:true`; dedup key: `{file_path, package_name, cve_type}`. (2) `DESER-{lang}-{pattern}-{hash8}` (dangerous-deserialize) ↔ `OWASP-A08-{hash8}` (owasp-top-ten) — cùng eval/deser pattern = 2 signals + agent re-confirm at deep+ wastes tokens; dedup key: `{file_path, line_range, pattern_class}`. (3) `CORS-{cat}-{hash8}` (cors-policy-check) ↔ `HEADER-Access-Control-{action}` (security-header-audit) — cùng CORS header từ runtime curl response = 2 signals. Implement shared `dedup_hints` namespace trong signal aggregation (`dimension.json severity_rules`). **MERGE candidate** với IMP-QD1-011 (unified dedup namespace cho tất cả lanes) tại Stage 2 G2. | P1 | M | architect | §Phase 4 §4.5 REDUN-QD3-001/002/003, Phase 2 AF-QD3-02 (fingerprint 3-way split confirms dedup broken) |
| **IMP-QD3-012** | **Per-file CDG dedup tại deep+ profile.** Deep+ profile: `secret-detection` (bash confirmed `CDG-SECURITY-LIVE` ALL signals) + `owasp-top-ten` CRITICAL injection (spec claims CDG-SECURITY-LIVE when implemented) + `auth-flow-verify` CDG nếu được implement (DISCREPANCY-3). File có BOTH hardcoded secret + SQL injection → nhiều CDG prompts cho cùng file → user fatigue → "approve all" → defeats CDG security gate purpose (CORE-027 violation at deep+ profile). Fix: CDG dedup key `{file_path, session_id}` — fire CDG ONCE per file per session, aggregate thành 1 prompt hiển thị tất cả critical signals từ file đó. Scope nhỏ (deep+ only) nhưng quan trọng khi QD3 được fully implemented. | P2 | S | wf-fix-bugs author | §Phase 4 §4.4 CASCADE-QD3-002, `dimension.json:257 max_aggregation:true`, DISCREPANCY-3 |

### §8.1 Priority Order Rationale — Revised (Phase 1+2+3+4 evidence)

> **Revised sau Phase 4 cross-probe DAG.** Layer structure nâng từ 3→4 dựa trên security impact quantification + Phase 4 evidence. IMP-QD3-002 upgrade lên L0 (không chỉ là doc inconsistency — là FALSE SECURITY GUARANTEE). 4 new IMPs QD3-009..012 phân bổ vào L2 + L3.

**Layer L0 (P0 — Security-Critical: fix TRƯỚC khi user tin tưởng standard-profile security output):**
- **IMP-QD3-002** (routing gap — PHASE 4 UPGRADED) — CASCADE-QD3-001 QUANTIFIED: `--profile=standard` = 40% OWASP coverage (A1 broken access control, A3 injection, A4 insecure design, full A7 auth failures, A9 logging/monitoring, A10 SSRF: hoàn toàn undetected). Fix → ~80-90% OWASP coverage. HIGHEST ROI trong 12 IMPs (6 cell dimension.json edit = 10%→90% user security assurance). Standard profile là lựa chọn phổ biến nhất → false sense of security at scale.
- **IMP-QD3-003** (CDG flag policy) — Phase 2 AF-QD3-05 confirmed: 6/7 probes có CDG-RISK tại implementation time. Nếu future implementers dùng `signal-emit.md` helper mà không attach CDG → security gate CORE-027 broken → auto-fix chạy mà không có user confirm cho CRITICAL vulnerabilities.

**Layer L1 (P0 — Architectural correctness: blocker TRƯỚC khi implement 6 SPEC-ONLY probes):**
- **IMP-QD3-001** (cache policy drift) — Phase 2 AF-QD3-03 confirmed bash hiện tại correct (`# Cache policy: NEVER`, zero cache calls). Nhưng 3 probe specs (`dep-vuln-scan` B2, `cors-policy-check` B3, `security-header-audit` B3) ghi "Cache allowed" → future implementers có thể follow spec → ADR-22 Rule 6 violation at implementation. Pre-implementation blocker: fix spec TRƯỚC khi implement 6 SPEC-ONLY probes. Also: cascade với IMP-QD1-005 retry pattern nếu probes được gate qua ADR-22 audit.

**Layer L2 (P1 — Coverage + Ordering + Consistency: improve quality và completeness):**
- **IMP-QD3-004** (tech stack expansion) — auth-flow-verify chỉ cover 2/7 stacks (JS/PY) là blocker cho .NET/Java/Go projects. cors-policy-check + security-header-audit 3/7. Add patterns cho Java Spring Security, .NET Microsoft.AspNetCore, Go gin/echo.
- **IMP-QD3-005** (`--source-dir` unification) — monorepo adoption blocked: 6/7 probes hardcode `src/`. Phase 3 IMP-QD3-005 scope expanded: `cd` path-dependency gap confirmed live.
- **IMP-QD3-006** (schema fork) → **MERGE IMP-QD1-007** — fingerprint 3-way split confirmed (spec=4, protocol=5, bash=6 tokens). Cross-dim unified fix cho tất cả lanes tại Stage 2 G2.
- **IMP-QD3-009** (execution_order field) → **MERGE IMP-QD1-008** — Phase 4 §4.8 quantified: deep sequential 375s vs DAG-optimized 195s (-48%). Cùng gap trong QD1 dimension.json → unified cross-dim fix.
- **IMP-QD3-010** (auth-flow-verify early-warning) — Phase 4 CASCADE-QD3-003: silent skip của probe CRITICAL nhất (only auth bypass detector) cần visible warning trong lane-report.md + partial JWT/RBAC static fallback (~40% coverage tanpa arch docs).
- **IMP-QD3-011** (cross-probe dedup) → **MERGE IMP-QD1-011** — 3 overlap pairs (CVE↔OWASP-A6, DESER↔OWASP-A8, COR↔HDR). Unified `dedup_hints` namespace cross-cutting fix cho tất cả lanes.

**Layer L3 (P2 — Quality polish: reduce noise + expand long-term coverage):**
- **IMP-QD3-007** (taint analysis) — FP reduction cho `dangerous-deserialize` + `owasp-top-ten`: JSON.parse global error handler, eval constant, dangerouslySetInnerHTML sanitized, md5 cache busting. Agent classify tại deep+ (đã có cho owasp-top-ten) → extend sang dangerous-deserialize.
- **IMP-QD3-008** (missing probe categories) — add `P-QD3-mass-assignment-detect`, `P-QD3-ssti-detect`, `P-QD3-webhook-sig-verify`. Coverage expansion (EC-QD3-002/008/014). Long-term: TOCTOU remains EC-only (runtime detection complexity).
- **IMP-QD3-012** (per-file CDG dedup) — Phase 4 CASCADE-QD3-002: CDG overload at deep+ breaks user review workflow. Priority P2 (deep+ = advanced users only; lower blast radius than L0/L1/L2 issues).

**MERGE summary tại Stage 2 G2 — cross-dim IMPs:**

| QD3 IMP | Merges with | Cross-dim scope |
|---|---|---|
| IMP-QD3-006 | IMP-QD1-007 | Unified fingerprint format (all lanes, all dim.json) |
| IMP-QD3-009 | IMP-QD1-008 | `execution_order` / `parallel_groups` in all dimension.json files |
| IMP-QD3-011 | IMP-QD1-011 | Unified `dedup_hints` namespace (all lanes) |

**Phase 5 final count: 12 IMPs total** (8 Phase 1 + 4 Phase 4) — Priority distribution: 2 P0-security + 1 P0-arch + 6 P1 + 3 P2. Stage 2 G2 MERGE will collapse 3 pairs → net ~9 cross-dim IMPs from QD3.

## Phase 3 — Test Fixtures ✅ DONE (2026-05-08, Phiên 12)

> **Kết quả:** `fixtures/qd3-test/` với 5 positive (AWS key, Stripe Live, generic password, DB URL postgres, Bearer hardcoded) + 5 negative (.example ext, .test.ts EXCLUDE, comment filter, md5 cache busting, .md ext). `accuracy-report.md` đầy đủ.
> **Metrics:** P_strict=0.83, R=1.00, F1_strict=0.91. 6 live signals (5 intended + 1 f-string bonus pos-03). 0 FP from negative set. CDG-SECURITY-LIVE ✅ all 6. DoD 9/9 PASS.
> **Key findings:** (1) F-string Python `f"postgresql://{username}:{password}@..."` triggered Database URL pattern → FP-QD3-008 live confirmed; (2) Path-dependency gap: probe must `cd` to fixture dir to avoid EXCLUDE_PATTERN match — IMP-QD3-005 scope expanded.

---

## Phase 4 — Cross-Probe DAG ✅ DONE (2026-05-08, Phiên 13)

> **Mục tiêu:** Phân tích dependencies giữa 7 probes QD3, xây dựng execution DAG, tìm cascade failures, redundancy patterns, ordering gaps, và coverage impact của profile gap.
> **Evidence files:** `dimension.json:9-202` (probe array, no execution_order field) + `wf-fix-security/SKILL.md:59-73` (Phase 1 SENSE/Phase 2 ACT prose, not machine-readable) + Phase 2 AF-QD3-01..06 + DISCREPANCY-2 routing table (6 cells) + profile-resolver.md (runtime truth).

### 4.1 Probe DAG (Mermaid)

```mermaid
flowchart TD
  classDef live fill:#c8e6c9,stroke:#2e7d32,stroke-width:2px
  classDef gap fill:#fff9c4,stroke:#f9a825,stroke-width:1px,stroke-dasharray:4 4
  classDef critical fill:#ffcdd2,stroke:#c62828,stroke-width:2px

  subgraph STATIC ["STATIC LAYER (parallel-safe, code input only)"]
    SEC["P-QD3-secret-detection\n✅ std+ live | 30s/2K\n🔴 CDG-SECURITY-LIVE ALL signals\n⭐ RUN FIRST (fastest + CDG)"]
    DVS["P-QD3-dependency-vuln-scan\n🟡 std+ SPEC-ONLY | 60s/3K"]
    DES["P-QD3-dangerous-deserialize\n🟡 std+ SPEC-ONLY | 30s/2K"]
    OWA["P-QD3-owasp-top-ten\n🔴 deep+ ONLY (runtime gap!) | 45-75s/4K\n🟡 SPEC-ONLY — DISCREPANCY-2"]
  end

  subgraph RUNTIME ["RUNTIME LAYER (parallel, needs base_url)"]
    COR["P-QD3-cors-policy-check\n🟡 std+ SPEC-ONLY | 30s/1.5K"]
    HDR["P-QD3-security-header-audit\n🟡 std+ SPEC-ONLY | 30s/1.5K\n(resolver std+ vs dim.json deep+)"]
  end

  subgraph AGENT ["AGENT LAYER (needs code + phase3-arch + optional base_url)"]
    AUTH["P-QD3-auth-flow-verify\n🔴 deep+ ONLY (runtime gap!) | 120s/10K\n🟡 SPEC-ONLY — DOC GATE (unique!)"]
  end

  CODE[("Source Code\nrequired_inputs: code")] -->|input| SEC
  CODE -->|input| DVS
  CODE -->|input| DES
  CODE -->|input| OWA
  CODE -->|input| AUTH

  BASE_URL[("base_url\noptional — server running")] -->|"E047: skip if missing"| COR
  BASE_URL -->|"E047: skip if missing"| HDR
  BASE_URL -.->|"runtime part\n(static grep still runs)"| AUTH
  BASE_URL -.->|"exhaustive: npm/pip audit"| DVS

  ARCH[("phase3-architecture\nrequired — UNIQUE to AUTH")] -->|"E044: SILENT SKIP if missing"| AUTH

  SEC -->|"🔴 CDG-SECURITY-LIVE\n(bash confirmed)"| BUS
  DVS -.-> BUS
  DES -.-> BUS
  OWA -.->|"CDG-RISK (spec claim)\nif implemented deep+"| BUS
  COR -.-> BUS
  HDR -.-> BUS
  AUTH -.->|"CDG-RISK for missing_auth\n(DISCREPANCY-3)"| BUS

  BUS{"Signal Bus\nmax_aggregation=true\n⚠️ 3-way fingerprint split (Phase 2 D5)\n⚠️ CDG overload risk at deep+\n⚠️ DVS-OWA A6 overlap\n⚠️ DES-OWA A8 overlap"}

  class SEC live
  class DVS,DES,COR,HDR,AUTH gap
  class OWA,AUTH critical
```

### 4.2 ASCII Fallback

```
 ┌──────────────────────────── STATIC LAYER (parallel-safe) ─────────────────────────┐
 │  SEC: secret-detection     ✅ live std+    [30s, 2K]  🔴 CDG-SECURITY-LIVE ⭐ FIRST│
 │  DVS: dependency-vuln-scan 🟡 gap  std+   [60s, 3K]                               │
 │  DES: dangerous-deserialize 🟡 gap std+   [30s, 2K]                               │
 │  OWA: owasp-top-ten        🔴 gap  deep+  [45-75s, 4K]  ← ROUTING GAP (std miss!) │
 │                                                                                    │
 │  Inputs: code only — all 4 can run parallel                                       │
 └──────────────────────────────────┬─────────────────────────────────────────────────┘
                                    │ independent (no data handoff)
                    ┌───────────────┼──────────────────────┐
                    ▼               ▼                       ▼
 ┌──────────── RUNTIME LAYER (parallel, needs base_url) ───────────────┐
 │  COR: cors-policy-check     🟡 std+   [30s, 1.5K]                   │
 │  HDR: security-header-audit 🟡 std+   [30s, 1.5K] (resolver)        │
 │  (E047: base_url missing → BOTH SKIP)                                │
 │  (Note: COR + HDR both curl same endpoints → parallel race risk)     │
 └──────────────────────────────────┬──────────────────────────────────┘
                                    │ (no data handoff to agent layer)
                                    ▼
 ┌────────── AGENT LAYER (last — code + phase3-arch required) ─────────┐
 │  AUTH: auth-flow-verify    🔴 deep+ [120s, 10K]  ← ROUTING GAP     │
 │  (E044: phase3-arch missing → SKIP — SILENT! only in lane-status)   │
 │  (E047: base_url missing → skip runtime curl; static grep still OK) │
 └──────────────────────────────────┬───────────────────────────────────┘
                                    │
                                    ▼
                               SIGNAL BUS
                   max_aggregation=true (dimension.json:257)
                   ⚠️ fingerprint 3-way split: 4/5/6 tokens (Phase 2 D5)
                   ⚠️ CDG overload at deep+: SEC + OWA CRITICAL same file
                   ⚠️ DVS↔OWA A6 overlap (same CVE, 2 signals)
                   ⚠️ DES↔OWA A8 overlap (same eval pattern, 2 signals)
                   ⚠️ COR↔HDR CORS header overlap
```

### 4.3 Dependency Edges

| # | From → To | Type | Source (file:line) | Effect khi thiếu |
|---|-----------|------|--------------------|-----------------|
| E1 | Source code → DVS/OWA/DES/SEC/AUTH | **INPUT** (code) | `dimension.json:24,53,82,107,136` `required_inputs:["code"]` | All 5 probes fail if no source code |
| E2 | base_url → COR | **INPUT** (required) | `dimension.json:162` `required_inputs:["base_url"]` | E047: cors-policy-check SKIP |
| E3 | base_url → HDR | **INPUT** (required) | `dimension.json:188` `required_inputs:["base_url"]` | E047: security-header-audit SKIP |
| E4 | base_url → AUTH (runtime) | **INPUT** (optional) | SKILL.md E047: "Skip probe, note skipped_no_base_url" | AUTH runtime curl skip; static grep runs |
| E5 | phase3-architecture → AUTH | **DOC GATE (unique!)** | `dimension.json:136-138` `required_inputs:["phase3-architecture"]` | **E044: AUTH SILENT SKIP** — no visible warning unless lane-status.json logged |
| E6 | base_url → DVS (exhaustive) | **INPUT** (exhaustive only) | SKILL.md: exhaustive calls npm/pip audit | Exhaustive DVS degrades to manifest-only (E045 fallback grep) |
| E7 | SEC → Signal Bus | **CDG ESCALATE** (confirmed) | `dimension.json:114` `cdg:true` + bash line 131 | CDG-SECURITY-LIVE token → gates wf-fix-execute |
| E8 | OWA → Signal Bus (deep+) | **CDG-RISK** (spec claim only) | Probe spec `cdg_flags:["CDG-SECURITY-LIVE"]` for injection CRITICAL | If implemented: 2nd CDG token for same file → CASCADE-QD3-002 |
| E9 | DVS ↔ OWA | **NONE** (static parallel) | Both `required_inputs:["code"]`, no shared state | Safe to parallelize — but CVE overlap (REDUN-QD3-001) |
| E10 | COR ↔ HDR | **NONE** (runtime parallel) | Both `required_inputs:["base_url"]`, independent curl | Safe to parallelize; COR + HDR may curl same endpoint simultaneously |

### 4.4 Cascade Findings

| ID | Finding | Severity | Impact | Profile |
|----|---------|:--------:|--------|---------|
| **CASCADE-QD3-001** | **owasp-top-ten + auth-flow-verify excluded from standard profile — critical security gap.** Per profile-resolver.md (runtime source of truth, Phase 2 AF-QD3-04), standard profile executes only 5/7 probes: dep-vuln-scan, dangerous-deserialize, secret-detection, cors-policy-check, security-header-audit. **Missing**: owasp-top-ten (ALL 10 OWASP categories at exhaustive) + auth-flow-verify (only probe catching auth bypass CRITICAL). dim.json falsely claims both run in standard (DISCREPANCY-2 upgraded P0). **OWASP coverage at standard = 4/10 categories (40%)** — A1 broken access control, A3 injection, A4 insecure design, full A7 auth failures, A9 logging, A10 SSRF all undetected. `--profile=standard` is most common user choice → false sense of OWASP security. Evidence: DISCREPANCY-2, AF-QD3-04, §2 routing table (6 cells), Phase 3 live confirmed profile-resolver truth. | **CRITICAL** | Users running standard think they have security coverage — they do not. IMP-QD3-002 (P0) confirmed + strengthened: fixing routing gap raises standard coverage to ~8/10 OWASP categories. | `standard`, `quick` |
| **CASCADE-QD3-002** | **CDG-SECURITY-LIVE double-fire at deep+ profile for same file.** At deep+ profile: secret-detection (Probe 4, bash confirmed, `dimension.json cdg=true`) + owasp-top-ten CRITICAL (Probe 2 spec claims `CDG-SECURITY-LIVE` for injection/access-control — SPEC-ONLY). `max_aggregation=true` (`dimension.json:257`). File with BOTH hardcoded secret + SQL injection → secret-detection emits CDG (Probe 4 bash) + owasp-top-ten emits CDG when implemented → **2 CDG prompts for same file**. User fatigue: multiple CDG confirmations per file → "approve all" behavior defeats CDG security gate purpose (CORE-027 violation). Evidence: AF-QD3-05, DISCREPANCY-3, `dimension.json max_aggregation:257`, SKILL.md `critical → escalate (CDG required)`. | **MEDIUM** | CDG overload at deep+ breaks user confirmation workflow. IMP-QD3-003 (P0) scope expanded: must define per-file CDG dedup (fire once per file, not per-signal). New IMP-QD3-012 (per-file CDG dedup). | `deep`, `exhaustive` |
| **CASCADE-QD3-003** | **auth-flow-verify SILENT SKIP when phase3-architecture docs missing.** auth-flow-verify is the ONLY QD3 probe with a **DOC dependency**: `required_inputs:["code","phase3-architecture"]` (`dimension.json:136-138`). No other QD3 probe has doc gate. Users who run `/wf-fix-bugs` before completing `/wf-design` (Phase 3 architecture) → E044 fires → auth-flow-verify SKIP. Warning is logged only in `lane-status.json` (not in user-visible lane-report.md). This is the **only probe** catching authentication bypass (CRITICAL) + JWT alg=none + missing RBAC + hardcoded JWT secret + password policy gaps. Silent skip = user believes auth was checked when it was not. Evidence: `dimension.json:136-138`, SKILL.md E044 (`"Skip probe, note skipped_no_architecture"`), §3 Probe 5 VERIFY note. | **HIGH** | Any team running wf-fix-bugs early (pre-Phase 3) silently misses auth verification — most critical probe for authentication security. New IMP-QD3-010 (early warning + partial fallback for doc gate). | deep+ profiles |

### 4.5 Redundancy Findings

| ID | Finding | Severity | Probes overlap | Dedup status |
|----|---------|:--------:|----------------|-------------|
| **REDUN-QD3-001** | **dependency-vuln-scan vs owasp-top-ten A6 — duplicate CVE detection.** dep-vuln-scan SENSE: checks 17 hardcoded CVE packages (express<4.18, lodash<4.17.21, log4j<2.17.1, ...) → signal `CVE-{package}-{severity}`. owasp-top-ten SENSE A6 (Vulnerable and Outdated Components): pattern-matches same packages (`log4j\|struts\|django\|flask` versions) → signal `OWASP-A06-{hash8}`. Same vulnerable dependency (e.g. lodash 4.17.20) → 2 signals with different fingerprints. `max_aggregation:true` → both signals same file → severity may escalate. No cross-probe dedup defined (different signal namespaces, different fingerprint formulae — Phase 2 D5 3-way split). Evidence: §3 Probe 1 SENSE (17 CVE list), §3 Probe 2 THINK (A6 patterns), `dimension.json max_aggregation:257`. | **HIGH** | Same vulnerability counted 2× → inflated signal count, false severity escalation at triage. IMP-QD3-011 (dedup namespace). | No dedup spec |
| **REDUN-QD3-002** | **dangerous-deserialize vs owasp-top-ten A8 — eval/deser pattern overlap.** dangerous-deserialize SENSE: `eval\|Function\|innerHTML\|dangerouslySetInnerHTML\|pickle\|ObjectInputStream\|BinaryFormatter\|PHP unserialize` → signal `DESER-{language}-{pattern}-{hash8}`. owasp-top-ten SENSE A8 (Software and Data Integrity Failures): includes eval/deser patterns in the JS/PY/Java grep. Same `eval(userInput)` or `innerHTML = req.body.html` → 2 signals from 2 probes. At deep+ owasp uses agent classify → agent re-confirms same pattern already flagged by dangerous-deserialize → extra token cost + double entry in issue-registry. Signal namespace: `DESER-*` vs `OWASP-A08-*` → no cross-probe dedup. Evidence: §3 Probe 3 SENSE/THINK vs §3 Probe 2 SENSE/THINK. | **MEDIUM** | Double alert for eval/deser patterns. Agent re-confirm at deep+ wastes tokens. Similar to REDUN-QD1-001 orphan_api double-emit. IMP-QD3-011 (dedup namespace). | No dedup spec |
| **REDUN-QD3-003** | **cors-policy-check vs security-header-audit — CORS/header overlap + parallel curl race.** cors-policy-check scans `Access-Control-Allow-Origin`, `Access-Control-Allow-Credentials`, methods/headers in both static grep (src files) and runtime `curl -X OPTIONS` response. security-header-audit scans ALL response security headers (including `Access-Control-*` fields) via `curl -D -`. If CORS headers permissive: cors-policy-check emits `CORS-wildcard_origin-{hash}` + security-header-audit may also flag same header in response → potential dual signal for CORS misconfiguration. **Additional risk:** both are runtime probes running parallel (Layer 2) needing same base_url → concurrent `curl` to same endpoints → connection overload or response interference on low-capacity test server. Evidence: §3 Probe 6 SENSE (OPTIONS curl) vs §3 Probe 7 SENSE (curl response headers), both `type:runtime` `dimension.json:151,179`. | **MEDIUM** | 2× CORS signal inflates report. Parallel curl race risk on same endpoint. IMP-QD3-011 (dedup) + IMP-QD3-009 (ordering: serialize COR before HDR or use shared curl result). | No dedup spec |

### 4.6 Ordering Findings

| ID | Finding | Severity | Recommendation |
|----|---------|:--------:|----------------|
| **ORDER-QD3-001** | **dimension.json has no execution_order field — static/runtime mixing risk.** `dimension.json:9-202` defines `probes[]` array order: [dep-vuln-scan, owasp-top-ten, dangerous-deserialize, secret-detection, auth-flow-verify, cors-policy-check, security-header-audit]. No `execution_order`, `parallel_groups`, or `dependencies` field exists. SKILL.md separates static (Phase 1 SENSE) vs runtime (Phase 2 ACT) by prose description only — not machine-readable for orchestrator. If orchestrator runs probes linearly per array: sequential 375s (deep). If orchestrator naive-parallelize all 7: static probes (code) + runtime probes (base_url) mixed → cors-policy-check may fire before secret-detection emits CDG → CDG token arrives too late for orchestrator to gate other probes. Evidence: `dimension.json:9-202` (full probe array, no ordering fields), SKILL.md Phase 1/Phase 2 table (prose-only), contrast IMP-QD1-008 (same gap in QD1). | **HIGH** | Add `execution_order` or `parallel_groups` field in dimension.json QD3. Analogous to IMP-QD1-008 — candidate for unified cross-dim fix at Stage 2 G2. New IMP-QD3-009. |
| **ORDER-QD3-002** | **secret-detection should execute first within static layer.** Current position in `dimension.json probes[]` array: 4th (after dep-vuln-scan, owasp-top-ten, dangerous-deserialize). secret-detection: 30s cost (fastest in static layer — min of {60s, 45s, 30s, 30s}), CRITICAL default severity, CDG-SECURITY-LIVE all signals, `cdg:true`. Running 4th means: if secret found, CDG token arrives at T≈165s (after 60+75+30=165s for first 3 probes). Optimal order: secret-detection FIRST → CDG token at T=30s → orchestrator can immediately surface warning to user before scanning further files. Remediation guidance: CDG user confirm before fix — earlier prompt = more meaningful user review. Evidence: `dimension.json estimated_cost fields`, `cdg:true:114`, SKILL.md `critical_triggers: "secret exposed"`. | **MEDIUM** | Reorder `probes[]` array: secret-detection first in static layer. Or add explicit `priority: "CDG_FIRST"` flag in probe definition. IMP-QD3-009 scope: include ordering recommendation. |

### 4.7 Coverage Findings

| ID | Finding | Note |
|----|---------|------|
| **COVERAGE-QD3-001** | **Standard profile covers only 4/10 OWASP Top 10 categories (~40%).** Mapping standard-runtime probes (5/7) to OWASP 2021: `dep-vuln-scan` → A6 (Vulnerable Components) ✓; `dangerous-deserialize` → A8 (partial Software/Data Integrity) ✓; `secret-detection` → A2 (Cryptographic Failures — hardcoded keys) ✓, partial A7 (token exposure) ✓; `cors-policy-check` → A5 (Security Misconfiguration — CORS) ✓; `security-header-audit` → A5 (Security Misconfiguration — headers) ✓. **Uncovered at standard**: A1 (Broken Access Control), A3 (SQL/NoSQL/Command Injection), A4 (Insecure Design), full A7 (Identification and Authentication Failures), A9 (Security Logging/Monitoring Failures), A10 (Server-Side Request Forgery). Probe coverage ratio: 5/7 = 71%. OWASP category coverage: ~4/10 = **40%**. Quick profile (runtime): 2/7 probes → ~3/10 OWASP categories (30%). **Impact quantified:** Fix IMP-QD3-002 (add owasp+auth to standard) → standard OWASP coverage jumps to ~8-9/10 (80-90%). | Directly quantifies CASCADE-QD3-001 severity. Evidence: §3 per-probe SENSE descriptions + OWASP Top 10 2021 mapping. IMP-QD3-002 ROI = highest in QD3 (30→40% OWASP coverage delta per effort = P0 justified). |

### 4.8 Recommended Execution Order

```
Layer 1 (parallel-safe static, ~75s = slowest of 4 probes):
  ├─ P-QD3-secret-detection      [30s]  ← FIRST (fastest, CDG early-warning at T=30s)
  ├─ P-QD3-dangerous-deserialize [30s]
  ├─ P-QD3-dependency-vuln-scan  [60s]
  └─ P-QD3-owasp-top-ten         [45s std / 75s deep — DEEP+ ONLY per routing]

Layer 2 (parallel runtime, ~30s, needs base_url — can start as soon as server confirmed up):
  ├─ P-QD3-cors-policy-check     [30s, std+]
  └─ P-QD3-security-header-audit [30s, std+ per resolver]
  NOTE: serialize COR before HDR or use shared curl result to avoid parallel curl race (REDUN-QD3-003).

Layer 3 (agent last, ~120s, needs code + phase3-arch + optional base_url):
  └─ P-QD3-auth-flow-verify      [120s, DEEP+ ONLY]
     PRE-CHECK: verify phase3-architecture exists BEFORE spawning agent (E044 early-fail with user warning)
```

**Wall-clock estimates:**

| Profile | Probes | Sequential | DAG-optimized | Savings |
|---------|--------|:-----------:|:-------------:|:-------:|
| quick (runtime) | 2: DVS + SEC | 90s | 60s (parallel) | ~33% |
| standard (runtime) | 5: DVS+DES+SEC+COR+HDR | 180s | max(60,30,30) + max(30,30) = 90s | **~50%** |
| deep (all 7) | 7 probes | 375s | max(75,30) + 120 = 195s | **~48%** |
| exhaustive (all 7) | 7 probes | 375s | 195s (same parallelism) | ~48% |

### 4.9 Tóm tắt Findings Phase 4

| Loại | Count | IDs |
|------|:-----:|-----|
| Cascade | 3 | CASCADE-QD3-001, CASCADE-QD3-002, CASCADE-QD3-003 |
| Redundancy | 3 | REDUN-QD3-001, REDUN-QD3-002, REDUN-QD3-003 |
| Ordering | 2 | ORDER-QD3-001, ORDER-QD3-002 |
| Coverage | 1 | COVERAGE-QD3-001 |
| **Total** | **9** | — |

**New IMP candidates từ Phase 4 (sẽ promote tại Stage 2 G2):**

| ID candidate | Title | Priority | Effort | Evidence Phase 4 |
|---|---|:-:|:-:|---|
| **IMP-QD3-009** | Explicit `execution_order` / `parallel_groups` field trong `dimension.json` QD3 — khai báo: static layer parallel-safe, runtime layer parallel (but serialize COR→HDR), agent layer last with DOC GATE check for phase3-arch | P1 | S | ORDER-QD3-001, CASCADE-QD3-003 |
| **IMP-QD3-010** | auth-flow-verify early-warning khi phase3-architecture missing — emit WARN signal hoặc lane-status note rõ ràng (không chỉ `lane-status.json`) + fallback partial mode: JWT grep static (không cần arch docs) | P1 | S | CASCADE-QD3-003, E5 |
| **IMP-QD3-011** | Cross-probe dedup namespace cho overlapping signal types — `CVE-*` ↔ `OWASP-A06-*` (REDUN-001), `DESER-*` ↔ `OWASP-A08-*` (REDUN-002), COR ↔ HDR CORS headers (REDUN-003). Shared `dedup_hints` namespace tương tự IMP-QD1-011. **MERGE candidate** với IMP-QD1-011 tại Stage 2 G2 (cross-dim unified fingerprint) | P1 | M | REDUN-QD3-001/002/003, Phase 2 AF-QD3-02 (fingerprint 3-way split) |
| **IMP-QD3-012** | Per-file CDG dedup — fire CDG once per file (not per-signal) khi multiple CRITICAL probes flag same file at deep+ profile. CDG token = `{file_path, session_id}` dedup key | P2 | S | CASCADE-QD3-002 |

**Cross-dim MERGE candidates (to Stage 2 G2):**
- IMP-QD3-009 ↔ IMP-QD1-008 (DAG ordering in dimension.json — same gap, same fix)
- IMP-QD3-011 ↔ IMP-QD1-011 (unified fingerprint/dedup namespace — cross-lane)

### 4.10 Phase 4 DoD verify

| DoD criterion | Status | Evidence |
|---|:---:|---|
| ≥1 DAG diagram | ✅ 2 (Mermaid §4.1 + ASCII §4.2) | §4.1, §4.2 |
| ≥3 cascade/redundancy/ordering findings | ✅ 9 findings (3C + 3R + 2O + 1Cov) | §4.4–§4.7 |
| Phase 2 evidence referenced | ✅ DISCREPANCY-2 (AF-QD3-04), DISCREPANCY-3 (AF-QD3-05), D5 fingerprint 3-way split, max_aggregation | §4.3 E7/E8, CASCADE-QD3-002 |
| Profile gap impact analysis | ✅ COVERAGE-QD3-001 (~40% OWASP at standard), CASCADE-QD3-001 (0% A1/A3/A4/A7/A9/A10) | §4.4, §4.7 |
| Live/gap probe status reflected | ✅ All DAG nodes labeled (✅ live / 🟡 gap / 🔴 routing gap) | §4.1, §4.4 CASCADE-QD3-001 |

---

## Phase Status

- ✅ **Phase 1 — Static Review** done (Phiên 10, 2026-05-08): §1-§3 + §4-§7 pre-seed + §8 8 IMP candidates. 56 pre-seed findings.
- ✅ **Phase 2 — Code Trace** done (Phiên 11, 2026-05-08): Đọc 5 files (bash script 153 dòng + profile-resolver 189 + signal-emit 228 + _shared.md 80 + grep). 6 AF findings. DISCREPANCY-2 upgraded to 6 cells; dim.json outlier; IMP-QD3-002 P1→P0. 7 Spec↔Impl tables added. 18 new code-trace discrepancies. Bash grep: 0 cache calls across 7 scripts (DISCREPANCY-1 IMPL-REFUTED). Fingerprint 3-way split confirmed.
- ✅ **Phase 3 — Test Fixtures** done (Phiên 12, 2026-05-08): `fixtures/qd3-test/` 5 positive + 5 negative. P_strict=0.83, R=1.00, F1=0.91. 6 live signals. 0 FP. DoD 9/9 PASS.
- ✅ **Phase 4 — Cross-Probe DAG** done (Phiên 13, 2026-05-08): Mermaid + ASCII DAG, 10 edges, 9 findings (3 CASCADE + 3 REDUN + 2 ORDER + 1 COVERAGE). CASCADE-QD3-001 quantifies standard profile = 40% OWASP coverage. CASCADE-QD3-003 identifies unique DOC GATE (phase3-arch). 4 new IMP candidates (QD3-009..012). 2 MERGE candidates with QD1 IMPs.
- ✅ **Phase 5 — Synthesize** done (Phiên 14, 2026-05-08): §8 expanded 8→12 rows (add IMP-QD3-009..012 với Phase 4 evidence links + MERGE notes). §8.1 revised from 3-layer to 4-layer (L0 P0-security + L1 P0-arch + L2 P1-coverage/ordering + L3 P2-polish). IMP-QD3-002 promoted to L0 (Phase 4 CASCADE-QD3-001 quantifies: standard = 40% OWASP). 3 MERGE candidates confirmed (QD3-006↔QD1-007, QD3-009↔QD1-008, QD3-011↔QD1-011). Final: 12 IMPs, 2 P0-security + 1 P0-arch + 6 P1 + 3 P2.

## Liên quan

- Probe specs: `.claude/skills/workflow/wf-fix-security/procedures/probes/`
- Lane skill: `.claude/skills/workflow/wf-fix-security/SKILL.md` v2.0.0-alpha.s4
- Dimension config: `.claude/skills/workflow/wf-fix-security/dimension.json` v1.0.0
- Cross-probe protocols: `.claude/skills/workflow/wf-fix-security/procedures/probes/_shared.md`
- Security agent: `.claude/agents/engineering/security.md`
- ADR-22: `docs/design/skills/wf-fix-bugs/07-tradeoffs-adr.md` Rule 6
- Cross-cutting: [`09-cross-cutting-findings.md`](./09-cross-cutting-findings.md)
- Roadmap merge: [`10-improvement-roadmap.md`](./10-improvement-roadmap.md) (Stage 2 G2)
- Audit precedent: [`02-qd1-functional-audit.md`](./02-qd1-functional-audit.md) (Phase 1 template structure)
