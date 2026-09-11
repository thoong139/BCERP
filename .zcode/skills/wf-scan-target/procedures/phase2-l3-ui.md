# Phase 2 Layer 3 — UI Screens & Components Discovery

> **Sprint 3 lazy-load refactor.** Map tất cả screens, pages, routes UI.
> Bao gồm CDG-07 (URL crawl side-effect confirm). Skip layer này khi `$scan_depth == "shallow"`.

## Reference Sections

- `_shared.md` §State Variables Glossary
- `_shared.md` §Helper Functions (`save_checkpoint`)

## Load Condition

Chạy PARALLEL với L1/L2/L4 sau `phase1-detect.md` POST-GATE PASS.
Skip nếu `$scan_depth == "shallow"`. Skip nếu target là api-only/dotnet backend (không có frontend).

---

## PRE-GATE

```
- $scan_root set
- $detected_tech_stack non-empty
- $L1_RESULT.key_files set (parallel-safe)
- $scan_depth != "shallow"
```

## INPUT

| Variable | From | Description |
|----------|------|-------------|
| `$scan_root` | Phase 1 | Path để scan |
| `$target`, `$target_type` | Phase 0 | URL crawl trigger |
| `$detected_tech_stack` | Phase 1 | Routing |
| `$L1_RESULT.key_files` | Phase 2 L1 | pages/screens/components |
| `$scan_depth` | Phase 0 | Trigger CDG-07 nếu deep + URL |
| `$MAX_PAGES` | Phase 0 | Sprint 7 — URL crawl page cap (5/25/50/100 theo profile) |
| `$SCAN_PROFILE` | Phase 0 | Sprint 7 — log message + CDG-07 display context |
| `$DELTA_MODE` | Phase 1 | Sprint 7 — true → filter screens/components theo changed files |

## Steps

### Layer 3 — UI Screens & Components Discovery (Sprint 4 — bash delegation cho local; AI cho URL crawl)

> **Token saving:** ~10K → ~1K cho local source (~90% giảm). URL crawl giữ AI vì cần WebFetch + CDG-07.
> Detection patterns trong `.claude/scripts/scan-target-ui.sh`: Next.js (App Router page.tsx +
> Pages Router), React Native (screens/, app/), Vue (pages/), Components (components/).
> Strip route groups (group)/, parallel slots @slot, replace [param] với :param.

