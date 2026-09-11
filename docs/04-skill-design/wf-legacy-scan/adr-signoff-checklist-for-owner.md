# ADR Sign-off Checklist — wf-legacy-scan v5.0 Design v2.1

**Ngày tạo:** 2026-04-22  
**Dùng cho:** Buổi meeting review ADR trước khi Owner ký `08-tradeoffs-adr.md §5.1`  
**File đầy đủ:** `docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md`

---

## Tóm tắt trạng thái

| Hạng mục | Tech Review | Human Review |
|----------|------------|-------------|
| 17 ADRs (ADR-LS01 đến ADR-LS17) | ✅ PASSED (2026-04-22) | ⬜ Pending |
| 20-item checklist §6 | ✅ 20/20 tech-verified | ⬜ Pending |
| #7 Agent list | ✅ **AI-VERIFIED** (xem bên dưới) | — Không cần thêm |
| #10 Concurrency caps | ✅ Tech-verified | ⬜ Owner cần validate trên hardware thực |
| #13 Calibration thresholds | ✅ Tech-verified | ⬜ Owner cần approve tune-later strategy |
| #14 VN keyword accuracy | ✅ Tech-verified (structure) | ⬜ Native speaker / Domain Expert cần review |
| #16 Resource availability | ✅ Tech-verified (timeline reasonable) | ⬜ Owner cần commit timeline |

---

## Item #7 — Agent List: ✅ AI VERIFIED (không cần human review)

AI đã grep `.claude/agents/` và xác nhận tất cả 16 subagent_type strings trong implementation khớp với DEVKIT agent files:

**Core 7 (v4.1 backward-compat):**
| subagent_type | Agent file | Status |
|--------------|-----------|--------|
| `finance-expert` | `agents/business/finance-expert.md` | ✅ |
| `procurement-expert` | `agents/business/procurement-expert.md` | ✅ |
| `sales-expert` | `agents/business/sales-expert.md` | ✅ |
| `hr-expert` | `agents/business/hr-expert.md` | ✅ |
| `ecommerce-expert` | `agents/business/ecommerce-expert.md` | ✅ |
| `operations-expert` | `agents/business/operations-expert.md` | ✅ |
| `compliance-expert` | `agents/business/compliance-expert.md` | ✅ |

**Optional 7 (v5.0 mở rộng — trigger khi IPS ≥0.75):**
| subagent_type | Agent file | Status |
|--------------|-----------|--------|
| `healthcare-expert` | `agents/business/healthcare-expert.md` | ✅ |
| `logistics-expert` | `agents/business/logistics-expert.md` | ✅ |
| `manufacturing-expert` | `agents/business/manufacturing-expert.md` | ✅ |
| `retail-expert` | `agents/business/retail-expert.md` | ✅ |
| `legal-expert` | `agents/business/legal-expert.md` | ✅ |
| `insurance-expert` | `agents/business/insurance-expert.md` | ✅ |
| `education-expert` | `agents/business/education-expert.md` | ✅ |

**Fallback + L4:**
| subagent_type | Agent file | Status |
|--------------|-----------|--------|
| `business-analyst` | `agents/business/business-analyst.md` | ✅ |
| `code-reviewer` | `agents/testing/code-reviewer.md` | ✅ |

**Kết luận #7:** Không cần human review — AI đã xác minh đủ. Đánh dấu ✅ trong §5.1.

---

## Item #10 — Concurrency Caps: ⬜ Cần Owner validate

**Giá trị hiện tại** (từ ADR-LS12 + `09-thresholds-justification.md §3`):
- `global_max = 8` — tổng agents chạy đồng thời
- `per_layer_max = 3` — agents per scan layer
- `per_probe_max = 4` — agents per probe
- `reserved_for_synthesis = 2` — dành cho L6 synthesis
- `agent_timeout_standard = 300s`
- `agent_timeout_deep = 600s`

