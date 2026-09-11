# PRE-GATE — wf-fix-data (QD6 Lane)

> **Reference:** `_shared/lane/pre-gate.md` (steps 1-7 chuẩn cho mọi lane)
> **Schema:** `_shared/lane/_shared.md` §5 (lane-status-v1)
> **Phiên bản:** v1.0 (S4 wf-fix-bugs v7.0)

---

## Lane-Specific Variables

```bash
LANE_NAME="wf-fix-data"
DIMENSION="QD6"
LANE_DIR="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data"
```

## Steps Chuẩn (1-7)

Đọc và thực hiện đầy đủ theo `_shared/lane/pre-gate.md`:

1. Verify orchestrator handoff (`SESSION_DIR`, `fix-status.json`)
2. Verify input data (registry + source dirs)
3. Verify dimension scope (QD6 trong dimensions_resolved)
4. Resolve profile → probe subset (Pattern A inline, xem `_shared/lane/profile-resolver.md` §QD6)
5. Initialize lane working dir
6. Init `lane-status.json` từ shared template
7. Init `signals.json` từ shared template

## QD6-Specific Extension Steps

### Step 8 — Verify migration/schema files exist

```bash
# Detect migration directory pattern
MIGRATIONS_DIR=""
for dir in "migrations" "db/migrations" "prisma/migrations" "alembic/versions" "src/migrations"; do
  if [ -d "$dir" ]; then
    MIGRATIONS_DIR="$dir"
    break
  fi
done

if [ -z "$MIGRATIONS_DIR" ]; then
  echo "INFO: Khong tim thay migration directory — P-QD6-migration-integrity + P-QD6-schema-drift-detect se skip" >&2
fi

# Detect ORM model files
ORM_FILES_FOUND=$(find . -type f \( -name "*.entity.ts" -o -name "models.py" -o -name "schema.prisma" -o -name "*.model.ts" \) 2>/dev/null | head -1)
if [ -z "$ORM_FILES_FOUND" ]; then
  echo "INFO: Khong tim thay ORM model files — P-QD6-orm-model-sync se skip" >&2
fi
```

### Step 9 — Verify --base-url cho runtime probes

```bash
if [ -z "${BASE_URL:-}" ]; then
  echo "INFO: BASE_URL khong set, runtime probes (P-QD6-constraint-violation) se skip" >&2
fi
```

### Step 10 — Resolve probe list theo profile (QD6)

```bash
case "$PROFILE" in
  quick)
    PROBES=("P-QD6-orm-model-sync" "P-QD6-data-type-mismatch")
    ;;
  standard)
    PROBES=("P-QD6-orm-model-sync" "P-QD6-data-type-mismatch"
            "P-QD6-schema-drift-detect" "P-QD6-migration-integrity")
    ;;
  deep)
    PROBES=("P-QD6-orm-model-sync" "P-QD6-data-type-mismatch"
            "P-QD6-schema-drift-detect" "P-QD6-migration-integrity"
            "P-QD6-constraint-violation")
    ;;
  exhaustive)
    PROBES=("P-QD6-orm-model-sync" "P-QD6-data-type-mismatch"
            "P-QD6-schema-drift-detect" "P-QD6-migration-integrity"
            "P-QD6-constraint-violation" "P-QD6-seed-data-audit")
    ;;
esac
```

## PRE-GATE Failure Handling

Theo `_shared/lane/pre-gate.md` §"PRE-GATE Failure Handling".

## Resume Behavior

Theo `_shared/lane/pre-gate.md` §"Resume Behavior".
