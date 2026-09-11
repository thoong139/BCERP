# REQ-ID Patterns — wf-verify-sync

**Trong registry và docs:**

```
REQ-[A-Z]+-\d+           # Standard:  REQ-FIN-001
REQ-[A-Z]+-[A-Z]+-\d+    # Extended:  REQ-ERP-FIN-001
```

**Trong code (mọi ngôn ngữ):**

```typescript
// REQ-ID: REQ-FIN-001           // TypeScript / Go / Java
/* REQ-ID: REQ-FIN-001 */
# REQ-ID: REQ-FIN-001            // Python
[Description("REQ-API-FIN-001")] // C# attribute
```

**Exclude patterns (Phase 1 KHÔNG scan):**

*Directories (luôn skip):* `node_modules/`, `dist/`, `build/`, `.next/`, `out/`, `.git/`, `__generated__/`, `generated/`, `coverage/`, `.turbo/`

*Generated/compiled files:* `*.d.ts`, `*.d.cts`, `*.d.mts`, `*.min.js`, `*.min.css`, `*.bundle.*`, `*.generated.*`, `*.gen.*`, `*.pb.ts`, `*_pb.ts`, `*_grpc_pb.ts`, `*.snap`, `*.map`, `*.js.map`, `*.css.map`, `*.lock`, `*.g.dart`, `*.freezed.dart`

*Config/build/project files (KHÔNG scan REQ-ID):* `*.config.*`, `*.config`, `*.csproj`, `*.vbproj`, `*.fsproj`, `*.vcxproj`, `*.sln`, `*.xaml`, `*.axml`, `*.props`, `*.targets`, `*.resx`, `*.svg`, `*.xml`, `*.json`, `*.jsonc`, `*.jsonl`, `*.yaml`, `*.yml`, `*.toml`, `*.ini`, `*.cfg`, `*.conf`, `*.properties`, `*.env*`, `Dockerfile`, `Makefile`, `*.gradle`, `*.cmake`, `CMakeLists.txt`

*Style/doc/data files:* `*.css`, `*.scss`, `*.less`, `*.sass`, `*.md`, `*.mdx`, `*.rst`, `*.txt`, `*.sql`, `*.prisma`, `*.graphql`

*Standard barrel/utility files:* `index.ts`, `index.js`, `types.ts`, `types.js`, `constants.ts`, `constants.js`

*Test/story files:* `*.test.*`, `*.spec.*`, `*.stories.*`, `*.fixture.*`

**Monorepo support:** Nếu có `apps/` — scan `apps/*/src/` cho mỗi app. Nếu có `packages/` — scan `packages/*/src/` cho shared packages. Orphan list ghi rõ app/package nào.