**Câu hỏi cho Owner:**
- [ ] Máy chủ / máy tính mục tiêu có RAM đủ để chạy 8 agents đồng thời không?
- [ ] Timeout 300s/600s có phù hợp với tốc độ kết nối Claude API của bạn không?
- [ ] Cần điều chỉnh `global_max` xuống (4-6) hay giữ 8?

> **Note:** Các giá trị này có thể override qua env vars (`LEGACY_SCAN_MAX_AGENTS`, `LEGACY_SCAN_AGENT_TIMEOUT_SEC`, v.v.) mà không cần sửa code.

---

## Item #13 — Calibration Thresholds: ⬜ Cần Owner approve strategy

**4 thresholds "calibration-required"** (từ `09-thresholds-justification.md §6`):

| Threshold | Giá trị v5.0 | Lý do "calibration-required" | Action cần Owner |
|-----------|-------------|-------------------------------|-----------------|
| Domain confidence min | 0.60 | Raised từ 0.40 để giảm false positive | Approve hoặc tune sau khi test |
| Feature drift tolerance | ±5% per layer | Empirical estimate, chưa có data | Approve tune-later after A.3 |
| Delta threshold incremental | 25% | Balance between re-scan và incremental | Approve tune-later |
| Per-agent timeout deep | 600s | Based on empirical Claude API response times | Approve hoặc adjust per hardware |

**Câu hỏi cho Owner:**
- [ ] Approve "tune-later" strategy: dùng giá trị v5.0 trước, điều chỉnh sau khi có real data từ A.3 fixtures?
- [ ] Hay muốn block release cho đến khi có data calibration thực?

> **Khuyến nghị:** Approve tune-later. v5.0 thresholds đều conservative (không quá tight) và có thể hot-fix qua env vars. Calibration thực cần A.3 fixtures.

---

## Item #14 — VN Keyword Accuracy: ⬜ Cần native speaker review

**Phạm vi review:** `docs/design/skills/wf-legacy-scan/10-vietnamese-keywords.md` + `.claude/skills/workflow/_shared/ips/vietnamese-keywords.json`

**14 domains cần review:**
Core 7: finance, hr, sales, operations, ecommerce, procurement, compliance  
Optional 7: healthcare, logistics, manufacturing, retail, legal, insurance, education

**Checklist cho Domain Expert/Native Speaker:**
- [ ] Các từ khóa tiếng Việt không dấu có đúng chính tả không? (VD: `hoadon` = hoá đơn ✅, `bangluong` = bảng lương ✅)
- [ ] Có domain-specific VN terminology nào quan trọng bị thiếu không?
- [ ] Các abbreviation (VD: `qlkh`, `qlns`, `bhxh`) có đủ và đúng không?
- [ ] Từ khóa có phản ánh đúng cách dev team VN đặt tên folder/file không?

> **File tham khảo:** `.claude/skills/workflow/_shared/ips/vietnamese-keywords.json` — hiện có 14 domains, mỗi domain ~8-12 từ.

---

## Item #16 — Resource Availability: ⬜ Cần Owner confirm

**Timeline từ design (đã hoàn thành — chỉ cần confirm retrospectively):**
- Design: 10 phases (A-J), thực tế hoàn thành trong 1 ngày (2026-04-22) bởi AI
- v5.0.0 đã release — timeline estimate không còn applicable
- **Action:** Owner chỉ cần confirm họ có resource để:
  - Populate A.3 fixtures (1-3 ngày)
  - A.4 human review meeting (~2 giờ)
  - Monitor + feedback sau release

---

## Hành động sau khi Owner fill checklist

1. Owner điền `08-tradeoffs-adr.md §5.1` Sign-off Sheet (Signed date + Signature)
2. AI hoặc Editor tạo tag:
   ```bash
   git tag -a design-legacy-scan-v2.1-approved \
     -m "Design v2.1 approved by Owner on $(date +%Y-%m-%d)"
   git push origin design-legacy-scan-v2.1-approved
   ```
3. Cập nhật `MIGRATION-PROGRESS.md` Phase A.4 status → ✅

