<!--
_template_notes:
  purpose: Hướng dẫn tạo test fixtures cho evals — match với 09-evals-test-cases.md.
  populate:
    - §1 Cấu trúc folder fixtures chuẩn
    - §2 3 fixture mẫu (minimal, realistic, corrupt)
    - §3 Quy tắc đặt tên + version fixture
    - §4 Helper script generate fixture từ real project
  Áp dụng: MỌI skill có evals (≥1 test case)
  độ dài: 100-200 dòng
  Khi dùng file này, KHÔNG cần đổi tên — copy nội dung sang README của tests/fixtures/{skill-name}/
-->

# Eval Fixtures — Sample Structure

> **Mục đích file:** Hướng dẫn tạo test fixtures cho `evals/evals.json`. Đảm bảo evals có dữ liệu reproducible.

---

## 1. Cấu trúc folder fixtures chuẩn

```
tests/fixtures/{skill-name}/
├── README.md                          ← Mô tả từng fixture
├── minimal/                           ← Cho TC-001 smoke
│   ├── .mc-data/
│   │   └── docs/_meta/req-registry.json
│   └── src/
│       └── {minimal-source-files}
├── realistic/                         ← Cho TC-002 integration
│   ├── .mc-data/
│   │   ├── docs/_meta/req-registry.json
│   │   ├── docs/phase2-features/sales/customers/manage-customers.md
│   │   └── work/wf-preflight/sessions/.../preflight-report.json
│   └── src/                           ← realistic codebase ~20-50 files
├── corrupt/                           ← Cho TC-003 edge (error injection)
│   ├── README.md                      ← Mô tả corruption type
│   └── .mc-data/
│       └── docs/_meta/req-registry.json    ← Invalid JSON / missing fields
└── concurrent/                        ← Cho TC-005 lock conflict
    └── lock.simulation.json
```

---

## 2. Sample fixtures detail

### 2.1 Minimal (smoke test)

**Mục đích:** Verify skill chạy được với dataset NHỎ NHẤT possible.

**Files cần có:**
```json
// tests/fixtures/{skill-name}/minimal/.mc-data/docs/_meta/req-registry.json
{
  "$schema": "req-registry-v2",
  "project": "test-minimal",
  "departments": ["sales"],
  "interface_type": "web",
  "systems": ["crm"],
  "modules": [{"id": "customers", "system": "crm", "department": "sales"}],
  "requirements": [
    {
      "id": "REQ-SALES-001",
      "department": "sales",
      "module": "customers",
      "title": "Quản lý khách hàng",
      "priority": "must-have",
      "impl_status": "not_started"
    }
  ],
  "features": []
}
```

**Pass criteria:**
- Skill chạy <30s
- Output đúng schema
- Không error

### 2.2 Realistic (integration test)

**Mục đích:** Verify skill xử lý project realistic (3-5 modules, 20-50 REQs, có cross-module).

**Source:** Có thể derive từ `tools/scenarios/scenarios/{A-H}/.mc-data/` (Phase 5 integration test fixtures).

**Files cần có:**
```
realistic/
├── .mc-data/
│   ├── docs/_meta/req-registry.json    ← 30-50 requirements
│   ├── docs/phase1-business/...
│   ├── docs/phase2-features/...
│   ├── docs/phase3-architecture/...
│   └── work/_meta/code-intelligence.json   ← CI cache (optional)
└── src/                                 ← Realistic codebase
```

### 2.3 Corrupt (edge test — error injection)

**Mục đích:** Verify skill ESCALATE đúng khi gặp data invalid.

**Variations:**

| Fixture | Corruption type | Expected error |
|---------|----------------|---------------|
| `corrupt/empty-registry/` | `requirements: []` | E012 (registry empty) |
| `corrupt/invalid-json/` | Trailing comma | E011 (JSON parse fail) |
| `corrupt/missing-field/` | No `$schema` | E011 (schema invalid) |
| `corrupt/cross-ref-drift/` | Phase 2 ref REQ không có trong registry | E013 (drift) |

