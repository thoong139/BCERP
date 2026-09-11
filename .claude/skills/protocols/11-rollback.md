<!-- From shared-protocols.md lines 866-910 (§11) -->
# Protocol 11 — Rollback Protocol

> Khi phase hoặc skill output bị lỗi nghiêm trọng, cần rollback an toàn.

## 11.1 Ba cấp độ rollback

| Level | Tên | Khi nào dùng | Hành động |
|-------|-----|-------------|-----------|
| **L1** | Re-run Phase | POST-GATE fail sau 3 retries cho 1 phase | Xóa output của phase đó → chạy lại phase |
| **L2** | Re-run Skill | Skill output inconsistent hoặc corrupt | Xóa toàn bộ output của skill → chạy lại skill |
| **L3** | Revert to Previous Phase | Fundamental error trong input (upstream docs sai) | Rollback đến phase trước, fix upstream → re-run từ đó |

## 11.2 Registry Rollback Rules

```
L1 (Re-run Phase):
  - Registry: KHÔNG thay đổi — phase re-run sẽ overwrite fields đúng
  - Files: Xóa output files của phase đó (chỉ phase đó)

L2 (Re-run Skill):
  - Registry: Revert fields mà skill đó sở hữu (theo Safe-Write table)
  - Files: Xóa toàn bộ output directory của skill
  - Working files: Xóa .mc-data/work/[skill]/

L3 (Revert to Previous Phase):
  - Registry: Revert về trạng thái sau phase trước (dùng backup)
  - Files: Xóa output từ phase hiện tại trở đi
  - CẢNH BÁO user: "Rollback L3 sẽ xóa output từ Phase [N] trở đi. Confirm?"
```

## 11.3 Backup Procedure

```
TRƯỚC MỖI SKILL:
  1. Copy req-registry.json → req-registry.backup-[timestamp].json
  2. Ghi snapshot: {skill, timestamp, registry_hash}
  3. Giữ tối đa 5 backups gần nhất (xóa cũ nhất nếu > 5)

KHI ROLLBACK:
  1. Tìm backup gần nhất TRƯỚC skill cần rollback
  2. Verify backup integrity (JSON valid, hash match)
  3. Restore registry từ backup
  4. Log rollback action
```
