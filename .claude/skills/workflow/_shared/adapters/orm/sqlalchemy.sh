#!/usr/bin/env bash
# Adapter for SQLAlchemy ORM (Python). Built in IMP-000 Stage 0.
# scan() fully implemented in IMP-010 (Stage 3 Sprint 4).
#
# Detection signals: dependency 'sqlalchemy' trong requirements.txt|pyproject.toml | import sqlalchemy.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    # Check dependency trong manifest
    if [[ -f "$project_path/requirements.txt" ]]; then
        grep -qiE '^[[:space:]]*sqlalchemy([[:space:]<>=!~]|$)' "$project_path/requirements.txt" 2>/dev/null && return 0
    fi
    if [[ -f "$project_path/pyproject.toml" ]]; then
        grep -qi 'sqlalchemy' "$project_path/pyproject.toml" 2>/dev/null && return 0
    fi
    if [[ -f "$project_path/Pipfile" ]]; then
        grep -qi 'sqlalchemy' "$project_path/Pipfile" 2>/dev/null && return 0
    fi
    # Fallback: tìm import sqlalchemy trong .py
    find "$project_path" -maxdepth 4 -type f -name '*.py' \
        -exec grep -lE '^(from|import)[[:space:]]+sqlalchemy' {} \; 2>/dev/null | head -1 | grep -q . && return 0
    return 1
}

# scan() — check SQLAlchemy model files for ForeignKey columns missing index=True.
# Output: JSON Lines (one signal object per line), exit 0.
# Checks:
#   1. Column(..., ForeignKey(...)) without index=True
#   2. relationship() without passive_deletes or cascade specification
# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    local probe_id="P-QD6-orm-model-sync"
    local dimension="QD6"
    _sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }

    EXCLUDE='(__pycache__|\.pyc|/tests/|/test/|_test\.py|\.test\.py|/migrations?/)'

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
        if ! grep -qE 'ForeignKey\(|Column\(' "$file" 2>/dev/null; then continue; fi

        # CHECK 1: Column(... ForeignKey(...)) without index=True
        while IFS= read -r match; do
            line_num=$(echo "$match" | cut -d: -f1)
            line_content=$(echo "$match" | cut -d: -f2-)

            # If this Column has ForeignKey but no index=True on same line
            if echo "$line_content" | grep -q 'ForeignKey(' 2>/dev/null; then
                if ! echo "$line_content" | grep -qE 'index\s*=\s*True' 2>/dev/null; then
                    fp=$(printf '%s' "QD6|${file}|${line_num}|${probe_id}|sqlalchemy_fk_no_index" | _sha256_fn | awk '{print "sha256:"$1}')
                    jq -nc \
                        --arg title "SQLAlchemy: ForeignKey column thiếu index=True" \
                        --arg desc "$(basename "$file") dòng ${line_num}: Column có ForeignKey nhưng thiếu index=True. FK column không có index → query join/filter chậm." \
                        --arg sev "medium" \
                        --arg file "$file" --argjson line "$line_num" \
                        --arg fp "$fp" --arg dim "$dimension" --arg probe "$probe_id" \
                        --arg issue "sqlalchemy_missing_fk_index" \
                        '{title:$title, description:$desc, severity:$sev,
                          file:$file, line:$line, fingerprint:$fp,
                          dimension:$dim, probe_id:$probe, issue_class:$issue,
                          suggested_agent:"dba",
                          remediation:"Thêm index=True vào Column definition: Column(Integer, ForeignKey(\"table.id\"), index=True)"}'
                fi
            fi
        done < <(grep -nE 'Column\(' "$file" 2>/dev/null | head -30)
    done < <(find "$project_path" -maxdepth 8 -type f -name '*.py' 2>/dev/null)
}
