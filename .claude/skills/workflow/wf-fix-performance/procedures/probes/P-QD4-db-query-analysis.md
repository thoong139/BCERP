# P-QD4-db-query-analysis — Phan tich hieu nang truy van database

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD4-db-query-analysis |
| **Loai** | static+runtime |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Phat hien (1) N+1 query patterns, (2) unbounded queries (thieu .limit/.take), (3) nested eager loading (include/include/where chain), (4) raw SQL khong co EXPLAIN, (5) runtime slow queries (neu DB accessible). |
| **Cache** | **allowed** (static part) |
| **Migrates from** | Stage D (new) |

## PRE-GATE

```
IF khong co source dir (src/, app/, lib/, models/) AND khong co DB config -> SKIP, note "no_source_or_db"
IF profile=quick -> SKIP (chi chay standard+)
IF runtime DB check AND (no DB env vars: DATABASE_URL, DB_HOST, MONGODB_URI, etc.) -> chi chay static part, skip runtime EXPLAIN
```

## SENSE

### B1: Delegate to inline bash static analysis (S5 v7.0)

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/raw/P-QD4-db-query-analysis.json"
mkdir -p "$(dirname "$RAW_OUT")"
SIGNALS_JSON='[]'

SOURCE="${SOURCE_DIR:-src/}"
# Fallback neu SOURCE_DIR khong ton tai
if [ ! -d "$SOURCE" ]; then
  for candidate in app lib models repositories daal; do
    [ -d "$candidate" ] && { SOURCE="$candidate"; break; }
  done
fi

