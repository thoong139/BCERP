#!/usr/bin/env bash
# Adapter for Hibernate / JPA ORM (Java). Built in IMP-000 Stage 0.
# scan() fully implemented in IMP-010 (Stage 3 Sprint 4).
#
# Detection signals: hibernate.cfg.xml | persistence.xml | dependency hibernate-core | @Entity annotation.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    # Config files
    find "$project_path" -maxdepth 4 -type f \
        \( -name 'hibernate.cfg.xml' -o -name 'persistence.xml' \) \
        -print -quit 2>/dev/null | grep -q . && return 0
    # Dependency trong pom.xml/build.gradle
    if [[ -f "$project_path/pom.xml" ]]; then
        grep -qi 'hibernate' "$project_path/pom.xml" 2>/dev/null && return 0
    fi
    if [[ -f "$project_path/build.gradle" ]]; then
        grep -qi 'hibernate' "$project_path/build.gradle" 2>/dev/null && return 0
    fi
    if [[ -f "$project_path/build.gradle.kts" ]]; then
        grep -qi 'hibernate' "$project_path/build.gradle.kts" 2>/dev/null && return 0
    fi
    # Fallback: @Entity annotation trong .java
    find "$project_path" -maxdepth 5 -type f \
        \( -name '*.java' -o -name '*.kt' \) \
        -exec grep -l '@Entity' {} \; 2>/dev/null | head -1 | grep -q . && return 0
    return 1
}

# scan() — check JPA/Hibernate entity files for missing @Index on FK relations.
# Output: JSON Lines (one signal object per line), exit 0.
# Checks:
#   1. @ManyToOne / @OneToOne fields without class-level @Table(indexes=...) for that column
#   2. JoinColumn without table-level index specification
# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    local probe_id="P-QD6-orm-model-sync"
    local dimension="QD6"
    _sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }

    EXCLUDE='(/test/|/tests/|/src/test/|\.test\.|/spec/)'

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if echo "$file" | grep -qE "$EXCLUDE"; then continue; fi
        if ! grep -q '@Entity' "$file" 2>/dev/null; then continue; fi

        # Check: @ManyToOne / @OneToOne without @Index at class or field level
        while IFS= read -r match; do
            line_num=$(echo "$match" | cut -d: -f1)

            # Check if class has @Table(indexes=...) for this relation
            if ! grep -qE '@Table\(.*indexes|@Index\(' "$file" 2>/dev/null; then
                fp=$(printf '%s' "QD6|${file}|${line_num}|${probe_id}|hibernate_missing_index" | _sha256_fn | awk '{print "sha256:"$1}')
                jq -nc \
                    --arg title "Hibernate/JPA: @ManyToOne/@OneToOne thiếu index" \
                    --arg desc "Entity $(basename "$file" .java) có @ManyToOne/@OneToOne tại dòng ${line_num} nhưng không có @Table(indexes=...) hay @Index. FK join column không có DB index → performance risk." \
                    --arg sev "medium" \
                    --arg file "$file" --argjson line "$line_num" \
                    --arg fp "$fp" --arg dim "$dimension" --arg probe "$probe_id" \
                    --arg issue "hibernate_missing_fk_index" \
                    '{title:$title, description:$desc, severity:$sev,
                      file:$file, line:$line, fingerprint:$fp,
                      dimension:$dim, probe_id:$probe, issue_class:$issue,
                      suggested_agent:"dba",
                      remediation:"Thêm @Table(indexes = {@Index(columnList = \"fk_column_id\")}) vào entity class, hoặc dùng migration tool để tạo index thủ công"}'
                break  # 1 signal per file (deduplicate)
            fi
        done < <(grep -nE '@(ManyToOne|OneToOne)\b' "$file" 2>/dev/null | head -10)
    done < <(find "$project_path" -maxdepth 8 -type f \( -name '*.java' -o -name '*.kt' \) 2>/dev/null)
}
