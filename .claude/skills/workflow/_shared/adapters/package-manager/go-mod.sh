#!/usr/bin/env bash
# Adapter for Go modules. Built in IMP-000 Stage 0.
# IMP-003 (Stage 3): Implement vuln scan via govulncheck.
#
# Detection signals: go.mod | go.sum
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"pm":"go","package":"module/path","version":"v1.2.3","severity":"unknown","cve":"GO-YYYY-NNNN","description":"..."}
#   OR: [stub] SPEC-ONLY-PROBE-SKIP pm=go tool=govulncheck not installed

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/go.mod" ]] && return 0
    [[ -f "$project_path/go.sum" ]] && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # Check govulncheck availability
    if ! command -v govulncheck >/dev/null 2>&1; then
        echo "[stub] SPEC-ONLY-PROBE-SKIP pm=go tool=govulncheck not installed"
        return 0
    fi

    # Run govulncheck with JSON output
    local vuln_json
    vuln_json=$(cd "$project_path" && govulncheck -json ./... 2>/dev/null) || true
    [[ -z "$vuln_json" ]] && return 0

    # govulncheck -json emits multiple JSON objects (one per finding)
    # Each has: {finding: {osv: "GO-...", trace: [{module, version}]}}
    while IFS= read -r finding; do
        [[ -z "$finding" ]] && continue
        local osv pkg ver desc
        osv=$(echo "$finding" | jq -r '.finding.osv // "N/A"' 2>/dev/null) || true
        pkg=$(echo "$finding" | jq -r '.finding.trace[0].module // "unknown"' 2>/dev/null) || true
        ver=$(echo "$finding" | jq -r '.finding.trace[0].version // "unknown"' 2>/dev/null) || true
        desc=$(echo "$finding" | jq -r '.finding.trace[0].function // "Vulnerable Go module"' 2>/dev/null) || true
        [[ "$osv" == "null" ]] && continue
        printf '{"pm":"go","package":"%s","version":"%s","severity":"unknown","cve":"%s","description":"%s","fix_available":false}\n' \
            "$pkg" "$ver" "$osv" "$desc"
    done < <(
        set +euo pipefail
        echo "$vuln_json" | jq -c 'select(.finding != null)' 2>/dev/null
    ) || true

    return 0
}