# ============================================================
# Static Check 1: N+1 via ORM (eager/relations/includes)
# ============================================================
if [ -d "$SOURCE" ]; then
  # Prisma / TypeORM / Sequelize: nested include/relations within loops
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    # Check if this include is inside a loop construct
    start_line=$((line > 5 ? line - 5 : 1))
    context=$(sed -n "${start_line},${line}p" "$file" 2>/dev/null || echo "")
    if echo "$context" | grep -qE '(for[[:space:]]*\(|\.forEach|\.map\(|\.reduce\()'; then
      fp=$(echo -n "QD4|$file|$line|P-QD4-db-query-analysis|n_plus_one_orm" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
      sig=$(jq -nc \
        --arg file "$file" --argjson line "$line" \
        --arg snippet "$(echo "$match" | head -c 100)" \
        --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
          "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-db-query-analysis",
          probe_version: "v1.0", severity: "high", fixability: "agent_fix", domain: "backend",
          title: "Potential N+1 query (ORM include/relation inside loop)",
          description: ("Phat hien nested ORM relation fetch ben trong loop tai " + $file + ":" + ($line | tostring) + ". Moi vong lap se trigger 1+ DB query. Dung batch loading hoac dataloader."),
          location: {file: $file, line: $line, column: null, selector: null, url: null},
          evidence: [{type: "code", path: $file, description: ($snippet)}],
          cdg_flags: [], fingerprint: $fp,
          remediation: {suggested_action: "Refactor to batch fetch: use Prisma include/TypeORM relations hoac dataloader pattern de gom query", suggested_agent: "dba", estimated_effort: "medium"},
          detected_at: $now, detected_by: "wf-fix-performance/P-QD4-db-query-analysis"
        }')
      SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
    fi
  done < <(grep -rnE '(include|relations|eager|populate|with)\s*[\[:].*\{' "$SOURCE" \
            --include='*.ts' --include='*.js' --include='*.py' --include='*.java' --include='*.go' --include='*.rb' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' || true)

  # ============================================================
  # Static Check 2: Unbounded queries (findAll/findMany/find without limit/take)
  # ============================================================
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    
    fp=$(echo -n "QD4|$file|$line|P-QD4-db-query-analysis|unbounded_query" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg file "$file" --argjson line "$line" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-db-query-analysis",
        probe_version: "v1.0", severity: "high", fixability: "agent_fix", domain: "backend",
        title: "Unbounded query - thieu limit/take",
        description: ("Phat hien query khong co limit tai " + $file + ":" + ($line | tostring) + ". findAll/findMany/find khong co gioi han co the load toan bo bang -> memory exhaustion."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ($snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Them .limit(N) hoac .take(N) de gioi han so luong records. Can nhac cursor-based pagination cho large datasets.", suggested_agent: "dba", estimated_effort: "low"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-db-query-analysis"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done < <(grep -rnE '\.(findAll|findMany|find|all)\s*\(' "$SOURCE" \
            --include='*.ts' --include='*.js' --include='*.py' --include='*.java' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' \
            | grep -vE '\.(limit|take)\(|LIMIT|TOP' || true)

  # ============================================================
  # Static Check 3: Raw SQL without EXPLAIN or param binding
  # ============================================================
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    # Check if it uses parameterized queries
    has_params=false
    if grep -qE '\$[0-9]+|:\w+|\?|%s' <<< "$match"; then
      has_params=true
    fi
    severity="medium"
    [ "$has_params" = false ] && severity="high"  # raw SQL without params = SQL injection + perf risk
    
    fp=$(echo -n "QD4|$file|$line|P-QD4-db-query-analysis|raw_sql" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg file "$file" --argjson line "$line" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg severity "$severity" --arg fp "$fp" \
      --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-db-query-analysis",
        probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "backend",
        title: "Raw SQL query - can xem xet hieu nang",
        description: ("Phat hien raw SQL tai " + $file + ":" + ($line | tostring) + ". Raw SQL bo qua ORM query optimization va co the thieu indexes. Can dung EXPLAIN de kiem tra query plan."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ($snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Them EXPLAIN ANALYZE truoc query de kiem tra index usage. Dam bao dung parameterized queries (bind params) de tranh SQL injection.", suggested_agent: "dba", estimated_effort: "low"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-db-query-analysis"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done < <(grep -rnE '(query\(|execute\(|raw\(|sequelize\.query|knex\.raw|prisma\.\$queryRaw|typeorm\.query|entityManager\.query|db\.execute)' "$SOURCE" \
            --include='*.ts' --include='*.js' --include='*.py' --include='*.java' --include='*.go' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' || true)

  # ============================================================
  # Static Check 4: Missing indexes heuristics (JOIN without index hints)
  # ============================================================
  while IFS=: read -r file line match; do
    [ -z "$file" ] && continue
    fp=$(echo -n "QD4|$file|$line|P-QD4-db-query-analysis|join_no_index" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
    sig=$(jq -nc \
      --arg file "$file" --argjson line "$line" \
      --arg snippet "$(echo "$match" | head -c 80)" \
      --arg fp "$fp" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-db-query-analysis",
        probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "backend",
        title: "JOIN query - can kiem tra index coverage",
        description: ("Phat hien JOIN operation tai " + $file + ":" + ($line | tostring) + ". JOIN khong co index phu hop co the gay full table scan."),
        location: {file: $file, line: $line, column: null, selector: null, url: null},
        evidence: [{type: "code", path: $file, description: ($snippet)}],
        cdg_flags: [], fingerprint: $fp,
        remediation: {suggested_action: "Kiem tra foreign key columns co index khong. Them composite indexes cho JOIN + WHERE conditions.", suggested_agent: "dba", estimated_effort: "medium"},
        detected_at: $now, detected_by: "wf-fix-performance/P-QD4-db-query-analysis"
      }')
    SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
  done < <(grep -rnE '(JOIN|join\s*\(|innerJoin|leftJoin|rightJoin|\.join\s*\()' "$SOURCE" \
            --include='*.ts' --include='*.js' --include='*.py' --include='*.java' --include='*.sql' \
            2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.|\.map$)' || true)

  # ============================================================
  # Static Check 5: Schema missing index annotations/decorators
  # ============================================================
  if [ -d "$SOURCE" ]; then
    # Look for entity/model files without @Index decorator or index: true
    while IFS= read -r ent_file; do
      [ -z "$ent_file" ] && continue
      # Check if entity has foreign key references
      if grep -qE '(@ManyToOne|@OneToMany|@ManyToMany|@JoinColumn|belongsTo|hasMany|hasOne|references|foreignKey)' "$ent_file" 2>/dev/null; then
        # Check if it has index annotations
        if ! grep -qE '(INDEX|@Index|index:\s*true|addIndex|createIndex)' "$ent_file" 2>/dev/null; then
          fp=$(echo -n "QD4|$ent_file|1|P-QD4-db-query-analysis|missing_index" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
          sig=$(jq -nc \
            --arg file "$ent_file" --arg fp "$fp" \
            --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
              "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-db-query-analysis",
              probe_version: "v1.0", severity: "medium", fixability: "agent_fix", domain: "backend",
              title: "Entity co foreign key relationships thieu index",
              description: ("File " + $file + " co relationship annotations (ManyToOne/OneToMany) nhung khong co @Index hoac index: true. FK columns khong co index -> JOIN performance degraded."),
              location: {file: $file, line: 1, column: null, selector: null, url: null},
              evidence: [{type: "code", path: $file, description: "Entity co relationship fields thieu @Index"}],
              cdg_flags: [], fingerprint: $fp,
              remediation: {suggested_action: "Them @Index decorator hoac index: true tren foreign key fields de optimize JOIN performance", suggested_agent: "dba", estimated_effort: "low"},
              detected_at: $now, detected_by: "wf-fix-performance/P-QD4-db-query-analysis"
            }')
          SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
        fi
      fi
    done < <(find "$SOURCE" -type f \( -name '*.entity.ts' -o -name '*.entity.js' -o -name '*.model.ts' -o -name '*.model.js' -o -name 'schema.prisma' -o -name '*.go' \) \
              2>/dev/null | grep -vE '(node_modules|__tests__|\.test\.|\.spec\.)' || true)
  fi
fi

# ============================================================
# Runtime Check: Slow query via DB adapter (neu DB accessible)
# ============================================================
if [ -n "${DATABASE_URL:-}" ] || [ -n "${DB_HOST:-}" ] || [ -n "${MONGODB_URI:-}" ]; then
  # Check if we can run EXPLAIN via available CLI
  if command -v psql &>/dev/null && [ -n "${DATABASE_URL:-}" ]; then
    # PostgreSQL: EXPLAIN ANALYZE on slow queries heuristics
    RUNTIME_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD4-performance/runtime"
    mkdir -p "$RUNTIME_DIR"
    
    # Use pg_stat_statements to find slow queries if available
    psql "$DATABASE_URL" -c "
      SELECT query, calls, total_exec_time, mean_exec_time, rows
      FROM pg_stat_statements
      ORDER BY total_exec_time DESC
      LIMIT 10;
    " 2>/dev/null > "$RUNTIME_DIR/pg_slow_queries.txt" || true
    
    if [ -f "$RUNTIME_DIR/pg_slow_queries.txt" ] && [ -s "$RUNTIME_DIR/pg_slow_queries.txt" ]; then
      tail -n +3 "$RUNTIME_DIR/pg_slow_queries.txt" | head -10 | while IFS='|' read -r query calls total_time mean_time rows; do
        [ -z "$query" ] && continue
        mean_ms=$(echo "$mean_time" | xargs printf "%.0f" 2>/dev/null || echo 0)
        [ "$mean_ms" -lt 1000 ] && continue  # Skip fast queries
        
        severity="medium"
        [ "$mean_ms" -gt 5000 ] && severity="high"
        [ "$mean_ms" -gt 10000 ] && severity="critical"
        
        query_snippet=$(echo "$query" | tr -s ' ' | head -c 120)
        fp=$(echo -n "QD4|pg_stat|slow|P-QD4-db-query-analysis|slow_query_runtime" | sha256sum 2>/dev/null | awk '{print "sha256:"$1}')
        sig=$(jq -nc \
          --arg snippet "$query_snippet" --argjson calls "$(echo "$calls" | xargs)" \
          --argjson mean_ms "$mean_ms" --argjson total_time "$(echo "$total_time" | xargs printf "%.0f")" \
          --arg severity "$severity" --arg fp "$fp" \
          --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          '{
            "$schema": "signal-v2", dimension_id: "QD4", probe_id: "P-QD4-db-query-analysis",
            probe_version: "v1.0", severity: $severity, fixability: "agent_fix", domain: "backend",
            title: ("Slow query: avg " + ($mean_ms | tostring) + "ms, called " + ($calls | tostring) + " times"),
            description: ("Query avg " + ($mean_ms | tostring) + "ms, total " + ($total_time | tostring) + "ms, " + ($calls | tostring) + " calls. Can xem xet them index hoac cau truc lai query."),
            location: {file: "runtime", line: null, column: null, selector: null, url: null},
            evidence: [{type: "code", path: "pg_stat_statements", description: ($snippet)}],
            cdg_flags: ([if ($severity == "critical") then "CDG-SLOW-QUERY-CRITICAL" else empty end]),
            remediation: {suggested_action: "Them index, rewrite query, hoac materialize view. Dung EXPLAIN ANALYZE de xac dinh bottleneck.", suggested_agent: "dba", estimated_effort: "medium"},
            detected_at: $now, detected_by: "wf-fix-performance/P-QD4-db-query-analysis"
          }')
        SIGNALS_JSON=$(jq -c --argjson s "$sig" '. + [$s]' <<< "$SIGNALS_JSON")
      done
    fi
  fi
fi

# Final output
jq -nc \
  --arg lane "wf-fix-performance" --arg probe "P-QD4-db-query-analysis" --arg pver "v1.0" \
  --arg profile "${PROFILE:-standard}" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson signals "$SIGNALS_JSON" \
  '{"$schema": "lane-signals-v1", lane: $lane, dimension: "QD4", probe_id: $probe,
    probe_version: $pver, profile: $profile, generated_at: $now, signals: $signals}' \
  > "$RAW_OUT"
```

**Bash script handles:**
- Static N+1 detection: grep `include/relations/eager/populate` trong loop context (for, forEach, map, reduce) — multi-language (TS, JS, Python, Java, Go, Ruby)
- Static unbounded query: grep `findAll/findMany/find/all` WITHOUT `limit/take/LIMIT/TOP`
- Static raw SQL: grep `.query(`, `.execute(`, `.raw(`, `$queryRaw` patterns — phan biet co/khong param binding
- Static JOIN analysis: grep `JOIN`, `.join(`, `innerJoin`, `leftJoin` patterns
- Static missing index: entity/model files co FK relationships (@ManyToOne, belongsTo) thieu `@Index` / `index: true`
- Runtime slow query: neu DATABASE_URL available + psql CLI — EXPLAIN ANALYZE hoac pg_stat_statements
- Cache policy: allowed cho static part; runtime part luon fresh

### B2: Scan Cache check (static part only)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD4-db-query-analysis --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

### B3: CI Enrichment (BAT BUOC khi GITNEXUS available — N+1 detection la canonical use case cho gitnexus_query)

> **Muc dich:** Voi `n_plus_one_orm` signals — confirm endpoint hot path co loop call repository khong. Voi `unbounded_query` signals — find call sites de uoc luong impact.

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" ]]; then
  # Pseudocode (orchestrator agent thuc hien):
  # 
  # FOR each signal trong $RAW_OUT.signals[] (top 30 theo severity):
  #   IF signal.signal_type == "n_plus_one_orm":
  #     # Tim endpoint chua N+1
  #     repo_method = signal.evidence.repo_call  # vd: "OrderRepository.findById"
  #     impact = mcp__plugin_gitnexus_gitnexus__impact(target=repo_method, direction="upstream")
  #     signal.evidence.gitnexus_callers = impact.direct_callers_count
  #     # Identify hot endpoint
  #     for caller in impact.top_callers:
  #       IF caller.kind == "endpoint" or caller.name contains "Controller":
  #         signal.evidence.hot_endpoint = caller.name
  #         signal.suggested_severity = "critical"  # N+1 in hot endpoint
  #     
  #     # Trace full flow
  #     flow = mcp__plugin_gitnexus_gitnexus__query(query=f"{signal.evidence.hot_endpoint} flow")
  #     signal.evidence.gitnexus_flow_steps = flow.steps[0:5]
  #   
  #   ELIF signal.signal_type == "unbounded_query":
  #     # Find call sites
  #     IF SERENA_AVAILABLE:
  #       refs = mcp__serena__find_referencing_symbols(name_path=signal.evidence.query_method, relative_path=signal.target.file_path)
  #       signal.evidence.serena_refs_count = refs.length
  #       # Bump severity neu nhieu noi goi
  #       IF refs.length > 5:
  #         signal.suggested_severity = "high"
  #   
  #   signal.evidence.ci_meta = {gitnexus_used: true, serena_used: $SERENA_AVAILABLE, freshness_level: $FRESHNESS_LEVEL}
fi
```

**Graceful:** GitNexus absent → skip B3, signals giu severity tu B1.

## THINK

Inline bash logic:
1. **N+1 via ORM:** Nested `include`/`relations`/`eager`/`populate` trong loop (for/forEach/map) => moi vong lap trigger query rieng => HIGH. Fix: batch fetch / dataloader.
2. **Unbounded queries:** `findAll`/`findMany` khong co `.limit(N)` hoac `.take(N)` => co the load toan bo bang => HIGH (memory risk). Fix: them limit/pagination.
3. **Raw SQL:** `query()`/`execute()`/`raw()` => bo qua ORM query optimization => MEDIUM. Khong co param binding => HIGH (SQL injection).
4. **JOIN without indexes:** JOIN operations => potential full table scan => MEDIUM. Can kiem tra FK indexes.
5. **Missing FK indexes:** Entity co relationships (@ManyToOne) nhung thieu @Index => MEDIUM. FK columns can index.
6. **Runtime slow queries:** pg_stat_statements => phat hien slow queries thuc te => CRITICAL/HIGH/MEDIUM dua tren mean execution time.
7. **Domain:** `backend`
8. **Fixability:** `agent_fix` (dba)

## ACT

Output schema `signal-v2`:
- N+1 ORM: `title: "Potential N+1 query (ORM inside loop)"`, `remediation.suggested_action: "Refactor to batch fetch or dataloader"`
- Unbounded query: `title: "Unbounded query - thieu limit/take"`, `remediation.suggested_action: "Them .limit(N) hoac cursor-based pagination"`
- Raw SQL: `title: "Raw SQL query - can kiem tra hieu nang"`, `remediation.suggested_action: "Them EXPLAIN ANALYZE, dung parameterized queries"`
- JOIN no index: `title: "JOIN query - can kiem tra index coverage"`, `remediation.suggested_action: "Kiem tra FK columns co index khong"`
- Missing entity index: `title: "Entity co FK relationships thieu index"`, `remediation.suggested_action: "Them @Index tren FK fields"`
- Slow query runtime: `title: "Slow query: avg Xms, called Y times"`, `remediation.suggested_action: "Them index, rewrite query, materialize view"`

## VERIFY

1. Moi Signal co `dimension_id == "QD4"`
2. Static signals co `evidence[].path` tro den file ton tai
3. N+1 signals co context evidence (code snippet xung quanh)
4. Severity trong [CRITICAL, HIGH, MEDIUM] (khong LOW default cho probe nay)
5. Runtime signals co metric values (mean_ms, calls)
6. Remediation present cho moi signal
7. Khong co duplicate fingerprints (cung file+line+pattern_type)

## Severity Rules

| Pattern | Severity |
|---------|----------|
| Runtime slow query mean > 10000ms | CRITICAL |
| N+1 ORM pattern (include/relation trong loop) | HIGH |
| Unbounded query (findAll/findMany thieu limit) | HIGH |
| Raw SQL khong co param binding | HIGH |
| JOIN query (potential no index) | MEDIUM |
| Entity FK thieu @Index | MEDIUM |
| Raw SQL co param binding | MEDIUM |
| Runtime slow query mean 1000-5000ms | MEDIUM |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Source dir khong tim thay | Skip static analysis, chi chay runtime (neu DB accessible) |
| DB env vars khong co | Chi chay static analysis, note "no_db_access" |
| psql khong available | Skip runtime PostgreSQL EXPLAIN, note "psql_unavailable" |
| pg_stat_statements khong available | Skip runtime slow query detection, note "pg_stat_statements_unavailable" |
| Cache hit (static part) | Dung cached signals, khong chay lai static grep |
| ORM khong duoc phat hien (khong co entity/models) | Emit warning, skip static checks 1-5, note "no_orm_patterns_found" |
