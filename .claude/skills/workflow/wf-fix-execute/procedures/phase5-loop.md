# Phase 5 LOOP: EVALUATE + FIX + DOCS + RESCAN

> Loop-back states cua state machine. Chi chay khi VERIFY_EVALUATE quyet dinh LOOP.
> Steps 5.16-5.19. Sau khi RESCAN → quay lai VERIFY_EVALUATE; khi TERMINATE → chuyen `phase5-final.md`.

**PRE-GATE:** Phase 5 SCAN completed (VERIFY_SCAN hoan thanh, chuan bi EVALUATE).

**INPUT:** `$SESSION_DIR/issue-registry.json` (co regression entries + discovered), `fix-status.json.phases.phase_5.loop_state`.

**OUTPUT:** Filtered issue fixes + delta docs sync + re-scan results.

---

## VERIFY_EVALUATE — Loop Decision (Step 5.16)

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.16 | **Evaluate verification results** (xem §Decision Tree ben duoi) | Decision made |

**Tinh toan truoc khi quyet dinh:**
```bash
$CRITICAL_REMAINING = jq '[.issues[] | select(.severity=="CRITICAL" and .status != "fixed" and .status != "skipped")] | length' issue-registry.json
$HIGH_REMAINING = jq '[.issues[] | select(.severity=="HIGH" and .status != "fixed" and .status != "skipped")] | length' issue-registry.json
$NEW_REGRESSIONS = jq '[.issues[] | select(.status=="regression")] | length' issue-registry.json
$OVERRIDE_GRANTED = jq '.phases.phase_5.override_granted' fix-status.json
$ITERATION = jq '.phases.phase_5.loop_state.current_iteration' fix-status.json
```

### Decision Tree (tuan tu, dung tai buoc dau tien match)

```
(1) IF $CRITICAL_REMAINING == 0 AND $NEW_REGRESSIONS == 0:
    → PASS → VERIFY_FINAL (status=PASS)

(2) IF iteration >= 4 (absolute max, da dung override):
    → TERMINATE → VERIFY_FINAL
      (status=WARN neu HIGH>0, PASS neu CRITICAL=0, FAIL neu CRITICAL>0 + LOG E039)
    KHONG CDG them sau iter 4.

(3) IF iteration == 3 AND $CRITICAL_REMAINING > 0:
    → FAIL → LOG E039 → VERIFY_FINAL (status=FAIL)
    KHONG CDG — CRITICAL khong cho phep override.

(4) IF iteration == 3 AND $HIGH_REMAINING > 0 AND !$OVERRIDE_GRANTED:
    → CDG-EXEC-04 (CORE-027 skill-specific):
      Prompt (theo Protocol 16 §16.4 template style):
        "⚠️ Con [N] loi muc CAO chua sua duoc sau 3 vong thu.
         Ban muon cho phep AI thu them 1 vong cuoi (vong 4) khong?
         (Co/Khong)
         Luu y: Neu 'Khong' → bao cao ket qua muc CANH BAO, con [N] loi can xu ly thu cong."
      IF user "Co" → SET override_granted=true, override_reason="user CDG-EXEC-04 at iter 3: [reason]"
                    → VERIFY_FIX (iteration 4)
      IF "Khong" → VERIFY_FINAL (status=WARN)
      Log decision vao session-log.json (event: CDG_APPROVED hoac CDG_REJECTED)

(5) ELSE (iteration < 3 AND issues remain):
    → LOOP → VERIFY_FIX (fix remaining issues) → VERIFY_DOCS → VERIFY_RESCAN
    → VERIFY_RESCAN quay lai VERIFY_INIT (step 5.0a) → tang current_iteration += 1
    → re-run VERIFY_SCAN → VERIFY_EVALUATE cho iteration moi

APPEND vao phases.phase_5.loop_state.iteration_history[]:
  { iteration, issues_remaining, regressions_found, action_taken, timestamp, override_event?, scan_mode? }

> **W3.1 plan v10-speedup — `scan_mode` field:** Moi entry trong `iteration_history[]` co them field
> `scan_mode` ("full" | "delta") duoc ghi boi Step 5.1 (Smart Rescan Logic, [`phase5-scan.md`](phase5-scan.md#L52)).
> - Iter 1 va iter cuoi (>= MAX-1): luon `"full"` — cross-module regression detection critical.
> - Iter giua: `"delta"` — scope = recently_modified_files UNION cross-module dependents (GitNexus depth=1).
> - Escape hatch `MCV3_FIX_VERIFY_DELTA_DISABLED=1` → moi iter `"full"`.
```

---

## VERIFY_FIX — Route Back to Phase 3 Partial (Step 5.17)

> Chi fix remaining issues — KHONG replay toan bo Phase 3.

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.17 | **Route back to Phase 3 (PARTIAL)** (xem §Procedure ben duoi) | Remaining issues fixed |

