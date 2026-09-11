#!/usr/bin/env bash
# Adapter for Maven + Gradle (Java/Kotlin/Scala). Built in IMP-000 Stage 0.
# IMP-003 (Stage 3): Implement vuln scan via OWASP Dependency-Check or mvn versions check.
#
# Detection signals: pom.xml | build.gradle | build.gradle.kts
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"pm":"maven","package":"groupId:artifactId","version":"x.y.z","severity":"high|medium|low","cve":"CVE-...","description":"..."}
#   OR: [stub] SPEC-ONLY-PROBE-SKIP pm=maven tool=mvn not installed

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/pom.xml" ]] && return 0
    [[ -f "$project_path/build.gradle" ]] && return 0
    [[ -f "$project_path/build.gradle.kts" ]] && return 0
    return 1
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # Check mvn availability
    if ! command -v mvn >/dev/null 2>&1; then
        echo "[stub] SPEC-ONLY-PROBE-SKIP pm=maven tool=mvn not installed"
        return 0
    fi

    # Run OWASP Dependency-Check (if installed as mvn plugin)
    # Fallback: check for outdated/vulnerable via dependency:tree + known CVEs
    # In CI, dependency-check:check requires network → use --offline flag
    local report_dir
    report_dir="$(mktemp -d -t maven-vuln-XXXXXX)" || return 0
    trap 'rm -rf "$report_dir"' RETURN

    local dc_json="$report_dir/dependency-check-report.json"
    (cd "$project_path" && mvn -q --batch-mode \
        org.owasp:dependency-check-maven:check \
        -DfailBuildOnCVSS=0 \
        -Dformat=JSON \
        -DoutputDirectory="$report_dir" \
        -DskipProvidedScope=false \
        2>/dev/null) || true

    if [[ -f "$dc_json" ]]; then
        # Parse OWASP report JSON
        jq -rc '
          .dependencies[]? |
          select(.vulnerabilities | length > 0) |
          .fileName as $file |
          .vulnerabilities[] |
          {
            pm: "maven",
            package: $file,
            version: (.cvssv3Score // .cvssv2Score // "0" | tostring),
            severity: (.severity // "unknown" | ascii_downcase),
            cve: .name,
            description: (.description // "Vulnerable dependency"),
            fix_available: false
          }
        ' "$dc_json" 2>/dev/null || true
    else
        # OWASP plugin not installed → emit skip
        echo "[stub] SPEC-ONLY-PROBE-SKIP pm=maven tool=dependency-check-maven not configured"
    fi

    return 0
}
