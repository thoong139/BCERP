#!/usr/bin/env bash
# Adapter for Go stack. Built in IMP-000 Stage 0.
# Full implementation in IMP-001 (Gin/Echo/chi route detection) at Stage 3.
#
# Detection signals: go.mod present.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/go.mod" ]]
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    echo "[stub] stack/go scan() chưa implement — IMP-000 Stage 0 chỉ build scaffolding (project=$project_path)"
    return 0
}
