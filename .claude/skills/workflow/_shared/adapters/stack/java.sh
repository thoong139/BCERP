#!/usr/bin/env bash
# Adapter for Java stack (incl. Kotlin/Scala JVM). Built in IMP-000 Stage 0.
# IMP-001 (Stage 3): Implement Spring Boot route detection.
#
# Detection signals: pom.xml | build.gradle | build.gradle.kts | settings.gradle
#
# Route detection patterns:
#   - @GetMapping("/path"), @PostMapping, @PutMapping, @DeleteMapping, @PatchMapping
#   - @RequestMapping(value="/path", method=RequestMethod.GET)
#   - @RestController, @Controller on class level
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"file":"path","line":N,"method":"GET|POST|...","route":"...","framework":"spring-boot"}

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1
    [[ -f "$project_path/pom.xml" ]] && return 0
    [[ -f "$project_path/build.gradle" ]] && return 0
    [[ -f "$project_path/build.gradle.kts" ]] && return 0
    [[ -f "$project_path/settings.gradle" ]] && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # -------------------------------------------------------
    # Pattern 1: Spring MVC shorthand annotations
    # @GetMapping("/path"), @PostMapping, @PutMapping, @DeleteMapping, @PatchMapping
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        method=$(echo "$raw" | grep -oE '@(Get|Post|Put|Delete|Patch)Mapping' | sed 's/@//;s/Mapping//' | tr '[:lower:]' '[:upper:]' | head -1) || true
        [[ -z "$method" ]] && method="ANY"
        route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"') || true
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"spring-boot"}\n' \
            "$file" "$line" "$method" "$route"
    done < <(
        grep -rEn '@(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping)' \
            --include='*.java' --include='*.kt' --include='*.scala' \
            "$project_path" 2>/dev/null
    )

    # -------------------------------------------------------
    # Pattern 2: @RequestMapping (generic, class-level or method-level)
    # @RequestMapping(value = "/path", method = RequestMethod.GET)
    # @RequestMapping("/path")  (class-level → prefix)
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        method=$(echo "$raw" | grep -oE 'RequestMethod\.(GET|POST|PUT|DELETE|PATCH)' | cut -d. -f2 | head -1) || true
        [[ -z "$method" ]] && method="ANY"
        route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"') || true
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"spring-boot"}\n' \
            "$file" "$line" "$method" "$route"
    done < <(
        grep -rEn '@RequestMapping\b' \
            --include='*.java' --include='*.kt' --include='*.scala' \
            "$project_path" 2>/dev/null
    )

    return 0
}
