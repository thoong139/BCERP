# Phase 1: Gap Analysis & Migration Strategy

> Phan tich su khac biet giua module cu (tu scan docs + CI code analysis) va he thong moi (EUREKA).
> De xuat chien luoc cho tung feature. CDG — user duyet truoc khi tiep tuc (hoac auto-approve skip).
> Day la phase QUAN TRONG NHAT — chat luong dau ra phu thuoc vao quyet dinh o day.

> **Shared:** Xem `procedures/_shared.md` — CDG, Auto-Approve Mode, CI-ROUTE, State Variables, Registry Safe-Write.

---

## PRE-GATE

```bash
test -f $SESSION_DIR/migrate-status.json
test -f $SESSION_DIR/preflight-results.json
test -f $SCAN_SESSION_DIR/target-map.json
test -f $SCAN_SESSION_DIR/feature-inventory.md
jq -e '.status == "in_progress"' $SESSION_DIR/migrate-status.json
```

---

## INPUT

| File | Duong dan | Mo ta |
|------|-----------|-------|
| Target map | `$SCAN_SESSION_DIR/target-map.json` | Machine-readable metadata cua module cu |
| Feature inventory | `$SCAN_SESSION_DIR/feature-inventory.md` | Danh sach tinh nang, CRUD ops, business rules cu |
| Module map | `$SCAN_SESSION_DIR/module-map.md` | Ban do cau truc module cu |
| CI Capabilities | `$CI_CAPABILITIES` | GitNexus/Serena available flags |
| Registry | `.mc-data/docs/_meta/req-registry.json` | Trang thai hien tai cua EUREKA |
| User prompt | `$USER_PROMPT` | Yeu cau cua ban |
| Target context | `$TARGET_SYSTEM`, `$TARGET_MODULE` | Dich den trong EUREKA |
| Auto-approve | `$AUTO_APPROVE` | Skip CDG neu true |
| Legacy decisions | `.mc-data/work/wf-brainstorm/legacy-decisions.json` | Neu LEGACY_MODE |

---

## OUTPUT

| File | Template | Mo ta |
|------|----------|-------|
| `$SESSION_DIR/gap-analysis.md` | `templates/gap-analysis.md` | Ket qua phan tich gap — cu co gi, moi thieu gi, khac biet gi |
| `$SESSION_DIR/strategy-matrix.md` | `templates/strategy-matrix.md` | Ma tran quyet dinh: moi feature → Keep/Redesign/Deprecate/Merge |
| `$SESSION_DIR/entity-mapping.md` | `templates/entity-mapping.md` | Bang anh xa entity cu → entity moi |

---

## Steps

### Step 1.1 — Trich xuat danh sach feature tu scan docs

Doc `target-map.json` + `feature-inventory.md` → trich xuat danh sach feature day du:

- Ten feature (tu scan docs)
- Loai (CRUD / business rule / validation / integration / UI)
- API endpoints lien quan (tu target-map.json)
- Entities lien quan (tu target-map.json)
- Business rules (tu feature-inventory.md)

Output: `$SOURCE_FEATURES[]` — array cac feature object.

### Step 1.1a — CI Code Analysis (NEW — v1.1)

**Truoc khi spawn agents**, enrich context bang code intelligence:

```
1. NEU $GITNEXUS_AVAILABLE:
   a. gitnexus_query({
        query: "$TARGET_MODULE functionality in EUREKA",
        task_context: "migrating from legacy to EUREKA ERP",
        goal: "find existing code related to $TARGET_MODULE for gap analysis"
      })
   b. gitnexus_impact({
        target: "$TARGET_MODULE handlers",
        direction: "downstream"
      })
   → Set $CI_SOURCE_ANALYSIS = {existing_processes: [...], affected_modules: [...]}

2. NEU $SERENA_AVAILABLE:
   a. find_symbol({name_path_pattern: "$TARGET_MODULE", relative_path: "apps/backend/"})
   b. Neu tim thay → find_referencing_symbols cho tung symbol quan trong
   → Set $CI_EXISTING_SYMBOLS = [...]

3. NEU CI NOT AVAILABLE → fallback:
   - Grep "$TARGET_MODULE" trong apps/backend/**/*.cs
   - Glob "**/$TARGET_MODULE*" trong apps/backend/
   → WARNING: "CI khong available — gap analysis dua tren scan docs + grep results"
```

Output `$CI_SOURCE_ANALYSIS` + `$CI_EXISTING_SYMBOLS` duoc feed vao agent prompts o Step 1.2.

### Step 1.2 — Spawn agents phan tich gap (PARALLEL)

**Agent 1: business-analyst** — Phan tich tu goc do nghiep vu:

```
Prompt: "Doc feature inventory cua module cu tai $SCAN_SESSION_DIR/feature-inventory.md.
Module cu: [ten module tu scan docs].
He thong moi: EUREKA ERP, target system=$TARGET_SYSTEM, target module=$TARGET_MODULE.

{NEU $CI_SOURCE_ANALYSIS co du lieu: 'Code EUREKA hien co lien quan: ' + $CI_SOURCE_ANALYSIS}

Phan tich:
1. Voi moi feature trong module cu, danh gia: feature nay co can thiet cho he thong moi khong?
2. Logic nghiep vu cu co con phu hop khong? Co can thay doi gi khong?
3. Co feature nao bi trung lap voi tinh nang da co trong EUREKA khong? (Dua tren CI analysis)
4. Co feature nao nen bo (deprecate) vi khong con phu hop?

Output: danh sach feature + khuyen nghi strategy + rationale (tieng Viet)."
```

**Agent 2: architect** — Phan tich tu goc do ky thuat:

