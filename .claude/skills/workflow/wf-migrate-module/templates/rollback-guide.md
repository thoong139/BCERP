---
$schema: rollback-guide-v1
migrate_id: {MIGRATE_ID}
generated_at: {timestamp}
---

# Huong dan Rollback — {MIGRATE_ID}

## Khi nao can rollback?

- Feature parity fail > 3 test cases
- Code khong compile hoac test fail
- User khong dong y ket qua implement
- Phat hien sai lech nghiep vu nghiem trong

## Cac snapshot da luu

| Snapshot ID | Phase | Thoi diem | Mo ta |
|-------------|-------|-----------|-------|
{snaplist}

## Cach rollback

### 1. Rollback Registry

Khoi phuc `req-registry.json` tu snapshot:

```bash
# Xem snapshot
cat .mc-data/work/wf-migrate-module/{MIGRATE_ID}/snapshots/registry-{snapshot_id}.json

# Khoi phuc
cp .mc-data/work/wf-migrate-module/{MIGRATE_ID}/snapshots/registry-{snapshot_id}.json \
   .mc-data/docs/_meta/req-registry.json
```

### 2. Rollback Code

```bash
# Xem danh sach file da thay doi
cat .mc-data/work/wf-migrate-module/{MIGRATE_ID}/snapshots/changed-files-{snapshot_id}.txt

# Khoi phuc tung file
git checkout -- {file_path}

# Hoac reset toan bo ve snapshot commit (neu da commit)
git reset --hard {snapshot_commit_hash}
```

### 3. Rollback Design Docs

```bash
# Xoa design docs duoc tao boi migration nay
# Danh sach file:
{design_doc_list}

rm {design_doc_paths}
```

### 4. Xac nhan rollback

```bash
# Kiem tra registry da ve dung trang thai
jq '.modules[] | select(.id == "{TARGET_MODULE}")' .mc-data/docs/_meta/req-registry.json

# Kiem tra khong con code file nao lien quan
grep -r "REQ-ID: REQ-{TARGET_MODULE}" apps/backend/
```

## Lien he

Neu rollback gap van de → kiem tra `error_log` trong `migrate-report.md`.
