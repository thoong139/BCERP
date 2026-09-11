#!/usr/bin/env bash
# Adapter for .NET stack (C#, F#, VB.NET). Built in IMP-000 Stage 0.
# IMP-001 (Stage 3): Implement ASP.NET Core route detection.
#
# Detection signals: *.csproj | *.fsproj | *.vbproj | *.sln present.
#
# Route detection patterns:
#   - Attribute routing: [HttpGet("path")], [HttpPost], [Route("...")], [ApiController]
#   - Minimal API: app.MapGet("/path", ...), app.MapPost, app.MapPut, app.MapDelete
#   - [Authorize] attribute attached to controller/action
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"file":"path","line":N,"method":"GET|POST|PUT|DELETE|PATCH|ANY","route":"...","framework":"aspnet"}
# Returns non-zero if project_path not found.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    find "$project_path" -maxdepth 3 -type f \
        \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' -o -name '*.sln' \) \
        -print -quit 2>/dev/null | grep -q .
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    local count=0

    # -------------------------------------------------------
    # Pattern 1: HTTP attribute routing (C#)
    # [HttpGet], [HttpPost("/path")], [HttpPut], [HttpDelete], [HttpPatch]
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        # Extract HTTP method from attribute name
        if echo "$raw" | grep -qiE '\[Http(Get|Post|Put|Delete|Patch)'; then
            method=$(echo "$raw" | grep -oiE 'Http(Get|Post|Put|Delete|Patch)' | sed 's/Http//I' | tr '[:lower:]' '[:upper:]' | head -1) || true
        else
            method="ANY"
        fi
        # Extract route string if present in attribute (|| true: grep returns 1 when no match)
        route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"') || true
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"aspnet"}\n' \
            "$file" "$line" "$method" "$route"
        count=$((count + 1))
    done < <(
        grep -rEn '\[(HttpGet|HttpPost|HttpPut|HttpDelete|HttpPatch|Route)\b' \
            --include='*.cs' --include='*.fs' \
            "$project_path" 2>/dev/null
    )

    # -------------------------------------------------------
    # Pattern 2: Minimal API (C# .NET 6+)
    # app.MapGet("/path", ...) | app.MapPost | app.MapPut | app.MapDelete | app.MapPatch
    # builder.MapGroup
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        method=$(echo "$raw" | grep -oiE '\.Map(Get|Post|Put|Delete|Patch)\(' | grep -oiE 'Map(Get|Post|Put|Delete|Patch)' | sed 's/Map//I' | tr '[:lower:]' '[:upper:]' | head -1) || true
        [[ -z "$method" ]] && method="ANY"
        route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"') || true
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"aspnet-minimal"}\n' \
            "$file" "$line" "$method" "$route"
        count=$((count + 1))
    done < <(
        grep -rEn '(app|endpoints|group)\.(MapGet|MapPost|MapPut|MapDelete|MapPatch)\(' \
            --include='*.cs' \
            "$project_path" 2>/dev/null
    )

    return 0
}
