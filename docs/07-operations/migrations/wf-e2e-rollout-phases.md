# wf-e2e v8.0 — Phased Rollout

## Phase 1 (Week 1-2): Foundation + Gates Cứng → v7.1.0

**Deploy:**
- wf-e2e-finding v1.0.0 (skill mới)
- wf-e2e-verify v8.0.0 F0+F0a+F0b
- F7/F8 strict (không fallback, không EVIDENCE_COMPILATION)
- --strict-evidence ON mặc định

**Beta test:** FIN-002, FIN-003

**Rollback checkpoint:** git tag v7.0-stable

---

## Phase 2 (Week 3): Logic Fix → v7.2.0

**Deploy:**
- F3 strict task generation
- F4 --max-time + P1 enforcement
- F6 per-severity anti-loop

**Verify:** 5 FEATs đa dạng

---

## Phase 3 (Week 4): Expert Dispatch → v7.3.0

**Deploy:**
- B1 Cross-Module Gap Detection
- B2 DECISION-REQUIRED Queue
- B3 Credential Vault
- --auto expert dispatch

**Verify:** 3 FEATs cross-module

---

## Phase 4 (Week 5-6): Hardening → v7.4.0

**Deploy:**
- G1 Flakiness: lint + smart retry + pre-flight + quarantine
- G2 --no-playwright degrade
- G3 Expert accuracy tracking
- G4 Context budget checkpoint
- G6 Master seed mutex

**Verify:** Batch 5 FEATs

---

## Phase 5 (Week 7): Batch + Operational → v8.0.0

**Deploy:**
- wf-e2e-batch v1.0.0
- All Tier 6 operational docs
- Integration tests O4

**Production rollout + monitoring**

---

## Phase 6 (Week 8+): Monitor + Iterate

**Metrics track:**
- Scenario PASS rate (target: >95%)
- Flaky rate (target: <5%)
- Context overflow rate (target: <5%)
- Expert decision accuracy (target: >80%)

**Version Strategy:**
- Minor bumps: v7.0→v7.1→v7.4→v8.0
- _contract.json track version
- Backward compat: v8 đọc v7 sessions với migration script
