# `_shared/adapters/` — Stack / PM / ORM Detection & Dispatcher

> **Trạng thái:** B0 Skeleton (IMP-000, Stage 0 G0 of plan `wf-fix-bugs-dimensions-audit-v1`)
> **Built:** 2026-05-08
> **Owner:** skill-author
> **Registry role:** NONE (CORE-006 — không ghi `req-registry.json`)
> **Ngôn ngữ:** Tài liệu tiếng Việt; tên file + API English (CORE-005)

---

## 1. Vì sao có thư mục này

QD1 audit pre-seed phát hiện stack bias trong nhiều probe (Node/JS-centric). Cross-cutting Theme 1 confirm: P-QD1-route-config-parse, P-QD3-dependency-vuln-scan, P-QD4-db-query-analysis, P-QD6-orm-model-sync, P-QD6-migration-integrity đều assume một stack/PM/ORM duy nhất.

Để IMP-001 / IMP-003 / IMP-010 không trùng lặp logic detect, tách phần **detect → dispatch → adapter** thành module riêng:

- **Dispatcher** (`_dispatcher.sh`): scan target path → identify stacks/PMs/ORMs hiện diện
- **Adapter** (`stack/*.sh`, `package-manager/*.sh`, `orm/*.sh`): mỗi file định nghĩa cách detect + scan cho 1 ecosystem

Mỗi probe khi cần chạy multi-stack chỉ cần invoke `_dispatcher.sh` rồi loop qua adapters đã match. Probe không phải embed logic detect.

---

## 2. Adapter contract (BẮT BUỘC)

Mỗi adapter file `<adapter>.sh` PHẢI export 2 function:

```bash
# detect <project_path>
# Trả về: 0 nếu adapter applicable, 1 nếu không
# Side effect: ghi line vào stdout dạng "<adapter-id>:<evidence-file>" (optional)
detect() {
    local project_path="${1:-.}"
    # Check file dấu hiệu (lockfile, manifest, file extension, …)
    # ...
    return 0  # hoặc 1
}

# scan <project_path>
# Trả về: 0 success, ≠0 error
# Stdout: JSON Lines, mỗi line = 1 finding theo schema do probe quy định
# (Schema cụ thể được probe gọi adapter định nghĩa, ví dụ:
#   route-config-parse → {"route":"/api/x", "method":"GET", "file":"...", "line":N}
#   dependency-vuln-scan → {"package":"x", "version":"1.0", "cve":"CVE-...", "severity":"high"}
# )
scan() {
    local project_path="${1:-.}"
    # Skeleton: in stub message
    echo "[stub] <adapter-id> scan() chưa implement — IMP-000 Stage 0 chỉ build scaffolding"
    return 0
}
```

Adapter file PHẢI có comment header:

```bash
# Adapter for <stack/PM/ORM>. Built in IMP-000 Stage 0 (plan wf-fix-bugs-dimensions-audit-v1).
# Full implementation in IMP-001 (route detection) / IMP-003 (vuln scan) / IMP-010 (ORM) at Stage 3.
```

---

## 3. Dispatcher API

### 3.1. CLI

```bash
# Liệt kê tất cả adapters đã đăng ký
bash _dispatcher.sh --list-adapters
# Output (1 line per adapter):
#   stack/node
#   stack/dotnet
#   ...

# Detect adapters applicable cho 1 project
bash _dispatcher.sh --detect <project_path>
# Output (1 line per match):
#   stack/node
#   package-manager/npm
#   orm/prisma

# In ra adapter contract (cho debug)
bash _dispatcher.sh --help
```

### 3.2. Exit codes

| Code | Ý nghĩa |
|---|---|
| 0 | Success |
| 1 | Bad usage (thiếu arg, flag không hỗ trợ) |
| 2 | Project path không tồn tại |
| 3 | Không có adapter nào match (chỉ với `--detect`) |

---

## 4. Cấu trúc file

```
adapters/
├── README.md                  # File này
├── _dispatcher.sh             # Entry point CLI
├── stack/
│   ├── node.sh                # package.json
│   ├── dotnet.sh              # *.csproj, *.sln
│   ├── java.sh                # pom.xml, build.gradle
│   ├── python.sh              # requirements.txt, pyproject.toml
│   └── go.sh                  # go.mod
├── package-manager/
│   ├── npm.sh                 # package-lock.json | yarn.lock | pnpm-lock.yaml
│   ├── pip.sh                 # requirements.txt | poetry.lock
│   ├── nuget.sh               # packages.lock.json | *.csproj <PackageReference>
│   ├── maven.sh               # pom.xml
│   └── go-mod.sh              # go.sum
├── orm/
│   ├── prisma.sh              # prisma/schema.prisma
│   ├── ef-core.sh             # *.csproj có PackageReference EntityFrameworkCore
│   ├── sqlalchemy.sh          # import sqlalchemy trong .py
│   ├── hibernate.sh           # hibernate.cfg.xml | persistence.xml
│   ├── typeorm.sh             # ormconfig.* | @Entity decorators
│   └── sequelize.sh           # sequelize/models | sequelize-cli config
└── tests/
    ├── conftest.py            # sys.path setup + helper fixtures
    └── test_dispatcher_smoke.py  # Smoke test: mỗi adapter có detect()/scan()
```

