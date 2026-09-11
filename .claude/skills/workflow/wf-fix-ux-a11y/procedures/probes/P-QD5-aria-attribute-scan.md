# P-QD5-aria-attribute-scan — WCAG 2.2 AA Static Markup Audit

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD5-aria-attribute-scan |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Quet WCAG 2.2 AA tinh trang static trong markup: img alt, form labels, ARIA roles, tabindex, anchor href anti-patterns. |
| **Cache** | allowed |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co .tsx/.jsx/.html/.vue/.svelte files → SKIP
```

## SENSE

### B1: Delegate to bash script (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD5-ux-a11y/raw/P-QD5-aria-attribute-scan.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-a11y.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-ux-a11y \
      --probe P-QD5-aria-attribute-scan \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash a11y probe failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-ux-a11y","dimension":"QD5",
 "probe_id":"P-QD5-aria-attribute-scan","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script implements 5 checks:**

1. **WCAG 1.1.1 — `<img>` thieu `alt`:** find `<img>` tags KHONG co `alt=` va KHONG co `aria-hidden="true"`
2. **WCAG 1.3.1 — form control thieu label:** `<input>/<select>/<textarea>` thieu `aria-label` hoac `aria-labelledby` (skip type=hidden/submit/button/reset/image)
3. **WCAG 2.4.3 — tabindex > 0:** anti-pattern lam focus order unpredictable
4. **WAI-ARIA 1.2 — invalid role:** `role="..."` voi value KHONG thuoc 67 valid ARIA roles
5. **WCAG 2.1.1 — `<a href="#">` hoac `href="javascript:"`:** anti-pattern, dung `<button>` cho action

### B2: Filter exclusions

Bash script tu skip:
- `__tests__/`, `test/`, `tests/`, `*.test.*`, `*.spec.*`, `fixtures/`, `node_modules/`, `dist/`, `build/`

### B3: CI Enrichment (BAT BUOC khi SERENA available — find_refs cho component spread analysis)

> **Muc dich:** Bug ARIA trong shared component lan ra rong (vd: `<Button>` thieu aria-label dung tren 50+ trang). Serena `find_referencing_symbols` cho biet pham vi anh huong de bump severity chinh xac.

```bash
if [[ "$SERENA_AVAILABLE" == "true" ]]; then
  # Pseudocode (orchestrator agent thuc hien):
  # FOR each signal trong $RAW_OUT.signals[] (top 30 theo severity):
  #   IF signal.signal_type IN ("missing_alt", "missing_label", "invalid_aria_role", "tabindex_positive"):
  #     # Identify owning component (heuristic: file la component file)
  #     IF signal.target.file_path matches "*/components/*" or "*.tsx":
  #       # Get component symbol
  #       symbols = mcp__serena__get_symbols_overview(signal.target.file_path)
  #       component_class = first(s for s in symbols if s.kind in ["class", "function"] and s.name[0].isupper())
  #       
  #       IF component_class:
  #         refs = mcp__serena__find_referencing_symbols(name_path=component_class.name, relative_path=signal.target.file_path)
  #         signal.evidence.serena_refs_count = refs.length
  #         signal.evidence.serena_refs_top_files = unique([r.file for r in refs])[:5]
  #         
  #         # Bump severity neu component dung lai nhieu
  #         IF refs.length > 10:
  #           signal.suggested_severity = "high" if signal.suggested_severity == "medium" else signal.suggested_severity
  #           signal.evidence.severity_bump_reason = f"shared component used in {refs.length} places"
  #         IF refs.length > 30:
  #           signal.suggested_severity = "critical"
  #           signal.evidence.severity_bump_reason = f"highly-shared component (>{refs.length} usages) — fix lan rong"
  #   
  #   signal.evidence.ci_meta = {gitnexus_used: false, serena_used: true, freshness_level: $FRESHNESS_LEVEL}
fi
```

**Graceful:** Serena absent → skip B3, signals giu severity tu B1.

## THINK

Bash script da implement severity logic:
- `<img>` thieu alt → HIGH (block screen reader)
- Form control thieu label → HIGH (block screen reader)
- Tabindex > 0 → MEDIUM (UX issue)
- Invalid ARIA role → MEDIUM (silent fail)
- `<a href="#">` → LOW (anti-pattern, work-around exists)

**Domain:** `frontend`
**Fixability:** `auto_fix` (most cases — add alt="", aria-label, change tag)

## ACT

Output schema `signal-v2`:
- Title: WCAG/ARIA reference (e.g., "WCAG 1.1.1: <img> thieu alt")
- Description: explanation + remediation hint
- `remediation.suggested_action: "Add missing a11y attribute"`
- `remediation.suggested_agent: "frontend-developer"`
- `remediation.estimated_effort: "trivial"`

SKILL.md emit qua signal-emit.md helper voi lock + dedup.

## VERIFY

1. Moi Signal co `dimension_id == "QD5"`
2. Moi Signal co `evidence[]` voi snippet matched
3. Title bat dau voi "WCAG" hoac "WAI-ARIA"
4. Severity trong [HIGH, MEDIUM, LOW]
5. probe_id match `^P-QD5-[a-z0-9-]+$`
6. Domain == "frontend"

## Severity Rules

| Pattern | Severity | WCAG/ARIA Ref |
|---------|----------|---------------|
| `<img>` thieu alt | HIGH | WCAG 1.1.1 |
| Form control thieu label/aria-label | HIGH | WCAG 1.3.1 |
| `tabindex > 0` | MEDIUM | WCAG 2.4.3 |
| Invalid ARIA role | MEDIUM | WAI-ARIA 1.2 |
| `<a href="#">` hoac `javascript:` | LOW | WCAG 2.1.1 |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Source dir khong co | Skip probe, emit empty signals voi `skip_reason: "no_source_dir"` |
| Bash script fail | SKILL.md fallback: emit empty signals, skip_reason="bash_script_failed" |
| Khong tim thay tags `<img>/<input>/<a>` | Bash script chay xong → 0 signals (clean) |
| Markup trong template literals (vd JSX trong string) | False negative chap nhan — runtime probe se cover (P-QD5-deep-ui-traversal) |
