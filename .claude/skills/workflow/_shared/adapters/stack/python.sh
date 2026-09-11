#!/usr/bin/env bash
# Adapter for Python stack. Built in IMP-000 Stage 0.
# IMP-001 (Stage 3): Implement Django urlpatterns + FastAPI route detection.
#
# Detection signals: pyproject.toml | requirements.txt | setup.py | Pipfile | poetry.lock
#
# Route detection patterns:
#   Django:
#     urlpatterns = [path("route", view, name="..."), re_path("regex", view)]
#     url("regex", view)  (Django < 2.x legacy)
#   FastAPI:
#     @app.get("/path"), @app.post, @app.put, @app.delete, @app.patch
#     @router.get("/path"), @router.post, etc.
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"file":"path","line":N,"method":"GET|POST|...","route":"...","framework":"django|fastapi"}

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    [[ -f "$project_path/pyproject.toml" ]] && return 0
    [[ -f "$project_path/requirements.txt" ]] && return 0
    [[ -f "$project_path/setup.py" ]] && return 0
    [[ -f "$project_path/Pipfile" ]] && return 0
    [[ -f "$project_path/poetry.lock" ]] && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # -------------------------------------------------------
    # Pattern 1: Django URL patterns
    # path("route", view), re_path(r"regex", view), url(r"regex", view)
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        route=$(echo "$raw" | grep -oE "(path|re_path|url)\(['\"]r?['\"]?[^'\"]*" | head -1 | sed "s/.*['\"]r\?['\"]//")
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"ANY","route":"%s","framework":"django"}\n' \
            "$file" "$line" "$route"
    done < <(
        grep -rEn '\b(path|re_path|url)\s*\(' \
            --include='*.py' \
            "$project_path" 2>/dev/null | grep -v '#'
    )

    # -------------------------------------------------------
    # Pattern 2: FastAPI decorator routes
    # @app.get("/path"), @router.get("/path"), @api_router.post("/path")
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        method=$(echo "$raw" | grep -oE '\.(get|post|put|delete|patch|options|head)\(' | tr -d '.' | tr -d '(' | tr '[:lower:]' '[:upper:]' | head -1)
        [[ -z "$method" ]] && method="ANY"
        route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
        [[ -z "$route" ]] && {
            route=$(echo "$raw" | grep -oE "'[^']+'" | head -1 | tr -d "'")
        }
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"fastapi"}\n' \
            "$file" "$line" "$method" "$route"
    done < <(
        grep -rEn '@(app|router|api_router|prefix_router)\.(get|post|put|delete|patch|options|head)\(' \
            --include='*.py' \
            "$project_path" 2>/dev/null
    )

    return 0
}
