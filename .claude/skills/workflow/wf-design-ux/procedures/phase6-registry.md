# Phase 6: Update Registry

> Safe-write registry — chỉ update field `ux_design_status: "done"`.
> Thực hiện trong MAIN conversation, KHÔNG spawn agent (Protocol 6.1).

**PRE-GATE:**
- [ ] Phase 5 (`phase5-review.md`) POST-GATE PASS
- [ ] Status phải là APPROVED hoặc APPROVED_WITH_CONDITIONS (KHÔNG phải REJECTED)

**INPUT:** `.mc-data/docs/_meta/req-registry.json` (đọc lại NGAY TRƯỚC KHI GHI — không cache)

**OUTPUT:** Registry với `ux_design_status: "done"`

---

## Reference Sections

- `_shared.md` §Registry Safe-Write
- `protocols/` §5 Registry Safe-Write Protocol

---

## Steps

| Step | Action | Verify |
|------|--------|--------|
| 6.1 | ĐỌC `req-registry.json` (fresh read — KHÔNG cache từ đầu session) | Content loaded |
| 6.2 | MODIFY chỉ field `ux_design_status: "done"` — giữ nguyên mọi fields khác | In-memory modified |
| 6.3 | GHI ATOMIC — single Write operation cho toàn bộ JSON | File written |
| 6.4 | VALIDATE JSON: `jq '.' req-registry.json` phải pass | Valid JSON |
| 6.5 | VALIDATE field: `jq '.ux_design_status == "done"' req-registry.json` | Field = "done" |

---

## Registry Safe-Write Rules

```
QUY TẮC SAFE-WRITE:
1. ĐỌC registry NGAY TRƯỚC KHI GHI (bước 6.1) — không dùng cached version
2. CHỈ MODIFY field `ux_design_status` — giữ nguyên 100% fields khác:
   - requirements[]
   - features[]
   - modules[]
   - systems[]
   - departments[]
   - interface_type
   - design_status
   - implementation_order
   - impl_status (per REQ-ID)
   - ... (tất cả fields khác)
3. GHI ATOMIC — dùng 1 Write operation cho toàn bộ JSON (không append/partial)
4. VALIDATE sau ghi — jq '.' phải pass
5. KHÔNG spawn agent cho Phase 6 — execute trong main conversation
```

**Fields được phép update (per CORE-006):**
- `ux_design_status` (ONLY)

**Fields KHÔNG được modify:** tất cả fields khác.

---

## Execution Pattern

```python
# Pseudocode
import json

# Step 6.1: Fresh read
with open('.mc-data/docs/_meta/req-registry.json') as f:
    registry = json.load(f)

# Step 6.2: Modify only ux_design_status
registry['ux_design_status'] = 'done'

# Step 6.3: Atomic write
with open('.mc-data/docs/_meta/req-registry.json', 'w') as f:
    json.dump(registry, f, indent=2, ensure_ascii=False)

# Step 6.4-6.5: Validate
subprocess.run(['jq', '.', '.mc-data/docs/_meta/req-registry.json'], check=True)
subprocess.run(['jq', '-e', '.ux_design_status == "done"', '.mc-data/docs/_meta/req-registry.json'], check=True)
```

---

## POST-GATE

- [ ] `jq '.ux_design_status == "done"' .mc-data/docs/_meta/req-registry.json` trả về `true`
- [ ] `jq '.' .mc-data/docs/_meta/req-registry.json` pass (JSON hợp lệ)
- [ ] Tất cả fields khác không thay đổi (so sánh fields list pre/post write — optional sanity check)

**Next phase:** `phase7-digest-summary.md`

---

## Error Handling

- Write fail (disk full, permission denied) → retry 3 lần, sau đó escalate
- JSON parse error sau write → rollback, re-read backup, retry
- Field conflict (ai đó khác đã modify registry) → re-read, re-apply, retry (max 3)
