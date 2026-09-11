# Phase 3: Glossary Generation

> Spawn `business-analyst` agent — tạo `glossary.json` từ domain terms phát hiện trong classified data.
> Phase ngắn (single agent), nhưng critical cho downstream skills (`/wf-legacy-extract`).

**PRE-GATE:**
- Phase 2 POST-GATE PASS
- Có ít nhất 1 file `classified/batch-*.json` valid trên disk
- `test -f .claude/skills/workflow/wf-legacy-classify/templates/glossary.json` (template)

**INPUT:**
- `.mc-data/work/legacy-scan/classified/batch-*.json` (tất cả)
- `.mc-data/work/legacy-scan/ledger.json` (project name)
- `.claude/skills/workflow/wf-legacy-classify/templates/glossary.json` (template schema)

**OUTPUT:**
- `.mc-data/work/legacy-scan/classified/glossary.json` (từ template, populated bởi business-analyst)

---

## Reference Sections

- `_shared.md` §Agent Prompt Templates — business-analyst Agent
- `_shared.md` §Fix Rules
- `_shared.md` §Error Codes (E021)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | **READ template** `.claude/skills/workflow/wf-legacy-classify/templates/glossary.json` (CORE-031) — cache schema để truyền vào agent prompt | Read | Template loaded |
| 3.2 | **Spawn `business-analyst` agent** với prompt từ `_shared.md §Agent Prompt Templates — business-analyst Agent`. Truyền template schema + project_name. Agent đọc tất cả `classified/batch-*.json`, populate template, ghi `.mc-data/work/legacy-scan/classified/glossary.json` | Agent (business-analyst) | File written |
| 3.3 | **Validate glossary.json** (xem §Validation bên dưới) — nếu fail → E021 retry (max 2) | Read | JSON valid, schema OK |
| 3.4 | **Fallback**: nếu sau 2 retries vẫn fail → tạo glossary từ template với empty values (giữ `$schema`, `project`, `created_at`, `created_by`, `stats={total_terms:0, ...}`), log WARNING vào error_log | Write | Fallback file created |

---

## Validation

```
1. test -f classified/glossary.json
2. test -s classified/glossary.json
3. jq '.' classified/glossary.json > /dev/null  (JSON valid)
4. jq -e '."$schema" == "legacy-scan-glossary-v1"' classified/glossary.json
5. jq -e '.project != ""' classified/glossary.json
6. jq -e 'has("terms") and has("abbreviations") and has("domain_concepts") and has("stats")' classified/glossary.json
7. jq -e '.stats | has("total_terms") and has("total_abbreviations") and has("total_domain_concepts") and has("modules_covered")' classified/glossary.json

IF terms.length == 0 AND project quá nhỏ → WARNING (acceptable)
```

---

## Phase 3 POST-GATE

```
1. test -f .mc-data/work/legacy-scan/classified/glossary.json
2. JSON valid + có $schema = "legacy-scan-glossary-v1"
3. Có đầy đủ 4 top-level fields: terms, abbreviations, domain_concepts, stats
4. stats có 4 sub-fields: total_terms, total_abbreviations, total_domain_concepts, modules_covered
5. project field non-empty
```

---

## Error Handling

| Code | Tình huống | Xử lý |
|------|-----------|-------|
| E021 | business-analyst agent fail (timeout/output invalid) | Retry agent max 2 lần. Vẫn fail → tạo glossary rỗng từ template với WARNING |

---

**Next phase:** `phase4-verify.md`
