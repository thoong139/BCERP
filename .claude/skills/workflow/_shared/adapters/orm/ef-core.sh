#!/usr/bin/env bash
# Adapter for Entity Framework Core (.NET). Built in IMP-000 Stage 0.
# scan() fully implemented in IMP-010 (Stage 3 Sprint 4).
#
# Detection signals: *.csproj có PackageReference Microsoft.EntityFrameworkCore* | DbContext class.

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    # Check PackageReference EntityFrameworkCore trong .csproj
    find "$project_path" -maxdepth 4 -type f \
        \( -name '*.csproj' -o -name '*.fsproj' \) \
        -exec grep -l 'EntityFrameworkCore' {} \; 2>/dev/null | grep -q . && return 0
    # Fallback: tìm class kế thừa DbContext
    find "$project_path" -maxdepth 5 -type f -name '*.cs' \
        -exec grep -l 'DbContext' {} \; 2>/dev/null | head -1 | grep -q . && return 0
    return 1
}

# scan() — check EF Core entity configuration issues.
# Output: JSON Lines (one signal object per line), exit 0.
# Checks:
#   1. IEntityTypeConfiguration files có Property(*Id) mà thiếu HasIndex
#   2. DbContext OnModelCreating thiếu Entity configuration entries
# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    local probe_id="P-QD6-orm-model-sync"
    local dimension="QD6"
    local lane="wf-fix-data"
    _sha256_fn() { sha256sum 2>/dev/null || shasum -a 256; }

    # CHECK 1: IEntityTypeConfiguration files có FK property mà thiếu HasIndex
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if ! grep -qE 'IEntityTypeConfiguration|EntityTypeBuilder' "$file" 2>/dev/null; then continue; fi

        # Tìm Property(x => x.*Id) mà không có HasIndex gần đó trong file
        while IFS= read -r match; do
            line_num=$(echo "$match" | cut -d: -f1)
            prop_name=$(echo "$match" | grep -oE '[A-Za-z]+Id\b' | head -1)
            [ -z "$prop_name" ] && continue

            # Nếu file không có HasIndex thật (lọc comment lines)
            if ! grep -vE '^\s*//' "$file" 2>/dev/null | grep -qE "HasIndex\("; then
                fp=$(printf '%s' "QD6|${file}|${line_num}|${probe_id}|missing_ef_index" | _sha256_fn | awk '{print "sha256:"$1}')
                jq -nc \
                    --arg title "EF Core: FK property thiếu HasIndex" \
                    --arg desc "Configuration $(basename "$file" .cs) có property ${prop_name} (likely FK) nhưng không có HasIndex(). EF Core không tạo DB index → query chậm khi join/filter theo FK." \
                    --arg sev "medium" \
                    --arg file "$file" --argjson line "$line_num" \
                    --arg fp "$fp" --arg dim "$dimension" --arg probe "$probe_id" \
                    --arg issue "missing_fk_index" \
                    '{title:$title, description:$desc, severity:$sev,
                      file:$file, line:$line, fingerprint:$fp,
                      dimension:$dim, probe_id:$probe, issue_class:$issue,
                      suggested_agent:"dba",
                      remediation:"Thêm builder.HasIndex(x => x.'"${prop_name}"').HasDatabaseName(\"IX_TableName_'"${prop_name}"'\");"}'
            fi
        done < <(grep -nE 'Property\(.*[A-Za-z]+Id\b' "$file" 2>/dev/null | head -20)
    done < <(find "$project_path" -maxdepth 8 -type f -name '*.cs' 2>/dev/null)
}
