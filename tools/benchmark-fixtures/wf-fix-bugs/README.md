# wf-fix-bugs Benchmark Fixture

> Synthetic project reproducible cho benchmark `/wf-fix-bugs` performance.
> Tạo bởi `build-fixture.sh` → output ở `output/` (gitignored).
> Dùng cho plan `plans/wf-fix-bugs-v10-speedup/` (Wave 1.4, 2.3, 3.4 benchmarks).

---

## Mục Tiêu

- **Reproducible**: cùng input → cùng bug count + cùng quality metrics qua mọi lần build
- **Đại diện**: 3 modules business, mix severity + sources + dimensions
- **Lightweight**: không cần `npm install` cho benchmark (Wave 1 dev cycle); Phase 2 sẽ thêm runtime server

---

## Cấu Trúc

```
benchmark-fixtures/wf-fix-bugs/
├── README.md                    # File này
├── build-fixture.sh             # Build output/ từ template/
├── reset-fixture.sh             # Xóa output/ + re-build
├── .gitignore                   # Ignore output/
├── template/
│   ├── package.json             # Project metadata (no install needed for static scan)
│   ├── tsconfig.json
│   ├── BUG-CATALOG.md           # Manifest 15 bugs với expected detection
│   ├── .mc-data/
│   │   └── docs/
│   │       ├── _meta/req-registry.json   # SSOT 15 requirements
│   │       ├── phase0-brainstorm/...
│   │       └── phase2-features/[sys]/[mod]/[feat].md
│   └── src/
│       ├── sales/     (orders + quotations — 5 bugs)
│       ├── crm/       (customers + leads — 5 bugs)
│       └── finance/   (invoices + payments — 5 bugs)
└── output/                      # Built fixture (gitignored)
```

---

## Cách Dùng

### Build fixture (lần đầu hoặc reset)

```bash
cd tools/benchmark-fixtures/wf-fix-bugs
bash build-fixture.sh                          # Build vào output/
# OR
bash build-fixture.sh --target /tmp/bench-1    # Build vào custom path
```

### Run baseline benchmark

```bash
cd output/                                      # Hoặc custom path
# Snapshot timestamp
START=$(date +%s)
# Run wf-fix-bugs từ thư mục của fixture (KHÔNG cd ra MCV3)
# Note: wf-fix-bugs sẽ detect MCV3 skill từ parent dir hoặc qua claude code session
/wf-fix-bugs --profile=exhaustive --scope=all --no-browser
END=$(date +%s)
echo "Duration: $((END-START))s"
```

### Reset fixture (re-run benchmark từ clean state)

```bash
bash reset-fixture.sh                          # Xóa output/ + re-build
```

### Verify bug detection

Sau khi `/wf-fix-bugs` chạy xong:

```bash
SESSION=$(ls -t output/.mc-data/work/wf-fix-bugs/sessions/ | head -1)
EXPECTED=20  # Tổng bugs trong BUG-CATALOG.md
DETECTED=$(jq '.issues | length' "output/.mc-data/work/wf-fix-bugs/sessions/$SESSION/phase5-triage/issue-registry.json")
echo "Detected $DETECTED / $EXPECTED bugs"
```

---

## Bug Distribution

**Total: 20 bugs** (sau khi build template được verify thực tế)

| Module | CRITICAL | HIGH | MEDIUM | LOW | Total |
|--------|:--------:|:----:|:------:|:---:|:-----:|
| sales (orders + quotations) | 1 | 2 | 1 | 1 | 5 |
| crm (customers + leads) | 1 | 3 | 3 | 1 | 8 |
| finance (invoices + payments) | 1 | 2 | 3 | 1 | 7 |
| **Total** | **3** | **7** | **7** | **3** | **20** |

| Source | Count | Notes |
|--------|:-----:|-------|
| static-scan | 13 | Lint, type, null ref, deprecated, perf, security patterns |
| runtime | 0 | (v1 — deferred to v2) |
| llm-scan | 7 | Business rules, missing validations |

| Dimension | Coverage |
|-----------|----------|
| QD1 functional | 8+ bugs |
| QD2 business | 5+ bugs |
| QD3 security | 3 bugs |
| QD4 performance | 2 bugs |
| QD5 UX/a11y | 3 bugs |
| QD10 cross-module | 1 bug |
| QD11 completeness | 3 bugs |

> Chi tiết per bug → `template/BUG-CATALOG.md`

---

## Benchmark Methodology

1. `bash reset-fixture.sh` → clean state
2. Snapshot `date +%s` → run wf-fix-bugs → snapshot end
3. Verify expected vs detected (15 bugs)
4. Compare quality metrics: fixed/deferred/failed counts
5. Compare CI tool call count (`fix-log.json` event=CI_TOOL_USED)
6. Compare cache hit ratio (post W1.2): `jq '[.entries[] | select(.cache_hit==true)] | length / [.entries[]] | length' fix-log.json`

> Detailed methodology: `plans/wf-fix-bugs-v10-speedup/02-benchmark.md`

---

## Roadmap

- **v1 (this commit):** Static-scan + llm-scan bugs, no runtime server. Run với `--no-browser`.
- **v2 (future):** Add minimal Express server + Playwright-detectable runtime bugs (5 thêm).
- **v3 (future):** Multi-app monorepo variant để benchmark cross-app fix.
