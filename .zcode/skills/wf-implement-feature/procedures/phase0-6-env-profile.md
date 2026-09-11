# Phase 0.6: Environment Profile Detection (v5.1+)

> Phát hiện môi trường build và framework để inject rules phù hợp vào agent context.
> Chạy SAU phase0-5-context-setup.md, TRƯỚC phase0-7-safety-gate.md.

**PRE-GATE:** `$FEATURE_SLUG` và `$SYSTEM_SLUG` đã set (từ Phase 0).

---

## BƯỚC 1: Detect Build Tool

| Step | Action | Verify |
|------|--------|--------|
| 0.6.1 | Check `test -f vite.config.ts \|\| test -f vite.config.js \|\| test -f vite.config.mjs` → `$BUILD_TOOL = "vite"` | Detection result |
| 0.6.2 | Check `test -f next.config.ts \|\| test -f next.config.js \|\| test -f next.config.mjs` → `$BUILD_TOOL = "nextjs"` | Detection result |
| 0.6.3 | Check `test -f package.json` → `jq -r '.dependencies + .devDependencies \| keys[]' package.json` grep cho `"react"`, `"vue"`, `"angular"` | Framework detected |
| 0.6.4 | Nếu không detect được → `$BUILD_TOOL = "generic"` | Fallback |

## BƯỚC 2: Set Environment Profile

| Detection | Signal | `$ENV_PROFILE` |
|-----------|--------|----------------|
| `vite.config.*` exists | Vite project | `vite` |
| `next.config.*` exists | Next.js project | `nextjs` |
| `package.json` has `"react"` but no vite/next | CRA/Custom React | `react-generic` |
| Only `server/` has `package.json` | Pure Node.js backend | `node-server` |
| None of the above | Unknown | `generic` |

| Step | Action | Verify |
|------|--------|--------|
| 0.6.5 | Resolve `$ENV_PROFILE` từ detection table trên | Profile set |

## BƯỚC 3: Detect Framework & CSS

| Step | Action | Verify |
|------|--------|--------|
| 0.6.6 | `jq -r '.dependencies + .devDependencies \| keys[]' package.json` → detect framework: `react` / `vue` / `angular` / `none` → `$FRAMEWORK` | Framework set |
| 0.6.7 | Detect CSS solution: `tailwindcss` / `@emotion/react` / `styled-components` / `css-modules` / `none` → `$CSS_SOLUTION` | CSS set |
| 0.6.8 | Detect server framework: `hono` / `express` / `@nestjs/core` / `fastify` / `none` → `$SERVER_FRAMEWORK` | Server set |
| 0.6.9 | Detect database: `better-sqlite3` / `typeorm` / `prisma` / `@nestjs/typeorm` / `knex` / `none` → `$DB_CLIENT` | DB set |

## BƯỚC 4: Build Environment Rules

### Environment-Specific Rules (inject vào agent context)

| Profile | Rules |
|---------|-------|
| `vite` | `import.meta.env.VITE_*` cho client, `process.env` cho server (Vite SSR/config); KHÔNG `define` secrets; `import.meta.env` values là string constants at build time |
| `nextjs` | `NEXT_PUBLIC_*` cho client components; server components dùng `process.env`; middleware edge runtime restrictions |
| `node-server` | Validate env vars at startup; KHÔNG hardcoded fallback secrets; dùng `dotenv` hoặc built-in |
| `react-generic` | React hooks rules; strict mode compliance |
| `generic` | No specific rules — rely on general best practices |

| Step | Action | Verify |
|------|--------|--------|
| 0.6.10 | Compile `$ENV_RULES` string từ profile (theo bảng trên) | Rules set |
| 0.6.11 | SET `$ENV_CONTEXT` = tổng hợp `{profile, build_tool, framework, css_solution, server_framework, db_client, env_rules}` | Context compiled |

---

## POST-GATE

`$ENV_PROFILE`, `$ENV_CONTEXT` set. Inject vào tất cả agent contexts qua `_shared.md`.

- `$ENV_CONTEXT` được append vào Developer, Code Reviewer, QA Lead, Security agent prompts
- Environment rules bổ sung cho các quality checklists

---

## Output State Variables

| Variable | Set | Consumed by |
|----------|-----|-------------|
| `$ENV_PROFILE` | `vite` / `nextjs` / `react-generic` / `node-server` / `generic` | phase2 (planning context), phase3 (agent context), phase4-5 (review context), BƯỚC 2b safety scan |
| `$ENV_CONTEXT` | Object `{profile, build_tool, framework, css_solution, server_framework, db_client, env_rules}` | Tất cả agent spawn contexts |
| `$BUILD_TOOL` | `vite` / `nextjs` / `generic` | BƯỚC 2b safety scan (E5 pattern) |
| `$FRAMEWORK` | `react` / `vue` / `angular` / `none` | phase3 (agent selection) |
| `$CSS_SOLUTION` | `tailwindcss` / `emotion` / `styled-components` / `css-modules` / `none` | phase3 (agent context) |
| `$SERVER_FRAMEWORK` | `hono` / `express` / `nestjs` / `fastify` / `none` | phase3 (agent context) |
| `$DB_CLIENT` | `better-sqlite3` / `typeorm` / `prisma` / `knex` / `none` | phase3 (agent context) |
