# Phase 2 Layer 2 — API Endpoints Discovery

> **Sprint 3 lazy-load refactor.** Liệt kê tất cả API endpoints với method, path, handler.
> Skip layer này khi `$scan_depth == "shallow"`.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)

## Load Condition

Chạy PARALLEL với L1/L3/L4 sau `phase1-detect.md` POST-GATE PASS.
Skip nếu `$scan_depth == "shallow"`.

---

## PRE-GATE

```
- $scan_root set
- $detected_tech_stack non-empty
- $L1_RESULT.key_files set (Layer 1 đã chạy hoặc sẽ chạy parallel)
- $scan_depth != "shallow"
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$scan_root` | Phase 1 | Path để scan |
| `$detected_tech_stack` | Phase 1 | Routing logic |
| `$L1_RESULT.key_files` | Phase 2 L1 | Endpoint files / API routes (parallel-safe) |
| `$swagger_data`, `$swagger_available` | Phase 1 | URL/Swagger source |
| `$target_type` | Phase 0 | URL routing |

## Steps

### Layer 2 — API Endpoints Discovery (Sprint 4 — bash delegation)

> **Token saving:** ~10-30K → ~1K (~95% giảm). Bash grep MapGet/MapPost/route patterns
> per tech stack — deterministic, no AI inference needed.

```bash
SCAN_ROOT="${scan_root:-$target}"
TECH_STACK_JSON="$SESSION_DIR/intermediate/tech-stack.json"

IF target_type IN ["local-source"]:
  # Delegate to bash API script
  bash .claude/scripts/scan-target-api.sh "$SCAN_ROOT" "$SESSION_DIR/intermediate/" "$TECH_STACK_JSON"

ELIF target_type == "swagger-spec" OR swagger_available == true:
  # AI-only step (cần parse swagger spec, không deterministic enough cho bash)
  Parse swagger_data.paths:
    FOR each path in paths:
      FOR each method in path:
        api_endpoints.append({
          method: method.toUpperCase(),
          path: path_key,
          operationId: operation.operationId,
          tags: operation.tags,
          summary: operation.summary,
          requires_auth: "security" in operation
        })

  # Save as l2-api.json với swagger source marker
  echo '{...}' | jq '.' > "$SESSION_DIR/intermediate/l2-api.json"

ELIF target_type == "url" AND swagger_available == false:
  # Save fallback note
  jq -n '{
    "$schema": "scan-target-l2-v1",
    generated_at: now | todate,
    total_endpoints: 0,
    source: "none",
    endpoints: [{note: "API spec không có sẵn từ URL — thử với --target=<swagger-url>"}]
  }' > "$SESSION_DIR/intermediate/l2-api.json"

# Read result
L2_RESULT_PATH="$SESSION_DIR/intermediate/l2-api.json"

# Sprint 7 PHẦN B — Delta scope filter (chỉ khi $DELTA_MODE == "true" + local-source)
# Filter endpoints[] theo source_file ∈ changed-files. Skip cho swagger/url (không có source_file).
if [[ "${DELTA_MODE:-false}" == "true" ]] && [[ "$target_type" == "local-source" ]]; then
  CHANGED_JSON="$SESSION_DIR/intermediate/changed-files.json"
  Log: "Delta mode: filtering L2 endpoints by changed files"

  tmp=$(mktemp)
  jq --slurpfile cf "$CHANGED_JSON" '
    .endpoints = (.endpoints // [] | map(
      select(.source_file == null or (.source_file as $sf | $cf[0].files | index($sf) != null))
    )) |
    .total_endpoints = (.endpoints | length) |
    .delta_filtered = true
  ' "$L2_RESULT_PATH" > "$tmp" && mv "$tmp" "$L2_RESULT_PATH"
fi

total_endpoints=$(jq -r '.total_endpoints' "$L2_RESULT_PATH")
source_type=$(jq -r '.source' "$L2_RESULT_PATH")

Log: "Layer 2 done: total_endpoints=$total_endpoints, source=$source_type"

save_checkpoint --layer L2 --status completed \
                --intermediate-key l2_result \
                --intermediate-path "intermediate/l2-api.json"
```

> **Reference (logic detail trong bash script):** xem `.claude/scripts/scan-target-api.sh`.
> Detection patterns:
> - **.NET DDD/Standard**: MapGet/MapPost/MapPut/MapDelete/MapPatch trong Endpoints/*.cs + Program.cs +
>   `[HttpGet]/[HttpPost]/...` decorators trong Controllers/. RequireAuthorization() → `requires_auth=true`.
> - **Next.js**: app/api/**/route.ts (export GET/POST/PUT/DELETE/PATCH) + Pages Router pages/api/**/*.ts.
>   Dynamic [param] → :param.
> - **Hono/Express**: app.get/post/..., router.get/post/... in routes/, app.ts, server.ts, index.ts.

## POST-GATE

```
- $L2_RESULT set (có thể "not available" nhưng không null)
- test -s $SESSION_DIR/intermediate/l2-api.json
- jq empty $SESSION_DIR/intermediate/l2-api.json
- checkpoint.json: layer_states.L2 == "completed"
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$L2_RESULT` | JSON | total_endpoints, endpoints[], source (code_scan/swagger/none) |

## Next Phase

→ Sau khi L1+L2+L3+L4 đều POST-GATE PASS → Phase 2 POST-GATE → Read `procedures/phase3-synthesis.md`