**README cho mỗi variation:**
```markdown
# Corruption: empty-registry

**Type:** Registry has `requirements: []`
**Expected detection:** PRE-GATE Phase 1 T3 fail
**Expected error code:** E012
**Expected behavior:** Skill ESCALATE, không advance Phase 2
```

---

## 3. Quy tắc đặt tên + versioning fixture

| Quy tắc | Detail |
|---------|--------|
| Tên folder | `lowercase-kebab-case`, mô tả ngắn (2-3 từ) |
| Version | Fixture có `_version` field trong README, bump khi schema change |
| Schema sync | Khi `req-registry-v2` → `v3`: regenerate ALL fixtures, bump version |
| Size | Minimal <50KB, Realistic <500KB, Corrupt <10KB |
| Git LFS | KHÔNG dùng — fixtures phải plain text để diff được |

---

## 4. Helper script — generate fixture

### Generate từ real project

```bash
#!/bin/bash
# tools/generate-fixture-from-project.sh
# Usage: ./generate-fixture-from-project.sh <source-project> <fixture-name>

SOURCE="$1"
NAME="$2"
DEST="tests/fixtures/{skill-name}/$NAME"

mkdir -p "$DEST/.mc-data/docs/_meta"

# Anonymize: thay tên company/dự án thật bằng generic names
jq '
  .project = "test-fixture" |
  .departments |= map(. as $d | $d) |
  .requirements |= map(.title = "Anonymized title \(.id)")
' "$SOURCE/.mc-data/docs/_meta/req-registry.json" > "$DEST/.mc-data/docs/_meta/req-registry.json"

# Copy structure (không copy source code thật)
echo "Fixture generated at $DEST"
```

### Generate corrupt variant

```bash
#!/bin/bash
# tools/generate-corrupt-fixture.sh
# Usage: ./generate-corrupt-fixture.sh <variation-name> <corruption-type>

NAME="$1"
TYPE="$2"  # empty-registry | invalid-json | missing-field | cross-ref-drift
BASE="tests/fixtures/{skill-name}/minimal/.mc-data/docs/_meta/req-registry.json"
DEST_DIR="tests/fixtures/{skill-name}/corrupt/$NAME"

mkdir -p "$DEST_DIR/.mc-data/docs/_meta"

case "$TYPE" in
  empty-registry)
    jq '.requirements = [] | .features = []' "$BASE" > "$DEST_DIR/.mc-data/docs/_meta/req-registry.json"
    ;;
  invalid-json)
    cat "$BASE" | sed 's/}$/},,/' > "$DEST_DIR/.mc-data/docs/_meta/req-registry.json"
    ;;
  missing-field)
    jq 'del(."$schema")' "$BASE" > "$DEST_DIR/.mc-data/docs/_meta/req-registry.json"
    ;;
  cross-ref-drift)
    jq '.requirements[0].id = "REQ-SALES-XXX"' "$BASE" > "$DEST_DIR/.mc-data/docs/_meta/req-registry.json"
    # Phase 2 docs vẫn ref REQ-SALES-001 (drift)
    ;;
esac

cat > "$DEST_DIR/README.md" <<EOF
# Corruption: $NAME

**Type:** $TYPE
**Generated at:** $(date -Iseconds)
EOF
```

---

## 5. Liên kết

- Eval test cases: [`09-evals-test-cases.md`](09-evals-test-cases.md)
- Phase 5 integration fixtures (reference): [`../../../tools/scenarios/`](../../../tools/scenarios/)
- Eval execution script: [`../../../.claude/scripts/audit/run-skill-evals.sh`](../../../.claude/scripts/audit/)
- Schema doc: [`../../02-standards/04-contract-schema.md`](../../02-standards/04-contract-schema.md)
