#!/usr/bin/env bash
# Adapter for pip-family Python package managers (pip, poetry, pipenv). Built in IMP-000 Stage 0.
# IMP-003 (Stage 3): Implement dependency vuln scan via pip-audit / safety.
#
# Detection signals: requirements.txt | poetry.lock | Pipfile.lock | pyproject.toml
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"pm":"pip","package":"name","version":"x.y.z","severity":"unknown","cve":"CVE-...","description":"..."}
#   OR: [stub] SPEC-ONLY-PROBE-SKIP pm=pip tool=pip-audit not installed

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/requirements.txt" ]] && return 0
    [[ -f "$project_path/poetry.lock" ]] && return 0
    [[ -f "$project_path/Pipfile.lock" ]] && return 0
    [[ -f "$project_path/pyproject.toml" ]] && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # Check pip-audit availability
    if ! command -v pip-audit >/dev/null 2>&1; then
        echo "[stub] SPEC-ONLY-PROBE-SKIP pm=pip tool=pip-audit not installed"
        return 0
    fi

    # Find requirements file
    local req_file="$project_path/requirements.txt"
    if [[ ! -f "$req_file" ]]; then
        req_file=""
    fi

    # Run pip-audit
    local audit_json=""
    if [[ -n "$req_file" ]]; then
        audit_json=$(pip-audit --format json -r "$req_file" 2>/dev/null) || true
    else
        audit_json=$(cd "$project_path" && pip-audit --format json 2>/dev/null) || true
    fi
    [[ -z "$audit_json" ]] && return 0

    # pip-audit JSON: array of {name, version, vulns:[{id, fix_versions, description}]}
    echo "$audit_json" | jq -rc '
      .[] | select(.vulns | length > 0) |
      .name as $pkg | .version as $ver |
      .vulns[] |
      {
        pm: "pip",
        package: $pkg,
        version: $ver,
        severity: "unknown",
        cve: .id,
        description: .description,
        fix_available: (.fix_versions | length > 0)
      }
    ' 2>/dev/null || true

    return 0
}
