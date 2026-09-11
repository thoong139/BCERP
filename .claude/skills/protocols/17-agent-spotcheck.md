<!-- From shared-protocols.md lines 1314-1349 (§17) -->
# Protocol 17 — Agent Output Spot-Check Protocol (BẮT BUỘC — SKILLS CÓ AGENTS)

> Kiểm tra agent output tuân thủ contract — KHÔNG dùng pattern matching sơ khai.
> Quick skills không dùng agents → bỏ qua protocol này.

## 17.1 Spot-Check Matrix (Schema-Based)

| Agent Category | Check | Cách kiểm tra | Severity |
|---------------|-------|---------------|----------|
| business/* | Output có đúng sections theo agent definition | Grep required section headers (##) | ERROR — auto-fix |
| business/* | REQ-ID present trong output | Grep `REQ-[A-Z]+-[0-9]+` | ERROR — auto-fix |
| business/* | Không mở rộng scope ngoài input | So sánh REQ-ID set output ⊆ REQ-ID set input | WARNING — log |
| engineering/* | Tuân thủ tech stack đã chốt trong Phase 3 | So sánh libraries/frameworks với architecture docs | WARNING — log |
| engineering/* | Code references có file path hợp lệ | Check paths tồn tại trong project | WARNING — log |

## 17.2 Quy tắc thực thi

QUY TẮC:
1. Spot-check chạy SAU agent trả kết quả, TRƯỚC ghi vào output file
2. Chỉ check 2-3 rules QUAN TRỌNG NHẤT per agent category
3. WARNING → log vào error_log[] + ghi vào phase-summary.md (Protocol 14) nếu có — KHÔNG block
4. ERROR → trigger Auto-Correction Loop (Protocol 2) ngay — yêu cầu agent bổ sung/sửa
5. Spot-check KHÔNG thay thế Cross-Validation Phase (Phase X trong skill template)
6. Spot-check là EARLY detection — Cross-Validation Phase vẫn chạy đầy đủ sau đó
7. **Input REQ-ID Set Mechanism (BẮT BUỘC cho scope check):** Skill PHẢI truyền input REQ-ID set cho spot-check qua context variable `$INPUT_REQ_IDS`. Skill lấy set này từ: (a) req-registry.json requirements[] nếu chạy toàn bộ, hoặc (b) feature spec input nếu chạy per-feature. Spot-check so sánh `output REQ-IDs ⊆ $INPUT_REQ_IDS`. Nếu skill không truyền → skip check này, log WARNING.

## 17.3 Relationship với existing protocols
- Protocol 2 Auto-Correction Loop: spot-check ERROR → trigger loop ngay (iteration 1)
- Protocol 8 Content Quality Gate: spot-check là subset — chỉ check schema, Protocol 8 check semantic
- Phase X Cross-Validation: spot-check là early detection, Phase X là full validation

## 17.4 Mở rộng
- Mỗi skill CÓ THỂ thêm spot-check rules riêng vào Fix Rules table
- KHÔNG thêm spot-check nếu Cross-Validation phase đã cover cùng check
- Bắt đầu với business/* và engineering/* — thêm design/*, testing/* khi có demand rõ
