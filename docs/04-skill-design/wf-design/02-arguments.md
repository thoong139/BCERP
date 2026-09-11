# 02 — Arguments

> **Mục đích file:** 4 arguments — đơn giản, nhưng `--from-scan` là cross-skill power feature.

---

## 1. Bảng arguments

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `target` | enum/string | auto-detect | Không | `platform` / `system` / `[module-name]` |
| `--status` | flag | — | Không | Hiển thị tiến độ, không thực thi |
| `--resume` | flag | — | Không | Resume từ checkpoint |
| `--from-scan=<session-id\|path>` | string | — | Không | (Sprint 5) Consume `target-map.json` từ wf-scan-target session làm baseline gap-analysis |

---

## 2. `--from-scan` cross-skill (Sprint 5)

OPTIONAL flag dành cho **legacy design / re-design**. Khi có flag:

```bash
/wf-design --from-scan=20260515-100000-a1b2
# Resolve: .mc-data/work/wf-scan-target/sessions/20260515-100000-a1b2/target-map.json
```

Skill load `target-map.json` và inject vào architect agent context:
- `layers.api_endpoints` → architect biết endpoints đã có trong code
- `layers.entities` → architect biết entities đã có
- `scan_diff` → phát hiện thay đổi giữa các đợt scan

**Hữu ích để:**
1. Baseline cho gap analysis legacy
2. Tránh re-design API/entity đã có trong code
3. Phát hiện scan_diff giữa các đợt scan

**KHÔNG thay đổi default behavior** — không pass flag → skill chạy như cũ (zero regression).

---

## 3. Target behavior

| Target value | Phase 1 scope | Lane count |
|--------------|---------------|------------|
| `platform` | All systems | N lanes (per system) |
| `system` (single) | 1 system | 1 lane |
| `[module-name]` (vd `MOD-CRM-SALES`) | Module thuộc 1 system | 1 lane focused |
| (auto-detect) | Suy từ registry.systems[] | N lanes |

---

## 4. Argument interactions

| Combo | Behavior |
|-------|----------|
| `--resume` + `--from-scan` | Resume preserve original `--from-scan` từ session-state |
| `--status` + bất kỳ | Display only |
| `target=platform` + `--from-scan` | Apply scan baseline cho all systems |

---

## 5. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| `target` | Tồn tại trong `registry.systems[]` hoặc `registry.modules[]` | — (default) |
| `--from-scan=<id>` | Session tồn tại với `target-map.json` valid | (warning, không block) |
| Registry | `test -f req-registry.json AND .features \| length > 0` | E000/E001 |
| Phase 2 features | `test -d phase2-features/ AND forensic check` (>=6 headings, >=400 words) | E002 |

---

## 6. Examples

```bash
# Default platform-wide design
/wf-design

# Single system
/wf-design SmartTax

# Single module focused
/wf-design MOD-CRM-SALES

# LEGACY re-design với scan baseline
/wf-design --from-scan=20260515-100000-a1b2

# Resume LPM session
/wf-design --resume

# Status check
/wf-design --status
```

---

## 7. Liên kết

- Error codes: [05-error-codes.md](05-error-codes.md)
- Cross-skill schema: [04-file-contract.md](04-file-contract.md) §consumes_from
- Sprint 5 details: SKILL.md §--from-scan section
