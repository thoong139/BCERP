<!--
_template_notes:
  purpose: Tham chiếu arguments skill nhận, default values, validation rules.
  populate:
    - §1 Bảng arguments: 1 row/arg, đầy đủ Type/Default/Mô tả
    - §2 Args interaction: combo argument, conflict, precedence
    - §3 Validation rules: regex, range, enum
    - §4 Examples: ≥3 use cases command line
    - §5 Profile detail (nếu có): mỗi profile mở/khóa args nào
  độ dài tham khảo: 150-300 dòng
  bỏ §5 nếu skill không có --profile
-->

# 02 — Arguments

> **Mục đích file:** Đặc tả arguments của skill — type, default, validation, interactions.

---

## 1. Bảng arguments

| Arg | Type | Default | Required | Mô tả |
|-----|------|---------|----------|-------|
| `--scope` | string | `all` | Không | Phạm vi xử lý (all, module:X, file:Y) |
| `--profile` | enum | `standard` | Không | `quick`, `standard`, `deep`, `exhaustive` |
| `--dry-run` | flag | — | Không | Mô phỏng, không ghi file |
| `--resume` | flag | — | Không | Resume session đang dở |
| `--status` | flag | — | Không | In trạng thái session hiện tại |
| `{...}` | {...} | {...} | {...} | {...} |

---

## 2. Argument interactions

| Combo | Behavior |
|-------|----------|
| `--resume` + `--scope` | `--scope` bị ignore (lấy từ session cũ) |
| `--dry-run` + `--apply` | ERROR — mutually exclusive |
| `--profile=quick` + `--deep-scan` | WARNING — quick override thành standard |

---

## 3. Validation rules

| Arg | Rule | Error code |
|-----|------|------------|
| `--scope` | Match regex `^(all|module:[a-z0-9-]+|file:.+)$` | E010 |
| `--profile` | In set {quick, standard, deep, exhaustive} | E011 |
| `--session-id` | Match `YYYY-MM-DD-{scope}-{slug}-NN` | E012 |
| `{...}` | {...} | {...} |

---

## 4. Examples

```bash
# Run đầy đủ standard profile
/{skill-name}

# Quick scan cho 1 module
/{skill-name} --scope=module:sales --profile=quick

# Resume session đang dở
/{skill-name} --resume

# Status check
/{skill-name} --status

# Dry-run xem trước, không ghi
/{skill-name} --profile=deep --dry-run
```

---

## 5. Profile detail (nếu skill có `--profile`)

| Profile | Time | Scope | Probes activated | Cache policy |
|---------|------|-------|------------------|-------------|
| `quick` | 2-5 min | Targeted | {N} probes | Use cache aggressive |
| `standard` | 10-20 min | Full | {N} probes | Normal cache |
| `deep` | 30-60 min | Full + LLM | {N} probes | Selective cache |
| `exhaustive` | 60+ min | Full + LLM + runtime | All | Skip cache |

---

## 6. Liên kết

- Validation script: [`.claude/scripts/{skill-name}/validate-args.sh`](../../../.claude/scripts/) (nếu có)
- Error codes detail: [05-error-codes.md](05-error-codes.md)
- Profile execution: trong [03-phase-routing.md](03-phase-routing.md) §profile dispatch
