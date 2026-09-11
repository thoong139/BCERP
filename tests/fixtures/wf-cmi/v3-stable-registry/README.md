# Fixture: `v3-stable-registry/` — TC-cmi-018

> **Mục đích:** Stable-registry hit test — 10 scenarios MỚI sinh từ CD41, 7 scenarios hash khớp với stable-registry session trước (TTL=15 ngày). Step 9.4 5x pre-flight SKIP 7 scenarios → time saved ~5.8 min. 3 scenarios NEW chạy 5x: 2 stable + 1 quarantine (flaky 2/5).

---

## Cấu trúc

```
v3-stable-registry/
├── README.md                              ← Bạn đang đọc
└── .mc-data/
    ├── docs/_meta/req-registry.json       ← 3 REQ stub
    └── work/wf-cmi/sessions/
        └── 2026-05-10-system-deep-prev-01/phase9-e2e-execute/
            └── stable-registry.json       ← 7 scenarios verified TTL=15d ago
```

## Expected behavior

| Step | Action | Outcome |
|------|--------|---------|
| Phase 9.4 | Load stable-registry.json + compute scenario hash per scenario | 7 hash match (TTL valid) + 3 NEW |
| 7 stable | mark stable=true, source='stable-registry', skip_5x=true | Time saved 5.8 min |
| 3 NEW × 5x | scenario-08: 4/5 PASS → register stable / scenario-09: 5/5 PASS → register / scenario-10: 2/5 PASS → quarantine | stable: +2, quarantine: 1 |
| stable-registry APPEND | Atomic write 2 new entries | Final length: 9 (7+2) |

## Pass criteria

1. Exit code 0
2. stable-registry.json post-Step 9.4: length=9 (7 carried + 2 new stable)
3. quarantine-report.json: 1 entry (scenario-10, reason='flaky', pass_rate=0.4)
4. e2e-execution-report.md: "Pre-flight efficiency: 7/10 stable-hit, time saved 5.8 min"
5. integrity-impact.json e2e_execution_summary: stable_registry_hits=7, misses=3, quarantined=1
6. Phase9-report.md ≤15 dòng có efficiency metric
7. expires_at cho 2 entries mới = verified_at + 30 days (~2026-06-16)

## Notes

- Stable-registry path convention: shared global hoặc per-session. Fixture dùng per-session path.
- TTL 30 days là default wf-cmi v3.0 (clone wf-e2e-scenario).

## Run

```bash
./.claude/scripts/audit/run-skill-evals.sh wf-cmi --test-id=TC-cmi-018
```
