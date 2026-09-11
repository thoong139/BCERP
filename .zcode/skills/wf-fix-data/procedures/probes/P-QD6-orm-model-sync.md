# P-QD6-orm-model-sync — Kiem tra ORM model sync giua cac entities

| Thuoc tinh | Gia tri |
|-----------|---------|
| **Probe ID** | P-QD6-orm-model-sync |
| **Loai** | static |
| **Profile** | standard, deep, exhaustive |
| **Muc dich** | Kiem tra ORM model files co dong bo voi nhau khong: relations co du 2 chieu khong, cascade behavior co explicit khong, default values co khop khong, index definitions co khop voi migration khong. |
| **Cache** | allowed |
| **Migrates from** | (new in v7) |

## SENSE

### B1: Delegate to bash script

```bash
RAW_OUT="$SESSION_DIR/phase4-find-bugs/lanes/QD6-data/raw/P-QD6-orm-model-sync.json"
mkdir -p "$(dirname "$RAW_OUT")"

if ! bash .claude/scripts/wf-fix-probe-static-data.sh \
      --session-dir "$SESSION_DIR" \
      --lane wf-fix-data \
      --probe P-QD6-orm-model-sync \
      --profile "$PROFILE" \
      --source-dir "${SOURCE_DIR:-src/}" \
      > "$RAW_OUT" 2>"$RAW_OUT.err"; then
  echo "WARNING: bash script failed, see $RAW_OUT.err" >&2
  cat > "$RAW_OUT" <<EOF
{"$schema":"lane-signals-v1","lane":"wf-fix-data","dimension":"QD6",
 "probe_id":"P-QD6-orm-model-sync","profile":"$PROFILE",
 "generated_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","signals":[],
 "skip_reason":"bash_script_failed"}
EOF
fi
```

**Bash script handles:**
- Phat hien tech stack: Prisma / TypeORM / EF Core / Drizzle
- Parse all model/entity files trong project
- Xay dung relation graph giua cac models
- So sanh relation definitions (1 chieu, 2 chieu, cascade, onDelete)
- So sanh default values va index definitions

### B2: Scan Cache check (khi --use-cache)

```bash
if [ "${USE_CACHE:-0}" -eq 1 ]; then
  python -m _shared.scan_cache.cache_lookup \
    --cache-root .mc-data/cache/wf-fix-bugs/probes/ \
    --probe-id P-QD6-orm-model-sync --probe-version 1.0.0 \
    >> "$RAW_OUT.cache" 2>/dev/null || true
fi
```

### B3: CI Enrichment (BAT BUOC khi GITNEXUS/SERENA available)

> **Muc dich:** Voi `missing_relation_side`, `cascade_mismatch` — can biet bao nhieu code dang dung relation do truoc khi sua. Tools: Serena `find_referencing_symbols` cho navigation property, GitNexus `impact` cho cascade impact.

```bash
if [[ "$GITNEXUS_AVAILABLE" == "true" || "$SERENA_AVAILABLE" == "true" ]]; then
  # Pseudocode:
  # FOR each signal trong $RAW_OUT.signals[] (top 30 theo severity):
  #   entity_a = signal.evidence.entity_a  # vd: User
  #   entity_b = signal.evidence.entity_b  # vd: Post
  #   relation_field = signal.evidence.relation_field  # vd: posts hoac author
  #   
  #   IF SERENA_AVAILABLE:
  #     # Tim noi dung relation property
  #     refs_a = mcp__serena__find_referencing_symbols(name_path=f"{entity_a}.{relation_field}", relative_path=signal.target.file_path)
  #     signal.evidence.serena_refs_a_count = len(refs_a)
  #   
  #   IF GITNEXUS_AVAILABLE:
  #     # Cascade impact: neu cascade_mismatch + hard_delete dung sai → blast radius cao
  #     IF signal.signal_type == "cascade_mismatch":
  #       impact = mcp__plugin_gitnexus_gitnexus__impact(target=entity_a, direction="upstream")
  #       signal.evidence.gitnexus_callers = impact.direct_callers_count
  #       IF impact.risk_level == "CRITICAL":
  #         signal.cdg_flag = "CDG-SCHEMA-BREAK"
  #         signal.suggested_severity = "critical"
  #   
  #   signal.evidence.ci_meta = {gitnexus_used, serena_used, freshness_level, behind_commits}
fi
```

**Graceful:** CI absent → skip B3, signals giu nguyen tu B1.

## THINK

Bash script implement logic sau:

1. **Bi-directional relation validation:**
   - Prisma: Kiem tra @relation references co tuong ung o 2 phia khong
     - `User.posts Post[]` <-> `Post.author User @relation(fields: [authorId], references: [id])`
     - Neu 1 phia thieu -> emit `missing_relation_side` (severity=critical)
   - TypeORM: Kiem tra @ManyToOne co @OneToMany tuong ung khong
     - `@ManyToOne(() => User)` <-> `@OneToMany(() => Post, post => post.user)`
     - Neu 1 phia thieu -> emit `missing_relation_side` (severity=critical)
   - EF Core: Kiem tra .HasOne().WithMany() pairs dung reference
     - `.HasOne(x => x.Author).WithMany(x => x.Posts)` -> OK
     - `.HasOne(x => x.Author).WithMany()` -> canh bao (missing nav property)