Tổng: **17 file** (1 README + 1 dispatcher + 5 stack + 5 PM + 6 ORM + 2 test).

---

## 5. Quy tắc design

### 5.1. Adapter là Bash, dispatcher là Bash

Cross-platform: chạy được trên Linux, macOS, Windows (Git Bash/WSL). Không phụ thuộc Python để keep dispatcher light. Logic phức tạp (parsing AST, query DB) sẽ delegate sang script Python riêng khi cần (ví dụ `parse-csproj.py`).

### 5.2. Adapter idempotent + side-effect-free khi detect

`detect()` chỉ đọc file, không modify. `scan()` được phép tạo cache nhưng phải dưới `.mc-data/cache/wf-fix-bugs/adapters/`.

### 5.3. Graceful degradation

Adapter có thể require external tool (ví dụ `pip-audit`, `dotnet`, `mvn`). Nếu tool absent, adapter PHẢI:
- Return non-zero từ `scan()` với error message rõ trên stderr
- KHÔNG crash dispatcher
- Ghi WARNING line vào stdout: `{"warning": "tool X not installed, skipping adapter Y"}`

### 5.4. Naming

- File adapter: `kebab-case.sh` (CORE-016/017)
- Adapter ID = `<category>/<name-without-ext>` (ví dụ `stack/node`, `orm/ef-core`)
- Không suffix `_adapter` hay `-adapter`

---

## 6. Testing

### 6.1. Smoke test (B0)

`tests/test_dispatcher_smoke.py` verify:

1. `_dispatcher.sh` invokable, exit 0 với `--list-adapters`
2. List đúng số lượng (5 stack + 5 PM + 6 ORM = 16 adapters)
3. Mỗi adapter file tồn tại + có `detect()` + `scan()` callable
4. Detect trên empty dir → return 1 cho tất cả
5. Detect trên path không tồn tại → exit 2

### 6.2. Real fixture tests (Stage 3 IMP-001/003/010)

Khi implement đầy đủ, mỗi adapter có fixture trong `fixtures/qd<N>-test/positive/case-<adapter>/`:

- 1 project mẫu cho stack/PM/ORM đó
- Expected output JSON Lines
- Assertion script

---

## 7. Cross-skill contract

### 7.1. Probe gọi adapter

Probe shell script (`.claude/scripts/wf-fix-probe-*.sh`) gọi dispatcher:

```bash
# Trong probe
ADAPTERS_DIR="${MCV3_SHARED_ADAPTERS:-.claude/skills/workflow/_shared/adapters}"
matched_adapters=$(bash "$ADAPTERS_DIR/_dispatcher.sh" --detect "$PROJECT_PATH")

while IFS= read -r adapter_id; do
    bash "$ADAPTERS_DIR/$adapter_id.sh" scan "$PROJECT_PATH" >> "$OUTPUT_FILE"
done <<< "$matched_adapters"
```

### 7.2. Adapter KHÔNG ghi registry

Adapter chỉ emit JSON Lines. Probe (caller) chịu trách nhiệm normalize → Signal → ghi `issue-registry.json` qua `signal_bus/`.

---

## 8. Versioning

Skeleton này = `v0.0.1-skeleton`. Khi IMP-001 done → bump `v0.1.0` (route detection live). Khi IMP-003 done → `v0.2.0`. Khi IMP-010 done → `v1.0.0` (GA, multi-ORM live).

---

## 9. Tham chiếu

- IMP-000 spec: [`plans/wf-fix-bugs-dimensions-audit-v1/10-improvement-roadmap.md §IMP-000`](../../../../../plans/wf-fix-bugs-dimensions-audit-v1/10-improvement-roadmap.md)
- DEC-001: [`plans/wf-fix-bugs-dimensions-audit-v1/12-decisions-log.md`](../../../../../plans/wf-fix-bugs-dimensions-audit-v1/12-decisions-log.md)
- _shared convention: [`_shared/README.md`](../README.md) §4 (Quy tắc chung)
- Cross-cutting Theme 1: [`plans/wf-fix-bugs-dimensions-audit-v1/09-cross-cutting-findings.md`](../../../../../plans/wf-fix-bugs-dimensions-audit-v1/09-cross-cutting-findings.md)
