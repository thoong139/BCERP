# Large-Codebase Fixture (CI)

Fixture synthetic dùng để chạy regression tests cho `/wf-fix-bugs` ở scale tương đương EUREKA-2026 (~50k files). Mục đích: bắt scale-related bugs (timeout silent failure, O(N×M) algorithm) **trước khi** chúng lọt ra production codebase.

## TL;DR — Generate + run local

```bash
# 1. Generate fixture (deterministic, seed=42, ~50k files, ~5s)
python .claude/skills/workflow/wf-fix-bugs/evals/fixtures/large-codebase/scripts/generate-fixture.py \
    --out-dir /tmp/wf-fix-large --clean

# 2. Chạy e2e + 4 regression tests
WF_FIX_LARGE_FIXTURE=/tmp/wf-fix-large \
    bash .claude/skills/workflow/wf-fix-bugs/evals/regression-tests/run-all.sh
```

## File này KHÔNG commit

Fixture được generate on-the-fly trong CI. Các file generated bị `.gitignore` (xem `.gitignore` cùng thư mục). KHÔNG commit binary blobs lớn — generator chỉ sinh text source files, ~25 MB total disk khi 50k files.

## Cấu hình

| Param | Default | Ghi chú |
|-------|---------|---------|
| `--seed` | 42 | Deterministic — cùng seed → cùng output |
| `--target-files` | 50000 | Tổng số source files |
| `--target-features` | 300 | Số features trong `req-registry.json` |
| `--out-dir` | (required) | Root directory |
| `--clean` | (off) | Xoá `out-dir` trước khi generate |
| `--force` | (off) | Bỏ qua marker cache, force regen |

## Cấu trúc generated

```
$OUT_DIR/
├── .fixture-marker.json       # Marker (seed, target-files, target-features)
├── .mc-data/docs/_meta/req-registry.json
└── apps/
    ├── erp-web/src/bucket-NNNN/file-XXXXXX.ts (.tsx)
    ├── backend/bucket-NNNN/file-XXXXXX.cs
    ├── mobile-staff/src/bucket-NNNN/file-XXXXXX.ts
    ├── sourcing-svc/src/bucket-NNNN/file-XXXXXX.py
    └── wms-svc/src/bucket-NNNN/file-XXXXXX.py
```

- Mỗi file có `// REQ-ID: REQ-XXX-NNN` + `// FEAT-ID: FEAT-XXX-XXX-NNN` ở dòng đầu
- 200 REQ-IDs unique × 200 FEAT-IDs unique trải đều theo round-robin
- Bucket size 200 files để tránh thư mục có hàng nghìn entries (chậm trên Windows fs)
- Mix ngôn ngữ: 40% .ts/.tsx, 30% .cs, 20% .py

## Idempotent / cache

Chạy lại với cùng `(seed, target-files, target-features)` mà không có `--force` → generator đọc `.fixture-marker.json` và `skip regen`. Phù hợp dùng trong CI: cache `out-dir` giữa các CI run, chỉ regen khi config thay đổi.

## Tests dùng fixture này

| Test | Vấn đề chống regression | File |
|------|------------------------|------|
| `e2e-large-codebase.test.sh` | Lane dispatch QD1+QD2+QD3 deep < 5 phút, no probe failures, schema valid | `evals/e2e-large-codebase.test.sh` |
| `test-probe-timeout-not-silent.sh` | Bug #3: timeout không silent fail (probe-failures.log + healthy=false) | `evals/regression-tests/` |
| `test-xref-on-N-orphans.sh` | Bug #4: xref O(N×M) khi có 1000 orphan REQ-IDs (< 30s) | `evals/regression-tests/` |
| `test-isg-name-narrowing.sh` | Bug #1: ISG `--name` được respect (`scope.name` non-null) | `evals/regression-tests/` |
| `test-init-status-flags.sh` | Bug #2: `--url` + `--credentials` được parse vào `flags` | `evals/regression-tests/` |

## CI integration

GitHub Actions: `.github/workflows/devkit-skill-tests.yml`. Trigger khi PR thay đổi `.claude/skills/workflow/wf-fix-bugs/**` hoặc `.claude/scripts/wf-fix-*`. Skip nếu chỉ thay đổi `*.md`.

Total CI time mục tiêu: **< 10 phút** (generate ~5s + e2e ~3 phút + 4 regression tests ~2 phút).

## Troubleshooting

- **`python: command not found`** — Sử dụng `python3` thay `python` trên Linux/macOS. CI workflow đã set `actions/setup-python@v5` Python 3.13.
- **`jq: command not found`** — Cài đặt: `apt-get install jq` (Ubuntu) | `choco install jq` (Windows). CI runner ubuntu-latest có sẵn.
- **Generator chậm > 30s** — Disk I/O bottleneck. Generator dùng pure stdlib không multi-process; nếu CI runner SSD-bound, chấp nhận.
- **Fixture bị stale (test fail nhưng code đúng)** — Xoá marker hoặc thêm `--force`: `rm $FIXTURE/.fixture-marker.json`.
