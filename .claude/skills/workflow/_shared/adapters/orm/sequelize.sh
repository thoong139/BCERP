#!/usr/bin/env bash
# Adapter for Sequelize ORM (Node.js). Built in IMP-000 Stage 0.
# scan() fully implemented in IMP-010 (Stage 3 Sprint 4).
#
# Detection signals: dependency sequelize trong package.json | .sequelizerc | sequelize-cli config.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    # Config files
    [[ -f "$project_path/.sequelizerc" ]] && return 0
    # Dependency
    if [[ -f "$project_path/package.json" ]]; then
        grep -qE '"(sequelize|sequelize-cli|sequelize-typescript)"' "$project_path/package.json" 2>/dev/null && return 0
    fi
    return 1
}

# scan() — check Sequelize model files for FK fields missing indexes definition.
# Output: JSON Lines (one signal object per line), exit 0.
# Checks:
#   1. Model.init() attributes with *Id suffix without corresponding indexes config
#   2. references: { model: ... } without index: true on the attribute
# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    local probe_id="P-QD6-orm-model-sync"
    local dimension="QD6"
    _sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }

    EXCLUDE='(__tests__|\.test\.|\.spec\.|fixtures/|migrations?/|node_modules)'

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
        if ! grep -qE 'Model\.init\(|sequelize\.define\(' "$file" 2>/dev/null; then continue; fi

        # CHECK: attributes with references: { model: ... } but no index: true
        while IFS= read -r match; do
            line_num=$(echo "$match" | cut -d: -f1)
            line_content=$(echo "$match" | cut -d: -f2-)

            # Get surrounding context (5 lines)
            context=$(sed -n "${line_num},$((line_num+5))p" "$file" 2>/dev/null)

            if echo "$context" | grep -q 'references:' 2>/dev/null; then
                if ! echo "$context" | grep -qE 'index\s*:\s*true' 2>/dev/null; then
                    fp=$(printf '%s' "QD6|${file}|${line_num}|${probe_id}|sequelize_fk_no_index" | _sha256_fn | awk '{print "sha256:"$1}')
                    jq -nc \
                        --arg title "Sequelize: FK attribute thiếu index: true" \
                        --arg desc "$(basename "$file") dòng ${line_num}: attribute có references (FK) nhưng thiếu index: true. FK column không có DB index → query join/filter chậm." \
                        --arg sev "medium" \
                        --arg file "$file" --argjson line "$line_num" \
                        --arg fp "$fp" --arg dim "$dimension" --arg probe "$probe_id" \
                        --arg issue "sequelize_missing_fk_index" \
                        '{title:$title, description:$desc, severity:$sev,
                          file:$file, line:$line, fingerprint:$fp,
                          dimension:$dim, probe_id:$probe, issue_class:$issue,
                          suggested_agent:"dba",
                          remediation:"Thêm index: true vào attribute definition: { type: DataTypes.INTEGER, references: { model: \"Table\", key: \"id\" }, index: true }"}'
                fi
            fi
        done < <(grep -nE '[A-Za-z]+Id\s*:' "$file" 2>/dev/null | head -20)
    done < <(find "$project_path" -maxdepth 8 -type f \( -name '*.ts' -o -name '*.js' \) 2>/dev/null)
}