**Procedure:**
```
1. Filter issue-registry.json:
   issues[] WHERE status IN ["discovered", "regression"]
   → day la danh sach can fix

2. Re-triage: group by severity → form new mini-batches

3. Execute fix dung Phase 3 protocol:
   - Spawn developer/security/frontend agents theo Developer Selection (_shared.md)
   - NHUNG chi cho remaining issues, khong phai full original set

3a. **Agent Output Spot-Check (CORE-029):** Run spot-check theo [Agent Output Spot-Check Protocol](_shared.md#agent-output-spot-check-protocol) TRUOC KHI UPDATE issue-registry.json. ERROR → re-spawn (max 3 retries) → escalate.

4. FOR moi fixed issue (da qua spot-check):
   UPDATE issue-registry.json:
     SET status = "fixed"
     POPULATE fix{}
     APPEND iteration_history[]: { iteration, action: "fixed", timestamp }

5. APPEND entries to fix-log.json voi `iteration = current_iteration` (da duoc VERIFY_INIT tang — VERIFY_FIX KHONG tu tang)

6. UPDATE fix-status.json:
   phases.phase_5.loop_state.state = "VERIFY_FIX"

7. Transition → VERIFY_DOCS
```

### Loop-back Internal Protocol

**REQUIRED (phai lam):**
- RELOAD issue-registry.json moi iteration (da duoc VERIFY_INIT Step 5.0 load) — de detect regression moi va track status changes across iterations
- APPEND vao fix-log.json voi field `iteration = current_iteration` (gia tri da duoc VERIFY_INIT tang tai [`phase5-scan.md`](phase5-scan.md#L41) Step 5.0a) — KHONG overwrite entries cua iteration truoc
- Filter: chi process issues WHERE `status IN ("discovered", "regression")` — skip status="fixed" va "skipped"

**FORBIDDEN (cam):**
- KHONG recreate file tu skeleton template (issue-registry.json, fix-log.json da ton tai — chi UPDATE/APPEND, khong overwrite toan bo)
- KHONG reset iteration counter ve 0 (tru khi restart Phase 5 tu dau)
- KHONG xoa entries cua iteration truoc khoi fix-log.json (cumulative log)
- KHONG re-initialize loop_state (giu nguyen current_iteration, append history)
- **KHONG tu tang `current_iteration` trong VERIFY_FIX/VERIFY_DOCS/VERIFY_RESCAN** — VERIFY_INIT la owner DUY NHAT cua increment (tranh double-increment)

**RATIONALE:** "Template immutability" = sau khi file duoc CREATE tu template o iteration 1, cac iteration tiep theo chi EDIT file do (UPDATE/APPEND) — khong recreate. "Re-read" file de lay current state luon duoc phep va can thiet.

---

## VERIFY_DOCS — Route Back to Phase 4 Delta (Step 5.18)

> Chi sync docs cho changes moi tu loop iteration hien tai.

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.18 | **Route back to Phase 4 (delta)** (xem §Procedure ben duoi) | Docs re-synced |

**Procedure:**
```
1. READ fix-log.json — chi process entries WHERE iteration == current_iteration
2. FOR moi entry WHERE behavior_changed == true:
   UPDATE feature spec tuong ung (Phase 4a protocol)
3. UPDATE fix-status.json:
   phases.phase_5.loop_state.state = "VERIFY_DOCS"
   docs_updated += [new files from loop]
4. Neu fix tao code moi → verify REQ-ID comments
5. Transition → VERIFY_RESCAN
```

---

## VERIFY_RESCAN — Re-run Full Regression (Step 5.19)

| Step | Action | Verify |
| ---- | ------ | ------ |
| 5.19 | **Re-run regression scan (smart):** Quay lai VERIFY_INIT (steps 5.0-5.0a trong [`phase5-scan.md`](phase5-scan.md)) de tang `current_iteration += 1`, sau do re-run VERIFY_SCAN (steps 5.1-5.15) — day la iteration N+1. **Scope tu dong chon boi Step 5.1 Smart Rescan Logic:** iter 1 va iter cuoi FULL scope (`$TARGET_DIRS`), iter giua DELTA scope (recently_modified UNION cross-module dependents). Goal: bat regression moi do loop fix tao ra — quality preserved vi iter cuoi LUON full (cross-module detection) + iter giua co cross-module dependents (depth=1) trong scope. UPDATE `phases.phase_5.loop_state.state = "VERIFY_RESCAN"` truoc khi quay lai VERIFY_INIT. Sau khi hoan thanh → VERIFY_EVALUATE (step 5.16). **QUAN TRONG:** (1) Increment duy nhat o VERIFY_INIT — khong tang o VERIFY_RESCAN. (2) `scan_mode` field se duoc ghi vao iteration_history[] boi Step 5.1. Escape hatch `MCV3_FIX_VERIFY_DELTA_DISABLED=1` → moi iter full scan nhu cu. | current_iteration incremented, scan_mode logged, No new regressions detected |

---

## Override Rules Summary

| Situation | Decision | CDG |
|-----------|----------|-----|
| iteration < 3, issues remain | LOOP → VERIFY_FIX | No CDG |
| iteration == 3, CRITICAL > 0 | FAIL (E039) | No CDG — CRITICAL cant override |
| iteration == 3, HIGH > 0, override != granted | **CDG CORE-027** ask user | Yes — user decide |
| iteration == 3, HIGH > 0, override granted | LOOP → iter 4 (ABSOLUTE MAX) | No more CDG after |
| iteration >= 4 | TERMINATE → VERIFY_FINAL | No CDG |

**POST-GATE:** VERIFY_RESCAN completed → back to VERIFY_EVALUATE (step 5.16) OR Decision Tree says TERMINATE → `phase5-final.md`.

**Next:**
- Loop continues → VERIFY_EVALUATE (step 5.16 in this file)
- Loop terminates → [`phase5-final.md`](phase5-final.md) (VERIFY_FINAL, step 5.20)
