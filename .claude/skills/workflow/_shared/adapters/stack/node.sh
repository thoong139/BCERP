#!/usr/bin/env bash
# Adapter for Node.js stack. Built in IMP-000 Stage 0 (plan wf-fix-bugs-dimensions-audit-v1).
# IMP-001 (Stage 3): Implement Express/NestJS/Next.js route detection.
#
# Detection signals: package.json present.
#
# Route detection patterns:
#   Express/Koa: app.get("/path", ...), router.get("/path", ...), app.use("/path", ...)
#   NestJS: @Get("/path"), @Post, @Put, @Delete, @Patch on controller methods
#   Next.js: app/[route]/route.ts export GET/POST handlers (App Router)
#            pages/api/[route].ts (Pages Router)
#
# OUTPUT (scan): newline-delimited JSON objects:
#   {"file":"path","line":N,"method":"GET|POST|...","route":"...","framework":"express|nestjs|nextjs"}

# shellcheck disable=SC2317
detect() {
    local project_path="${1:-.}"
    [[ -f "$project_path/package.json" ]]
}

# shellcheck disable=SC2317
scan() {
    local project_path="${1:-.}"
    [[ ! -d "$project_path" ]] && return 1

    # -------------------------------------------------------
    # Pattern 1: Express/Koa/Fastify — app.METHOD("/path")
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        method=$(echo "$raw" | grep -oE '\.(get|post|put|delete|patch|options|head|all)\(' | tr -d '.' | tr -d '(' | tr '[:lower:]' '[:upper:]' | head -1)
        [[ "$method" = "ALL" ]] && method="ANY"
        [[ -z "$method" ]] && method="ANY"
        route=$(echo "$raw" | grep -oE "'[^']+'" | head -1 | tr -d "'")
        [[ -z "$route" ]] && route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"express"}\n' \
            "$file" "$line" "$method" "$route"
    done < <(
        grep -rEn '\b(app|router|server|api)\.(get|post|put|delete|patch|options|head|all)\s*\(' \
            --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' --include='*.mjs' \
            "$project_path" 2>/dev/null
    )

    # -------------------------------------------------------
    # Pattern 2: NestJS decorators — @Get("/path"), @Post, etc.
    # -------------------------------------------------------
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        local file line method route
        file=$(echo "$match" | cut -d: -f1)
        line=$(echo "$match" | cut -d: -f2)
        raw=$(echo "$match" | cut -d: -f3-)
        method=$(echo "$raw" | grep -oE '@(Get|Post|Put|Delete|Patch)\b' | tr -d '@' | tr '[:lower:]' '[:upper:]' | head -1)
        [[ -z "$method" ]] && method="ANY"
        route=$(echo "$raw" | grep -oE "'[^']+'" | head -1 | tr -d "'")
        [[ -z "$route" ]] && route=$(echo "$raw" | grep -oE '"[^"]+"' | head -1 | tr -d '"')
        [[ -z "$route" ]] && route="[inferred]"
        printf '{"file":"%s","line":%s,"method":"%s","route":"%s","framework":"nestjs"}\n' \
            "$file" "$line" "$method" "$route"
    done < <(
        grep -rEn '@(Get|Post|Put|Delete|Patch)\s*\(' \
            --include='*.ts' --include='*.tsx' \
            "$project_path" 2>/dev/null
    )

    return 0
}
