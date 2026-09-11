#!/usr/bin/env bash
# Adapter for NuGet package manager (.NET). Built in IMP-000 Stage 0.
# IMP-003 (Stage 3): Implement vuln scan via `dotnet list package --vulnerable`.
#
# Detection signals: packages.lock.json | *.csproj với PackageReference | packages.config
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"pm":"nuget","package":"name","version":"x.y.z","severity":"high|medium|low","cve":"N/A","description":"..."}
#   OR: [stub] SPEC-ONLY-PROBE-SKIP pm=nuget tool=dotnet not installed

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    [[ -f "$project_path/packages.lock.json" ]] && return 0
    find "$project_path" -maxdepth 3 -type f -name 'packages.config' \
        -print -quit 2>/dev/null | grep -q . && return 0
    find "$project_path" -maxdepth 3 -type f \
        \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) \
        -exec grep -l 'PackageReference' {} \; 2>/dev/null | grep -q . && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # Check dotnet CLI availability
    if ! command -v dotnet >/dev/null 2>&1; then
        echo "[stub] SPEC-ONLY-PROBE-SKIP pm=nuget tool=dotnet not installed"
        return 0
    fi

    # dotnet list package --vulnerable --include-transitive
    # Output format is text, not JSON — parse it
    local raw_output
    raw_output=$(cd "$project_path" && dotnet list package --vulnerable 2>/dev/null) || true
    [[ -z "$raw_output" ]] && return 0

    # Parse text output: lines like "> Package  Version  Severity  Advisory URL"
    # Example: "> Microsoft.Data.SqlClient  2.1.0  High  https://..."
    while IFS= read -r line; do
        # Match lines starting with > (vulnerable package markers)
        if [[ "$line" =~ ^[[:space:]]*\>[[:space:]]+(.*) ]]; then
            local rest="${BASH_REMATCH[1]}"
            # Extract package name (first token), version (second), severity (third)
            read -r pkg ver severity rest2 <<< "$rest" || true
            [[ -z "$pkg" ]] && continue
            local lc_sev
            lc_sev=$(echo "${severity:-unknown}" | tr '[:upper:]' '[:lower:]') || true
            printf '{"pm":"nuget","package":"%s","version":"%s","severity":"%s","cve":"N/A","description":"Vulnerable NuGet package detected by dotnet audit","fix_available":true}\n' \
                "$pkg" "${ver:-unknown}" "${lc_sev:-unknown}"
        fi
    done <<< "$raw_output"

    return 0
}
