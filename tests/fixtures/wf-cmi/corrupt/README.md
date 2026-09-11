# Fixture: `corrupt/` — TC-cmi-003 Edge (Registry Corruption)

> **Mục đích:** Kiểm tra auto-fix budget 3 retries + ESCALATE khi `req-registry.json` bị corrupt mid-Phase 3.

---

## Cấu trúc

```
corrupt/
├── README.md                              ← Bạn đang đọc
├── inject/
│   └── corrupt-trigger                    ← Hook trigger corrupt giữa Phase 2 và Phase 3
└── .mc-data/
    └── docs/
        └── _meta/
            ├── req-registry.json          ← Registry hợp lệ ban đầu (Phase 1-2 PASS)
            └── req-registry.corrupted.json ← Phiên bản đã corrupt (JSON broken)
```

## Corruption mechanism

1. Pipeline start với `req-registry.json` hợp lệ → Phase 1, Phase 2 PASS
2. Khi vào Phase 3 PRE-GATE T2 (jq parse check), test harness phát hiện file `inject/corrupt-trigger` → swap registry bằng phiên bản corrupted
3. PRE-GATE T2 fail (`jq '.' req-registry.json` exit non-zero)
4. Phase 3 invariant range error E039 logged
5. Auto-fix budget 3 retries (mỗi retry re-read registry):
   - Retry 1: re-read → vẫn corrupt → fail
   - Retry 2: re-validate jq → fail
   - Retry 3: fallback backup → no backup tồn tại → fail
6. Budget exhausted → ESCALATE qua AskUserQuestion (CORE-027 CDG E099)

## Run

```bash
cd tests/fixtures/wf-cmi/corrupt
/wf-cmi --profile=standard
```

## Expected behavior

- Phase 1 PASS, Phase 2 PASS
- Phase 3 PRE-GATE T2: jq parse exit 4 (invalid JSON) → E039
- Auto-fix attempts: 3/3 retries fail
- ESCALATE với 4 options:
  - "Re-run phase" (sửa registry rồi retry)
  - "Skip Phase 3 (risky)"
  - "Cancel pipeline"
  - "Switch profile (try quick — bỏ qua một số validation)"
- Exit code 2

## Pass criteria

- `error-ledger.json`: last entry `{error_code: "E039", phase: 3, retry_count: 3, escalated: true, resolution: "AWAIT_USER"}`
- `integrity-status.json`: `current_phase=3, status="ESCALATED"`
- Lock retained (cho phép `--resume`)
- Exit 2, không advance sang Phase 4
- Pipeline state preserved: user có thể fix registry rồi `--resume`

## Test harness note

Trong evals harness thực, test hook sẽ:
```bash
# Copy bad registry vào vị trí registry hợp lệ
mv .mc-data/docs/_meta/req-registry.json .mc-data/docs/_meta/req-registry.backup.json
cp .mc-data/docs/_meta/req-registry.corrupted.json .mc-data/docs/_meta/req-registry.json
# Trigger để skill biết đã corrupt
echo "$(date -Iseconds)" > inject/corrupt-trigger
```

## Liên kết

- Eval definition: [`.claude/skills/workflow/wf-cmi/evals/evals.json`](../../../../.claude/skills/workflow/wf-cmi/evals/evals.json) §TC-cmi-003
- Design canon: [`docs/04-skill-design/wf-cmi/09-evals-test-cases.md`](../../../../docs/04-skill-design/wf-cmi/09-evals-test-cases.md) §2.TC-cmi-003
- Error code: [`docs/04-skill-design/wf-cmi/05-error-codes.md`](../../../../docs/04-skill-design/wf-cmi/05-error-codes.md) — E039
