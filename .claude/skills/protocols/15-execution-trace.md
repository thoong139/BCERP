<!-- From shared-protocols.md lines 1124-1172 (§15) -->
# Protocol 15 — Execution Trace Protocol (BẮT BUỘC — MỌI SKILL)

> Ghi lại hành động của skill để trace được toàn bộ workflow.
> File này là OUTPUT-ONLY OBSERVABILITY — KHÔNG dùng làm input context cho skill tiếp theo.

## 15.1 Log Path
- File: `.mc-data/work/_trace/session-log.json`
- Template: `.claude/doc-framework/_meta/session-log.template.json`
- Tạo bởi: skill đầu tiên chạy (nếu chưa tồn tại)

## 15.2 Khi nào ghi

| Thời điểm | Event | Ghi gì |
|-----------|-------|--------|
| Bắt đầu skill (sau PRE-GATE pass) | START | skill, phase, timestamp, run_sequence |
| Kết thúc skill (sau POST-GATE pass) | COMPLETE | agents_invoked, files_created/modified, warnings, decisions |
| Skill fail (POST-GATE fail sau 3 iterations) | FAIL | errors, phase dừng ở đâu |
| Checkpoint saved (Protocol 3) | CHECKPOINT | checkpoint_id, phase, batch |

## 15.3 Quy tắc

QUY TẮC:
1. ĐỌC session-log.json trước khi APPEND — không ghi đè entries cũ
2. APPEND-ONLY — chỉ thêm entry mới vào cuối mảng entries[]
3. Nếu file chưa tồn tại → tạo từ template
4. VALIDATE sau ghi: jq '.entries | length > 0' session-log.json
5. Failure ghi log KHÔNG block skill execution — log là best-effort
6. KHÔNG dùng session-log.json làm input/context cho bất kỳ skill nào
7. Khi skill chạy lại: run_sequence = max(existing run_sequence for same skill) + 1
8. KHÔNG bao giờ Read toàn bộ session-log.json trong skill execution — chỉ append
9. Concurrent write protection: tuân thủ CORE-025 (isolated write scope). Nếu chạy song song, dùng `jq` atomic write pattern: `tmp=$(mktemp); jq '.entries += [new_entry]' session-log.json > "$tmp" && mv "$tmp" session-log.json`. Đọc-modify-ghi trong 1 pipeline, giảm thiểu race window. KHÔNG chạy 2 skills ghi session-log đồng thời nếu không có write isolation (CORE-025).

## 15.4 Rotation Policy

QUY TẮC:
- Giữ tối đa 200 entries gần nhất
- Khi vượt 200: tự động archive entries cũ vào `.mc-data/work/_trace/session-log.archive.json`
- Archive chạy khi append entry mới — best-effort, không block
- User có thể đọc archive file nếu cần tra cứu lịch sử
- Kích thước dự kiến: mỗi entry ~500 bytes → 200 entries ≈ 100KB (không loãng AI context vì không đọc)

## 15.5 Ownership
- Mỗi skill tự ghi entry của mình
- session-log.json là APPEND-ONLY — không skill nào xóa/sửa entries cũ

## 15.6 User Access
- User có thể đọc session-log.json bất kỳ lúc nào để xem tiến độ
- Kết hợp với phase-summary.md (Protocol 14) để có cả chi tiết kỹ thuật lẫn tóm tắt doanh nghiệp