```
Prompt: "Doc target-map.json va module-map.md cua module cu tai $SCAN_SESSION_DIR/.
Module cu: [ten module tu scan docs].
He thong moi: EUREKA ERP (.NET 10 Minimal API + DDD + CQRS), target system=$TARGET_SYSTEM, target module=$TARGET_MODULE.

{NEU $CI_EXISTING_SYMBOLS co du lieu: 'Symbols EUREKA hien co: ' + $CI_EXISTING_SYMBOLS}

Phan tich:
1. Entity cua module cu: anh xa sang entity moi nhu the nao?
   - Entity nao map 1-1?
   - Entity nao can tap lai (split/merge)?
   - Entity nao da co san trong EUREKA? (Dua tren CI symbol search)
2. API endpoints: endpoint cu nao can giu, endpoint nao can thay doi de phu hop pattern EUREKA?
3. Business rules: rule nao implement lai y nguyen, rule nao can refactor?
4. Dependencies: module cu phu thuoc vao nhung gi? Thu vien, external service, module khac?

Output: danh sach entity mapping + khuyen nghi ky thuat (tieng Viet)."
```

> **PARALLEL:** 2 agents chay dong thoi — doc lap, khong conflict.

### Step 1.3 — Tong hop ket qua

Doc ket qua tu ca 2 agents → tong hop:

1. **Gap analysis** — viet `$SESSION_DIR/gap-analysis.md`:
   - Module cu co gi (tong quan)
   - Module moi da co gi (tu registry + CI analysis)
   - Gap: thieu gi, khac biet gi, trung lap gi

2. **Strategy matrix** — viet `$SESSION_DIR/strategy-matrix.md`:
   - Moi feature: Keep / Redesign / Deprecate / Merge + rationale

3. **Entity mapping** — viet `$SESSION_DIR/entity-mapping.md`:
   - Moi entity cu → entity moi (hoac null neu deprecate)
   - Field-level mapping neu khac biet

### Step 1.4 — CDG-1: Strategy Confirmation

**NEU `$AUTO_APPROVE == true`:**
- Skip CDG-1. Dung AI-suggested strategy.
- Ghi log: `"CDG-1: AUTO-APPROVED — [N] features, strategy: Keep=[K], Redesign=[R], Deprecate=[D], Merge=[M]"`

**NEU `$AUTO_APPROVE == false`:** Hien thi tom tat strategy matrix → **AskUserQuestion CDG-1** (xem `_shared.md` §CDG-1).

User co the:
- Dong y het → tiep tuc
- Xem chi tiet → hien thi strategy-matrix.md
- Chinh sua → update strategy-matrix.md theo y user

### Step 1.5 — CDG-2: Entity Mapping Confirmation

**NEU `$AUTO_APPROVE == true`:**
- Skip CDG-2. Dung AI-suggested entity mapping.
- Ghi log: `"CDG-2: AUTO-APPROVED — [N] entities mapped."`

**NEU `$AUTO_APPROVE == false`:** Hien thi tom tat entity mapping → **AskUserQuestion CDG-2** (xem `_shared.md` §CDG-2).

### Step 1.6 — CDG-3: Scope Confirmation

**NEU `$AUTO_APPROVE == true`:**
- Skip CDG-3. Dung AI-suggested scope.
- Ghi log: `"CDG-3: AUTO-APPROVED — [N] features in scope."`

**NEU `$AUTO_APPROVE == false`:** Hien thi tom tat pham vi migration → **AskUserQuestion CDG-3** (xem `_shared.md` §CDG-3).

### Step 1.7 — Cap nhat status + checkpoint

Cap nhat `migrate-status.json` (current_phase="gap-analysis", status="in_progress").
Luu checkpoint (next_phase="phase2", cdg_decisions ghi nhan auto-approve status).

### Step 1.8 — Dry-Run Exit (NEW v1.1)

**NEU `$DRY_RUN == true`:**

Hien thi Dry-Run Preview theo `_shared.md` §Dry-Run Protocol:

```
## Dry-Run Preview — /wf-migrate-module

| Muc | Gia tri |
|-----|---------|
| Module cu | {SOURCE_MODULE} |
| Module moi | {TARGET_MODULE} |
| Tong features | {N} |
| Keep | {K} |
| Redesign | {R} |
| Deprecate | {D} |
| Merge | {M} |

**Se duoc goi:**
- /wf-add-scope --from-scan={SCAN_SESSION_ID} (Phase 2)
- /wf-define-features --from-scan={SCAN_SESSION_ID} (Phase 3)
- /wf-design --from-scan={SCAN_SESSION_ID} (Phase 4)
- /wf-plan-modules --module={TARGET_MODULE} (Phase 5)
- /wf-implement-feature --task=... (Phase 6 — {N} tasks)
```

Sau do: ghi CORE-026 COMPLETE trace → **STOP**.

KHONG ghi registry. KHONG goi sub-skill. KHONG chuyen sang Phase 2.

**NEU `$DRY_RUN == false`:** Tiep tuc binh thuong sang Phase 2.

---

## POST-GATE

**Strategy Completeness Gate:**
- Moi feature trong `$SOURCE_FEATURES` deu co strategy (Keep/Redesign/Deprecate/Merge)
- Moi strategy deu co rationale
- KHONG co feature nao "unassigned"

**Data Mapping Gate:**
- Moi entity trong scan docs duoc map sang entity moi HOAC co rationale "khong map"
- Moi field khong map 1-1 deu co giai thich

```bash
# Content validation
test -s $SESSION_DIR/gap-analysis.md
test -s $SESSION_DIR/strategy-matrix.md
test -s $SESSION_DIR/entity-mapping.md
# Strategy completeness
grep -c "unassigned" $SESSION_DIR/strategy-matrix.md | grep -q "^0$"
```

---

## Next Phase

→ `procedures/phase2-add-scope.md`
