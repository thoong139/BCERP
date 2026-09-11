# P-QD4-bundle-size-audit — Bundle Size + N+1 Query Audit

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD4-bundle-size-audit |
| **Loai** | static |
| **Profile** | quick, standard, deep, exhaustive |
| **Muc dich** | Phat hien (1) bundle artifacts > threshold KB, (2) N+1 query patterns trong source code. |
| **Cache** | allowed |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co build dir (dist/, build/, .next/, out/) AND khong co source dir → SKIP
IF profile=quick → chi check bundle size, skip N+1 detection
```

## SENSE

### B1: Delegate to bash script (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-bundle-size-audit.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-perf.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-performance \
      --probe P-QD4-bundle-size-audit \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      --build-dir "${BUILD_DIR:-}" \
      --bundle-warn-kb "${BUNDLE_WARN_KB:-500}" \
      --bundle-fail-kb "${BUNDLE_FAIL_KB:-1000}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash perf probe failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"\$schema":"lane-signals-v1","lane":"wf-fix-performance","dimension":"QD4",
 "probe_id":"P-QD4-bundle-size-audit","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- **Bundle size:** find `*.js, *.css, *.mjs` trong build dir → measure size → compare voi threshold (warn=500KB, fail=1000KB default)
- **N+1 patterns:** grep `await ... .findOne|find|query|fetch|get` trong loop context (`for (`, `forEach`, `map`, `reduce`)
- Auto-detect build dir: `dist/`, `build/`, `.next/`, `out/`
- Skip test files, source maps, node_modules

### B2: Threshold customization

Default thresholds:
- Bundle warn: 500 KB → severity=medium
- Bundle fail: 1000 KB → severity=high

Override qua env var hoac CLI args (truyen tu wf-fix-performance SKILL.md).

## THINK

Bash script da implement:
1. **Bundle size severity:**
   - `> 1000 KB` → HIGH (block release)
   - `> 500 KB` → MEDIUM (optimize)
   - `<= 500 KB` → no signal
2. **N+1 detection:**
   - Look 5 lines BEFORE await call → if surrounded by loop construct → emit MEDIUM/HIGH
   - Severity: HIGH (likely performance bug)
3. **Domain:** `frontend` (bundle), `backend` (N+1)
4. **Fixability:** `agent_fix` (frontend-developer cho code-split, developer cho query optimize)

## ACT

Output schema `signal-v2`:
- Bundle: `title: "Large bundle: NNN KB <file>"`, `remediation.suggested_action: "Code-split via dynamic import"`
- N+1: `title: "Possible N+1 query pattern"`, `remediation.suggested_action: "Refactor to batch fetch or dataloader"`

## VERIFY

1. Moi Signal co `dimension_id == "QD4"`
2. Bundle signals co `evidence[]` voi `File size: NNN KB`
3. N+1 signals co `evidence.description` chua snippet
4. Severity trong [HIGH, MEDIUM] (no critical/low cho probe nay)
5. Remediation present cho moi signal

## Severity Rules

| Pattern | Severity |
|---------|----------|
| Bundle > 1000 KB (configurable) | HIGH |
| Bundle 500-1000 KB | MEDIUM |
| N+1 query pattern (await DB call inside loop) | HIGH |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Build dir khong ton tai | Skip bundle check, run N+1 only |
| Source dir khong ton tai | Skip N+1 check, run bundle only |
| Bash script fail | SKILL.md fallback: emit empty signals, skip_reason="bash_script_failed" |
| Cross-platform stat fail | Bash script fallback: BSD `stat -f %z` if GNU `stat -c %s` fail |
