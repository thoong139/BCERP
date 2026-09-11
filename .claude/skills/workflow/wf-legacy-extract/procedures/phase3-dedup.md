# Phase 3: Deduplication & Divergence Detection

> Cross-module dedup pass — merge requirements có similarity > 85%.
> Nếu strategy S5 (hoặc maturity level `CODE_PLUS_*`): chạy divergence detection
> giữa from_code và from_docs sources.

**PRE-GATE:**
- [ ] Phase 2 POST-GATE PASS
- [ ] `extracted/*.json` files tồn tại cho tất cả modules đã extract
- [ ] `$EXTRACTED_MODULES` không rỗng

**INPUT:**
- `.mc-data/work/legacy-scan/extracted/{module}.json` (tất cả modules)
- `$EXTRACTED_MODULES`, `$STRATEGY_ID`, `$MATURITY_LEVEL`

**OUTPUT:**
- `.mc-data/work/legacy-scan/extracted/dedup-report.json`
- `.mc-data/work/legacy-scan/extracted/{module}-divergences.json` (chỉ S5)
- In-memory: `$DEDUP_STATS`

---

## Reference Sections

- `_shared.md` §Error Code Reference (E008 — dedup ambiguous)

---

## Steps

| Step | Action | Tool | Verify |
|------|--------|------|--------|
| 3.1 | **Load extracted data:** Đọc tất cả `extracted/*.json` (loại trừ `dedup-report.json` và `*-divergences.json`) → flatten thành `all_requirements[]` với metadata `{module, req_id, title, description, confidence}` | Read | Array loaded |
| 3.2 | **Compute similarity matrix:** Cho mỗi cặp (req_a, req_b) trong all_requirements — tính similarity score (cosine similarity trên title + description, hoặc Levenshtein). Chỉ xét các cặp cùng domain/system để giảm complexity | — | Matrix computed |
| 3.3 | **Classify similarity results:** Xem §Similarity Classification (bên dưới) | — | Classifications done |
| 3.4 | **Merge high-similarity requirements (> 85%):** Pick requirement có confidence cao hơn làm canonical, link các bản khác là `duplicate_of`. Update `extracted/{module}.json` tương ứng | Read/Write | Merges applied |
| 3.5 | **Handle ambiguous (70-85%):** Giữ cả hai requirements, WARN E008, log vào `ambiguous[]` trong dedup-report | — | Ambiguous logged |
| 3.6 | **Write dedup-report.json:** Xem §Dedup Report Schema | Write | `test -f extracted/dedup-report.json` |
| 3.7 | **Divergence Detection (S5 only):** Chạy chỉ khi `$STRATEGY_ID == "S5"` OR `$MATURITY_LEVEL IN ("CODE_PLUS_EXTERNAL_DOCS", "CODE_PLUS_DEVKIT_PARTIAL")`. Xem §Divergence Detection | Read/Write | `{module}-divergences.json` per module |
| 3.8 | **Update $DEDUP_STATS:** `{merged_count, ambiguous_count, kept_count}` — dùng cho Phase 5 report | — | Stats ready |

---

## Similarity Classification (Step 3.3)

| Similarity | Classification | Hành động |
|-----------|---------------|-----------|
| > 85% | DUPLICATE | Merge — pick canonical (confidence cao hơn) |
| 70-85% | AMBIGUOUS | Giữ cả hai, WARN E008, log vào ambiguous[] |
| < 70% | UNIQUE | Giữ nguyên cả hai |

---

## Dedup Report Schema (Step 3.6)

```json
{
  "generated_at": "ISO 8601",
  "total_requirements_before": 245,
  "total_requirements_after": 228,
  "merged": [
    {
      "canonical": { "module": "auth", "req_id": "TMP-AUTH-001", "title": "..." },
      "duplicates": [
        { "module": "user", "req_id": "TMP-USER-015", "title": "...", "similarity": 0.91 }
      ]
    }
  ],
  "ambiguous": [
    {
      "req_a": { "module": "sales", "req_id": "TMP-SALES-003" },
      "req_b": { "module": "crm", "req_id": "TMP-CRM-007" },
      "similarity": 0.78,
      "reason": "Tương đồng trong title nhưng khác behavior"
    }
  ],
  "stats": {
    "merged_count": 17,
    "ambiguous_count": 4,
    "kept_count": 228
  }
}
```

---

## Divergence Detection (Step 3.7 — S5 only)

> Chỉ chạy khi `$STRATEGY_ID == "S5"` hoặc `$MATURITY_LEVEL IN ("CODE_PLUS_EXTERNAL_DOCS", "CODE_PLUS_DEVKIT_PARTIAL")`.

**Mục đích:** Khi có cả code VÀ docs (external hoặc DEVKIT partial), so sánh để phát hiện:
- Behavior documented nhưng chưa implement
- Behavior implement nhưng chưa document
- Divergence giữa spec (docs) và reality (code)

**Thuật toán per module:**

```
1. Tách extracted data thành 2 sources:
   - from_code: requirements có source chứa code files (.ts, .cs, .py, .java, ...)
   - from_docs: requirements có source chứa doc files (.md, .pdf, .docx, ...)

2. So sánh 2 sets → phân loại từng requirement:
   - SYNCED: có trong cả code và docs, mô tả tương đồng (similarity > 85%)
   - DIVERGED: có trong cả 2 nhưng mô tả khác nhau (similarity 40-85%)
   - UNDOCUMENTED: có trong code nhưng KHÔNG có trong docs
   - UNIMPLEMENTED: có trong docs nhưng KHÔNG có trong code

3. Ghi output: extracted/{module}-divergences.json
```

**Divergence file schema:**

```json
{
  "module": "auth",
  "synced": [
    { "code_req": "TMP-AUTH-001", "doc_req": "TMP-AUTH-001", "similarity": 0.92 }
  ],
  "diverged": [
    {
      "code_req": "TMP-AUTH-003",
      "doc_req": "TMP-AUTH-007",
      "similarity": 0.65,
      "code_says": "JWT hết hạn sau 1 giờ",
      "doc_says": "JWT hết hạn sau 24 giờ",
      "resolution_hint": "Code is truth — document cần cập nhật"
    }
  ],
  "undocumented": [
    { "code_req": "TMP-AUTH-005", "title": "Rate limit login attempts", "note": "Code có, docs thiếu" }
  ],
  "unimplemented": [
    { "doc_req": "TMP-AUTH-009", "title": "2FA support", "note": "Docs mô tả, code chưa có" }
  ]
}
```

**Quy tắc output:**
- UNDOCUMENTED items → được include vào `extracted/{module}.json` (code là truth)
- UNIMPLEMENTED items → giữ lại trong divergence file, KHÔNG đưa vào extracted (chờ user quyết định)

---

## POST-GATE

- [ ] `extracted/dedup-report.json` tồn tại
- [ ] `test -s extracted/dedup-report.json` pass (non-empty)
- [ ] `jq '.' extracted/dedup-report.json` pass (valid JSON)
- [ ] `dedup-report.json` có `merged[]`, `ambiguous[]`, `stats`
- [ ] `$DEDUP_STATS` set (cho Phase 5)
- [ ] **S5 only:** `extracted/{module}-divergences.json` tồn tại cho mỗi module
- [ ] **S5 only:** Divergence files có 4 categories (synced, diverged, undocumented, unimplemented)

**Next phase:** `phase4-alignment.md`
