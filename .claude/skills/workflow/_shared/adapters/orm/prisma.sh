#!/usr/bin/env bash
# Adapter for Prisma ORM (Node.js/TypeScript). Built in IMP-000 Stage 0.
# scan() fully implemented in IMP-010 (Stage 3 Sprint 4).
#
# Detection signals: prisma/schema.prisma | dependency @prisma/client trong package.json.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/prisma/schema.prisma" ]] && return 0
    [[ -f "$project_path/schema.prisma" ]] && return 0
    # Fallback: check dependency trong package.json
    if [[ -f "$project_path/package.json" ]]; then
        grep -q '"@prisma/client"' "$project_path/package.json" 2>/dev/null && return 0
    fi
    return 1
}

# scan() — check Prisma schema for missing indexes on relation/FK fields.
# Output: JSON Lines (one signal object per line), exit 0.
# Checks:
#   1. Model có @relation fields mà không có @@index trên FK field
#   2. Model có FK field (suffix Id) không có @@index
# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    local probe_id="P-QD6-orm-model-sync"
    local dimension="QD6"
    _sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }

    # Tìm schema.prisma files
    while IFS= read -r schema_file; do
        [ -z "$schema_file" ] && continue
        [ ! -f "$schema_file" ] && continue

        # Parse: tìm model blocks
        local current_model=""
        local model_start_line=0
        local line_num=0
        local fk_fields=()

        while IFS= read -r line; do
            line_num=$((line_num + 1))

            # Detect model block start
            if echo "$line" | grep -qE '^model [A-Z]'; then
                current_model=$(echo "$line" | awk '{print $2}')
                model_start_line=$line_num
                fk_fields=()
                continue
            fi

            # Detect model block end
            if [ "$line" = "}" ] && [ -n "$current_model" ]; then
                # Đọc lại model block để check @@index per FK field
                if [ ${#fk_fields[@]} -gt 0 ]; then
                    for fk_field in "${fk_fields[@]}"; do
                        # Check if @@index([fk_field]) exists in the model
                        if ! grep -qE "@@index\(\[${fk_field}\]|@@index\(\[.*${fk_field}.*\]" "$schema_file" 2>/dev/null; then
                            fp=$(printf '%s' "QD6|${schema_file}|${model_start_line}|${probe_id}|prisma_missing_index_${fk_field}" | _sha256_fn | awk '{print "sha256:"$1}')
                            jq -nc \
                                --arg title "Prisma: FK field thiếu @@index" \
                                --arg desc "Model ${current_model} có FK field ${fk_field} nhưng không có @@index([${fk_field}]). Query filter/join theo FK sẽ chậm (full table scan)." \
                                --arg sev "medium" \
                                --arg file "$schema_file" --argjson line "$model_start_line" \
                                --arg fp "$fp" --arg dim "$dimension" --arg probe "$probe_id" \
                                --arg issue "prisma_missing_fk_index" \
                                '{title:$title, description:$desc, severity:$sev,
                                  file:$file, line:$line, fingerprint:$fp,
                                  dimension:$dim, probe_id:$probe, issue_class:$issue,
                                  suggested_agent:"dba",
                                  remediation:"Thêm @@index(['"${fk_field}"']) vào model '"${current_model}"' trong schema.prisma"}'
                        fi
                    done
                fi
                current_model=""
                fk_fields=()
                continue
            fi

            # Collect FK fields (suffix Id và có @relation hoặc tên field)
            if [ -n "$current_model" ]; then
                # Field tên kết thúc bằng Id (không phải id primary key)
                if echo "$line" | grep -qE '^\s+[a-zA-Z]+Id\s+'; then
                    field_name=$(echo "$line" | awk '{print $1}' | tr -d ' ')
                    # Bỏ qua id, uuid primary keys
                    if [ "$field_name" != "id" ]; then
                        fk_fields+=("$field_name")
                    fi
                fi
            fi
        done < "$schema_file"
    done < <(find "$project_path" -maxdepth 6 -name 'schema.prisma' -type f 2>/dev/null)
}