```bash
SCAN_ROOT="${scan_root:-$target}"
TECH_STACK_JSON="$SESSION_DIR/intermediate/tech-stack.json"

# Sprint 7 PHẦN E — URL crawl giới hạn cứng max-depth=2 (root + 1 level deep)
# Tránh deep recursive crawl gây DDoS / rate-limit. CDG-07 dùng $MAX_PAGES (Sprint 7 Q4=D).
URL_MAX_DEPTH=2

IF target_type == "local-source":
  # Delegate to bash UI script (local source enumeration only)
  bash .claude/scripts/scan-target-ui.sh "$SCAN_ROOT" "$SESSION_DIR/intermediate/" "$TECH_STACK_JSON"
  # Script tự handle backend-only short-circuit (frontend_present=false → skipped)

ELIF target_type == "url":
  # AI-only step (cần WebFetch + CDG-07 cho rate-limit / cost confirmation)
  # Sprint 7 PHẦN E — URL crawl max-depth=2 (root + 1 level)
  Log: "URL crawl max_depth=$URL_MAX_DEPTH (Sprint 7 hardcoded — chỉ scan root + 1 level)"

  HTML = WebFetch(target).body
  Grep "<a href=" OR "<Link href=" → hrefs[]
  internal_links = [href for href in hrefs if same_domain(href, target)]
  estimated_pages = len(unique(internal_links))

  # Apply MAX_PAGES cap từ Sprint 7 profile (5/25/50/100 hoặc --max-pages override)
  IF estimated_pages > $MAX_PAGES:
    Log: "estimated_pages=$estimated_pages > MAX_PAGES=$MAX_PAGES — sẽ truncate"
    estimated_pages = $MAX_PAGES

  # CDG-07: confirm trước khi crawl > $MAX_PAGES trang (Sprint 7 dùng MAX_PAGES adaptive,
  # thay cho hardcode 5 ở Sprint 1). Trigger cũng yêu cầu URL_MAX_DEPTH ≥ 2 (đang fixed = 2).
  IF scan_depth == "deep" AND $URL_MAX_DEPTH -ge 2 AND estimated_pages > $MAX_PAGES:
    hostname = extract_hostname(target)
    Display:
      "⚠️ AI sắp gửi khoảng {estimated_pages} HTTP requests đến '{hostname}'
       (profile=$SCAN_PROFILE, max_pages=$MAX_PAGES, max_depth=$URL_MAX_DEPTH).

       Hậu quả có thể có:
       - Bị rate-limit từ server (429 Too Many Requests)
       - Tốn chi phí nếu là API có billing
       - Tạo log entries trên server đích

       Bạn có muốn AI tiếp tục crawl các trang con không?
       - Có: tiếp tục crawl ({estimated_pages} pages, max_depth=$URL_MAX_DEPTH)
       - Không: chỉ phân tích trang chính, bỏ qua các trang con (depth = 1)"

    IF user trả lời "Không":
      Log: "User declined CDG-07 — limit crawl to depth 1"
      internal_links = []
      ui_screens.append({name: "Trang chính", route: "/", source: "crawl-root-only"})
    ELSE:
      Log: "User accepted CDG-07 — proceed with full crawl (MAX_PAGES=$MAX_PAGES)"

  # Crawl với hard caps: MAX_PAGES (số pages) + URL_MAX_DEPTH=2 (level)
  PAGES_VISITED=0
  FOR each link in unique(internal_links):
    IF PAGES_VISITED -ge $MAX_PAGES: break
    # current_depth = 1 (root linked) — vì URL_MAX_DEPTH=2 nên KHÔNG recurse thêm level
    route = extract_path(link)
    screen_name = humanize(route)
    ui_screens.append({name: screen_name, route: route, source: "crawl", depth: 1})
    PAGES_VISITED=$((PAGES_VISITED + 1))

  # Save manually as l3-ui.json (cùng schema scan-target-l3-v1)
  jq -n --argjson scrs "$ui_screens_json" --argjson mp "$MAX_PAGES" --argjson md "$URL_MAX_DEPTH" '{
    "$schema": "scan-target-l3-v1",
    generated_at: now | todate,
    scan_root: "'"$target"'",
    total_screens: ($scrs | length),
    total_components: 0,
    source: "url_crawl",
    crawl_max_pages: $mp,
    crawl_max_depth: $md,
    screens: $scrs,
    components: []
  }' > "$SESSION_DIR/intermediate/l3-ui.json"

# Read result
L3_RESULT_PATH="$SESSION_DIR/intermediate/l3-ui.json"

# Sprint 7 PHẦN B — Delta scope filter (chỉ khi $DELTA_MODE == "true" + local-source)
# Filter screens[] và components[] theo path ∈ changed-files. Skip cho url crawl.
if [[ "${DELTA_MODE:-false}" == "true" ]] && [[ "$target_type" == "local-source" ]]; then
  CHANGED_JSON="$SESSION_DIR/intermediate/changed-files.json"
  Log: "Delta mode: filtering L3 screens + components by changed files"

  tmp=$(mktemp)
  jq --slurpfile cf "$CHANGED_JSON" '
    .screens = (.screens // [] | map(
      select(.path == null or (.path as $p | $cf[0].files | index($p) != null))
    )) |
    .components = (.components // [] | map(
      select(.path == null or (.path as $p | $cf[0].files | index($p) != null))
    )) |
    .total_screens = (.screens | length) |
    .total_components = (.components | length) |
    .delta_filtered = true
  ' "$L3_RESULT_PATH" > "$tmp" && mv "$tmp" "$L3_RESULT_PATH"
fi

total_screens=$(jq -r '.total_screens' "$L3_RESULT_PATH")
total_components=$(jq -r '.total_components' "$L3_RESULT_PATH")

Log: "Layer 3 done: total_screens=$total_screens, total_components=$total_components"

save_checkpoint --layer L3 --status completed \
                --intermediate-key l3_result \
                --intermediate-path "intermediate/l3-ui.json"
```

## POST-GATE

```
- $L3_RESULT set (có thể "not applicable" nhưng không null)
- test -s $SESSION_DIR/intermediate/l3-ui.json
- jq empty $SESSION_DIR/intermediate/l3-ui.json
- checkpoint.json: layer_states.L3 == "completed"
```

## OUTPUT (set for next phase)

| Variable | Type | Description |
|----------|------|-------------|
| `$L3_RESULT` | JSON | total_screens, total_components, screens[], components[] |

## Next Phase

→ Sau khi L1+L2+L3+L4 đều POST-GATE PASS → Phase 2 POST-GATE → Read `procedures/phase3-synthesis.md`