2. **Cascade behavior consistency:**
   - Prisma: Kiem tra `onDelete: Cascade | SetNull | Restrict | NoAction` dong nhat
   - TypeORM: Kiem tra `@ManyToOne(() => User, { onDelete: 'CASCADE' })`
   - EF Core: Kiem tra `.OnDelete(DeleteBehavior.Cascade | Restrict | SetNull)`
   - Phat hien: Cascade behavior khac nhau giua 2 phia cua relation
   - Phat hien: Cascade behavior khong explicit (dung default)
   - Emit `cascade_mismatch` (severity=high) khi khong dong nhat
   - Emit `cascade_not_explicit` (severity=medium) khi implicit

3. **Default value consistency:**
   - Prisma: @default(now()) vs migration DEFAULT CURRENT_TIMESTAMP -> OK
   - Kiem tra default values giua ORM model va migration co khop khong
   - Phat hien: ORM co default nhung migration khong -> emit `default_mismatch`
   - Phat hien: migration co default nhung ORM khong -> emit `default_mismatch`
   - Chu y: Prisma `@default(uuid())` vs DB `gen_random_uuid()` -> function names khac nhung tuong thich

4. **Index definition sync:**
   - Prisma: So sanh `@@index([field1, field2])` voi migration CREATE INDEX statements
   - TypeORM: So sanh `@Index()` decorators voi migration indexes
   - EF Core: So sanh `.HasIndex()` configurations voi migration
   - Phat hien: Index trong ORM nhung khong co trong migration -> emit `index_missing_in_db`
   - Phat hien: Index trong migration nhung khong co trong ORM -> emit `index_missing_in_code`
   - Kiem tra index properties: unique, where clause (partial index), include columns (covering index)

5. **Model reference validation:**
   - Kiem tra relation target model co ton tai khong
   - Prisma: `Post User @relation(...)` -> User model phai ton tai trong schema.prisma
   - TypeORM: `@ManyToOne(() => User)` -> User entity class phai ton tai va duoc import
   - Emit `invalid_relation_target` (severity=critical) neu tham chieu khong ton tai

6. **Profile-based depth:**
   - standard: Chi kiem tra bi-directional relations + cascade consistency
   - deep: Bo sung default value sync + index definition sync
   - exhaustive: Bo sung kiem tra relation field type matching (VD: String ID vs Int ID)

7. **Dedup:** fingerprint = sha256(QD6|model1|model2|relation_field|probe_id|sync_type)

## ACT

Bash script output signals theo schema signal-v2 voi:
- dimension_id: QD6, probe_id: P-QD6-orm-model-sync
- signal_type: missing_relation_side | cascade_mismatch | cascade_not_explicit | default_mismatch | index_missing_in_db | index_missing_in_code | invalid_relation_target
- severity theo Severity Rules
- evidence[] voi file path + line cua ca 2 models (neu co), code excerpt
- remediation.suggested_action: goi y them field, sua cascade, dong bo index

Sau do SKILL.md emit signals vao signals.json:

```bash
jq -c '.signals[]' "$RAW_OUT" | while read -r sig; do
  emit_signal_from_json "$LANE_DIR" "$sig"
done
```

## VERIFY

1. Kiem tra missing_relation_side signals co chi ro ca 2 model files
2. Kiem tra cascade_mismatch signals co chi ro behavior khac nhau
3. Kiem tra invalid_relation_target signals co model name thuc su ton tai trong codebase
4. Kiem tra khong co false positives cho:
   - Uni-directional relationships (intentional, VD: reference to external system)
   - Soft delete relation (User.deletedBy -> Admin, 1 chieu la intentional)
   - Polymorphic relations (comments on table)
5. Moi severity dung voi Severity Rules

## Severity Rules

| Dieu kien | Severity |
|-----------|----------|
| Relation target model khong ton tai | CRITICAL |
| Relation chi co 1 chieu (missing inverse side) | HIGH |
| Cascade behavior khac nhau giua 2 phia relation | HIGH |
| Cascade behavior khong explicit (dung default) | MEDIUM |
| Default value khac nhau giua ORM va migration | MEDIUM |
| Index co trong ORM nhung thieu trong migration | HIGH |
| Index co trong migration nhung thieu trong ORM | MEDIUM |

## Fallback

| Tinh huong | Hanh vi |
|------------|---------|
| Khong tim thay ORM model files | Skip probe, note "no_model_files" |
| Chi co 1 model file (single-model project) | Skip relation checks, note "single_model_project" |
| Relation target o file khac (cross-file) | Van co the kiem tra, note "cross_file_relations" |
| Unsupported tech stack (raw SQL) | Skip probe, note "unsupported_stack" |
| Parse error trong 1 model file | Bo qua file do, tiep tuc cac file khac, log WARNING |
| Scan Cache corrupt | Fallback: scan thuong, log WARNING |
