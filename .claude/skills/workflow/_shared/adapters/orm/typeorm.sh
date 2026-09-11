#!/usr/bin/env bash
# Adapter for TypeORM (Node.js/TypeScript). Built in IMP-000 Stage 0.
# scan() fully implemented in IMP-010 (Stage 3 Sprint 4).
#
# Detection signals: ormconfig.* | dependency typeorm trong package.json | @Entity decorator trong .ts.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    # Config file
    find "$project_path" -maxdepth 2 -type f \
        \( -name 'ormconfig.json' -o -name 'ormconfig.ts' \
           -o -name 'ormconfig.js' -o -name 'ormconfig.yml' -o -name 'ormconfig.env' \) \
        -print -quit 2>/dev/null | grep -q . && return 0
    # Dependency
    if [[ -f "$project_path/package.json" ]]; then
        grep -q '"typeorm"' "$project_path/package.json" 2>/dev/null && return 0
    fi
    return 1
}

# scan() — check TypeORM entity files for missing @Index on FK/relation columns.
# Output: JSON Lines (one signal object per line), exit 0.
# Checks:
#   1. @ManyToOne / @OneToOne decorated properties without @Index decorator
#   2. Column ending in Id (FK convention) without @Index
# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    local probe_id="P-QD6-orm-model-sync"
    local dimension="QD6"
    _sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }

    EXCLUDE='(__tests__|\.test\.|\.spec\.|mocks?/|node_modules)'

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
        if ! grep -q '@Entity' "$file" 2>/dev/null; then continue; fi

        # Check: @ManyToOne / @OneToOne without @Index in same entity
        while IFS= read -r match; do
            line_num=$(echo "$match" | cut -d: -f1)
            # Look for the column name on the next few lines
            col_section=$(sed -n "${line_num},$((line_num+5))p" "$file" 2>/dev/null)
            col_name=$(echo "$col_section" | grep -oE '[a-zA-Z]+Id\b' | head -1)
            [ -z "$col_name" ] && col_name=$(echo "$col_section" | awk '/[a-z][A-Za-z]+:/ {print $1}' | head -1 | tr -d ':')

            # Check if @Index exists for this column or entity-level @@index
            if ! grep -qE "@Index\(\[?['\"]?${col_name}['\"]?\]?\)" "$file" 2>/dev/null; then
                fp=$(printf '%s' "QD6|${file}|${line_num}|${probe_id}|typeorm_missing_index" | _sha256_fn | awk '{print "sha256:"$1}')
                jq -nc \
                    --arg title "TypeORM: @ManyToOne/@OneToOne thiếu @Index" \
                    --arg desc "Entity trong $(basename "$file") có @ManyToOne/@OneToOne tại dòng ${line_num} nhưng thiếu @Index decorator. Thiếu index → full table scan khi query theo FK." \
                    --arg sev "medium" \
                    --arg file "$file" --argjson line "$line_num" \
                    --arg fp "$fp" --arg dim "$dimension" --arg probe "$probe_id" \
                    --arg issue "typeorm_missing_fk_index" \
                    '{title:$title, description:$desc, severity:$sev,
                      file:$file, line:$line, fingerprint:$fp,
                      dimension:$dim, probe_id:$probe, issue_class:$issue,
                      suggested_agent:"dba",
                      remediation:"Thêm @Index() decorator trước @ManyToOne/@OneToOne, hoặc @Index([\"fkColumnName\"]) tại class level"}'
            fi
        done < <(grep -nE '@(ManyToOne|OneToOne)\(' "$file" 2>/dev/null | head -20)
    done < <(find "$project_path" -maxdepth 8 -type f \( -name '*.ts' -o -name '*.js' \) 2>/dev/null)
}
