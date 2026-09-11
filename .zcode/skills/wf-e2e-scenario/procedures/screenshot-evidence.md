# F7 — Screenshot Evidence Procedure

## Naming Convention

```
screenshots/
├── login-result.png                 ← Login screen sau khi login
├── scenario-{NN}-{slug}.png         ← Per scenario row final state
├── scenario-{NN}-step-{S}.png       ← (optional) Per step intermediate
└── scenario-{NN}-error.png          ← (nếu FAIL) Error state evidence
```

`{NN}` = 2-digit scenario number (01, 02, ..., 99)
`{slug}` = kebab-case từ tên scenario (vd: "tao-customer-happy-path")
`{S}` = step number

---

## Capture Strategy

### Per scenario final state

```bash
# Sau khi execute all steps của 1 scenario
SLUG=$(echo "$SCENARIO_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
mcp__plugin_playwright_playwright__browser_take_screenshot \
  --output="$SCREENSHOTS/scenario-${NN}-${SLUG}.png" \
  --full_page=true
```

### Per failure step (debug evidence)

```bash
# Nếu Pass/Fail=FAIL → capture error state
mcp__plugin_playwright_playwright__browser_take_screenshot \
  --output="$SCREENSHOTS/scenario-${NN}-error.png" \
  --full_page=true

# Also capture console errors
CONSOLE=$(mcp__plugin_playwright_playwright__browser_console_messages)
echo "$CONSOLE" > "$SCREENSHOTS/scenario-${NN}-console.log"
```

### Cross-module scenarios

```bash
# Per module page in chain
for MODULE in upstream downstream; do
  mcp__plugin_playwright_playwright__browser_take_screenshot \
    --output="$SCREENSHOTS/scenario-${NN}-${MODULE}.png"
done
```

---

## Evidence Links trong test-scenario.md

Sau bảng steps của mỗi scenario:

```markdown
| Bước | Hành động | Kết quả mong đợi | Kết quả thực tế | Pass/Fail |
|------|-----------|------------------|------------------|-----------|
| 1    | ...       | ...              | ...              | ✅ PASS    |
| 2    | ...       | ...              | ...              | ✅ PASS    |

**Evidence:** [scenario-01-tao-customer.png](../screenshots/scenario-01-tao-customer.png)
**Tested by:** wf-e2e-scenario v1.0.0 at 2026-05-13T16:30:00Z
```

---

## Screenshot Size + Quality

- Full page: capture entire scrollable content (default)
- Viewport only: `--full_page=false` (rare, cho specific element evidence)
- Format: PNG (lossless)
- Compression: default

---

## Error Handling

| Error | Action |
|-------|--------|
| E077 Screenshot fail | Log warning, scenario marked "PARTIAL" thay vì PASS/FAIL |
| Disk full | Capture skipped, scenario marked "NO_EVIDENCE", continue execution |
| File path too long (Windows) | Truncate slug to 50 chars |

---

## Cleanup (sau F7 done)

Không xóa screenshots — chúng là evidence cho:
- Orchestrator summary
- User review
- F8 demo reference (nếu cần)
- Compliance audit trail
