#!/usr/bin/env bash
# Adapter for npm-family package managers (npm, yarn, pnpm). Built in IMP-000 Stage 0.
# IMP-003 (Stage 3): Implement dependency vuln scan via npm audit / yarn audit / pnpm audit.
#
# Detection signals: package-lock.json | yarn.lock | pnpm-lock.yaml | npm-shrinkwrap.json.
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"pm":"npm","package":"name","version":"x.y.z","severity":"high|medium|low|critical","cve":"CVE-...","description":"..."}
#   OR: [stub] SPEC-ONLY-PROBE-SKIP pm=npm tool=npm not installed

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/package-lock.json" ]] && return 0
    [[ -f "$project_path/yarn.lock" ]] && return 0
    [[ -f "$project_path/pnpm-lock.yaml" ]] && return 0
    [[ -f "$project_path/npm-shrinkwrap.json" ]] && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # Detect which lockfile is present to choose the right tool
    local pm="npm"
    if [[ -f "$project_path/yarn.lock" ]]; then
        pm="yarn"
    elif [[ -f "$project_path/pnpm-lock.yaml" ]]; then
        pm="pnpm"
    fi

    # Check tool availability
    if ! command -v "$pm" >/dev/null 2>&1; then
        echo "[stub] SPEC-ONLY-PROBE-SKIP pm=$pm tool=$pm not installed"
        return 0
    fi

    # Run audit — cd into project dir first
    local audit_json
    audit_json=$(cd "$project_path" && "$pm" audit --json 2>/dev/null) || true
    [[ -z "$audit_json" ]] && return 0

    # npm audit --json v2 format: .vulnerabilities object keyed by package name
    local vuln_count
    vuln_count=$(echo "$audit_json" | jq -r '.vulnerabilities // {} | length' 2>/dev/null) || true
    if [[ "$vuln_count" == "0" ]] || [[ -z "$vuln_count" ]]; then
        return 0
    fi

    # Emit one JSON line per vulnerable package
    echo "$audit_json" | jq -rc '
      .vulnerabilities // {} | to_entries[] |
      .value as $v |
      {
        pm: "'"$pm"'",
        package: $v.name,
        version: ($v.range // "unknown"),
        severity: $v.severity,
        cve: ([$v.via[]? | select(type == "object") | .cve // ""] | join(",") | if . == "" then "N/A" else . end),
        description: ([$v.via[]? | select(type == "object") | .title // ""] | join("; ") | if . == "" then $v.name else . end),
        fix_available: ($v.fixAvailable // false)
      }
    ' 2>/dev/null || true

    return 0
}
