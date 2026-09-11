# Deployment Guide — [TÊN DỰ ÁN]

> READS: `phase3-architecture/technical-specs/infra-spec.md`, `phase3-architecture/P3-01-architecture.md`, `phase3-architecture/technical-specs/database-design.md`
> USED BY: `user-guide.md`, `phase6-deployment/stakeholder-review.md`
> DATE: YYYY-MM-DD | VERSION: v[X.Y]

---

## 1. Environments

| Env | URL | Branch | Deploy trigger | Approval |
|-----|-----|--------|---------------|---------|
| Development | `localhost:[PORT]` | any | Manual | Không cần |
| Staging | `staging.[domain]` | `develop` | Auto on push | Không cần |
| Production | `[domain]` | `main` | Manual | Cần approval |

---

## 2. Prerequisites

```bash
# Công cụ cần cài đặt trên máy deploy
node >= 20.x          # Kiểm tra: node --version
docker >= 24.x        # Kiểm tra: docker --version
docker-compose >= 2.x # Kiểm tra: docker-compose --version

# Quyền truy cập cần có
✅ Docker registry (push/pull images)
✅ Target server SSH access
✅ Database admin access (để chạy migrations)
✅ ENV variables của môi trường target
```

---

## 3. Required Environment Variables

> Xem đầy đủ trong `technical-specs/infra-spec.md § Required Environment Variables`
> Tạo file `.env` từ `.env.example` và điền values thực tế.

```bash
# Kiểm tra tất cả ENV bắt buộc đã có
cat .env.example | grep -v '^#' | grep '=' | while IFS='=' read key val; do
  if [ -z "${!key}" ]; then
    echo "❌ Missing: $key"
  else
    echo "✅ Set: $key"
  fi
done
```

---

## 4. Build & Deploy Steps

### 4.0. Placeholder Setup

> Trước khi chạy các script deploy, điền các placeholders sau:

| Placeholder | Nguồn lấy giá trị |
|-------------|-------------------|
| `[registry]` | URL container registry (VD: `ghcr.io/org`, `registry.digitalocean.com/project`) |
| `[app-name]` | Tên app từ `package.json` hoặc quy ước đặt tên dự án |
| `$GIT_SHA` | Tự động từ Git: `export GIT_SHA=$(git rev-parse --short HEAD)` |
| `[domain]` | Domain thực tế từ DNS config trong `infra-spec.md` |
| `$STAGING_DB_URL` | Connection string từ ENV variables (xem Mục 3) |

### DEP-STAGING-001: Deploy lên Staging

```bash
# Bước 1: Lấy code mới nhất
git checkout develop
git pull origin develop

# Bước 2: Build Docker image
docker build -t [registry]/[app-name]:$GIT_SHA .
echo "✅ Build OK: $GIT_SHA"

# Bước 3: Run tests
docker run --rm [registry]/[app-name]:$GIT_SHA npm run test
echo "✅ Tests passed"

# Bước 4: Push image
docker push [registry]/[app-name]:$GIT_SHA
echo "✅ Pushed to registry"

# Bước 5: Chạy database migration
DATABASE_URL=$STAGING_DB_URL npm run migration:run
echo "✅ Migration done"

# Bước 6: Deploy
docker-compose -f docker-compose.staging.yml up -d --force-recreate
# HOẶC nếu dùng Kubernetes:
kubectl set image deployment/[app-name] app=[registry]/[app-name]:$GIT_SHA -n staging

# Bước 7: Health check
sleep 10
curl -f https://staging.[domain]/health || (echo "❌ Health check failed" && exit 1)
echo "✅ Deploy staging OK"
```

### DEP-PROD-001: Deploy lên Production

```bash
# ⚠️ CRITICAL: Thực hiện từng bước, không skip

# Bước 1: Xác nhận đã test trên staging
echo "Đã test đầy đủ trên staging? (yes/no)"
read confirm
[ "$confirm" != "yes" ] && echo "Abort." && exit 1

# Bước 2: BACKUP DATABASE
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
pg_dump $PROD_DB_URL > backup_${TIMESTAMP}.sql
echo "✅ Backup: backup_${TIMESTAMP}.sql"

# Bước 3: Thông báo maintenance (nếu cần downtime)
# [Gửi thông báo đến users nếu có downtime]

# Bước 4: Chạy migration production
DATABASE_URL=$PROD_DB_URL npm run migration:run
echo "✅ Production migration done"

# Bước 5: Blue-green / Rolling deploy
kubectl set image deployment/[app-name] app=[registry]/[app-name]:$GIT_SHA -n production
kubectl rollout status deployment/[app-name] -n production
echo "✅ Deploy initiated"

# Bước 6: Health check
sleep 30
curl -f https://[domain]/health || (echo "❌ Health check FAILED — xem rollback" && exit 1)
echo "✅ Production deploy OK: $GIT_SHA"

# Bước 7: Monitor 30 phút sau deploy
echo "📊 Monitor dashboard: [MONITORING_URL]"
echo "⏱️  Monitor ít nhất 30 phút trước khi đóng ca"
```

---

## 5. Rollback Procedure

> Thực hiện ngay khi phát hiện lỗi sau deploy.

```bash
# Rollback code — về version trước
kubectl rollout undo deployment/[app-name] -n production
kubectl rollout status deployment/[app-name] -n production
echo "✅ Code rolled back"

# Kiểm tra version hiện tại
kubectl get deployment [app-name] -n production -o jsonpath='{.spec.template.spec.containers[0].image}'

# Rollback database (chỉ khi migration đã chạy và cần rollback)
# ⚠️ NGUY HIỂM — Chỉ làm khi thật sự cần thiết
DATABASE_URL=$PROD_DB_URL npm run migration:revert
# HOẶC restore từ backup
pg_restore -d $PROD_DB_URL backup_YYYYMMDD_HHMMSS.sql

# Health check sau rollback
curl -f https://[domain]/health
echo "✅ Rollback complete — verify functionality"
```

---

## 6. Smoke Tests Sau Deploy

Chạy các tests cơ bản để xác nhận hệ thống hoạt động:

```bash
BASE_URL="https://[domain]"

# 1. Health check
curl -f $BASE_URL/health

# 2. Auth flow
TOKEN=$(curl -s -X POST $BASE_URL/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"[test-email]","password":"[test-pass]"}' \
  | jq -r '.data.token')
[ -z "$TOKEN" ] && echo "❌ Auth failed" && exit 1
echo "✅ Auth OK"

# 3. Core API endpoint
curl -f -H "Authorization: Bearer $TOKEN" \
  $BASE_URL/api/v1/[system]/[resource]?limit=1
echo "✅ Core API OK"

echo "✅ Smoke tests passed"
```

---

## 7. CI/CD Pipeline (Reference)

```yaml
# .github/workflows/deploy.yml (tham khảo)
stages:
  test:      # Chạy unit + integration tests
  build:     # Build Docker image, tag với Git SHA
  push:      # Push image lên registry
  staging:   # Auto deploy khi push vào develop
  production: # Manual trigger + approval required
```

---

## 8. Post-Deploy Checklist

```
□ Health check endpoints trả 200
□ Smoke tests passed
□ Error rate < 0.1% (xem monitoring dashboard)
□ Response time P95 < 500ms
□ Không có error spike trong logs
□ Database connections ổn định
□ Thông báo team deploy thành công + Git SHA
```

---

## 9. Quản Lý Tài Khoản & Phân Quyền (Account Management)

> Hướng dẫn quản lý tài khoản, phân quyền, và onboarding/offboarding người dùng.

### 9.1. Default Admin Account

> ⚠️ CRITICAL: Đổi mật khẩu default ngay sau khi deploy lần đầu.

| Field | Giá trị mặc định |
|-------|-----------------|
| Email | `admin@[domain]` |
| Password | `[Set trong ENV: DEFAULT_ADMIN_PASSWORD]` |
| Role | ADMIN |

**Bước đầu tiên sau deploy:**
```
1. Đăng nhập bằng admin account
2. Đổi mật khẩu ngay (Profile → Đổi mật khẩu)
3. Tạo tài khoản cá nhân riêng cho từng admin
4. Tắt hoặc đổi email default admin account
```

---

### 9.2. Roles & Permissions Matrix

> Roles được định nghĩa theo từng system. Một user có thể có nhiều roles.

**Role Definitions**

| Role ID | Tên role | System | Mô tả |
|---------|---------|--------|-------|
| ROLE-ADMIN | Admin | ALL | Toàn quyền tất cả systems |
| ROLE-[SYS]-MANAGER | [System] Manager | [SYS] | Quản lý toàn bộ system [SYS] |
| ROLE-[SYS]-STAFF | [System] Staff | [SYS] | Thao tác trong system [SYS] |
| ROLE-[SYS]-VIEWER | [System] Viewer | [SYS] | Chỉ xem, không sửa |

**Permission Matrix**

| Action | ADMIN | [SYS]-MANAGER | [SYS]-STAFF | [SYS]-VIEWER |
|--------|-------|--------------|-------------|-------------|
| Xem tất cả records | ✅ | ✅ | ❌ (chỉ own) | ✅ |
| Xem records của mình | ✅ | ✅ | ✅ | ✅ |
| Tạo mới | ✅ | ✅ | ✅ | ❌ |
| Sửa (own) | ✅ | ✅ | ✅ | ❌ |
| Sửa (any) | ✅ | ✅ | ❌ | ❌ |
| Xóa | ✅ | ✅ | ❌ | ❌ |
| Export data | ✅ | ✅ | ✅ | ✅ |
| Quản lý users | ✅ | ❌ | ❌ | ❌ |
| Xem audit logs | ✅ | ✅ | ❌ | ❌ |
| Cấu hình system | ✅ | ❌ | ❌ | ❌ |

---

### 9.3. Tạo Tài Khoản Người Dùng Mới

**Ai có quyền tạo:** ADMIN, [SYS]-MANAGER (trong system của mình)

**Các bước:**
```
1. Đăng nhập với quyền Admin/Manager
2. Vào: Quản trị → Người dùng → Thêm mới
3. Điền thông tin:
   - Họ tên đầy đủ (bắt buộc)
   - Email công ty (bắt buộc, dùng để đăng nhập)
   - Phòng ban (bắt buộc)
   - Vai trò / Role (bắt buộc — chọn đúng role)
4. Nhấn "Tạo tài khoản"
5. Hệ thống tự gửi email welcome + link đặt mật khẩu cho user mới
   (Link hết hạn sau 24 giờ)
```

**Checklist onboarding user mới:**
```
□ Tạo tài khoản với đúng role
□ User nhận được email welcome
□ User đã đặt mật khẩu (confirm với user)
□ Hướng dẫn user đọc User Guide
□ Test đăng nhập thành công
□ Kiểm tra user thấy đúng menu/tính năng theo role
```

---

### 9.4. Chỉnh Sửa Tài Khoản

```
Thay đổi thông tin cá nhân:
  → User tự sửa: Profile → Cập nhật thông tin
  → Admin sửa hộ: Quản trị → Người dùng → Chọn user → Sửa

Thay đổi Role:
  → Chỉ ADMIN thực hiện được
  → Quản trị → Người dùng → Chọn user → Phân quyền
  → Thay đổi có hiệu lực ngay (phiên hiện tại của user sẽ bị refresh)

Reset mật khẩu:
  → Admin: Quản trị → Người dùng → Chọn user → "Reset mật khẩu"
  → Hệ thống gửi email link đặt lại mật khẩu mới cho user
```

---

### 9.5. Vô Hiệu Hóa / Xóa Tài Khoản (Offboarding)

> ⚠️ Không xóa tài khoản — Vô hiệu hóa (deactivate) để giữ audit trail.

**Quy trình offboarding khi nhân viên nghỉ việc:**
```
□ Bước 1: Vô hiệu hóa tài khoản NGAY khi nhân viên nghỉ
   Admin → Quản trị → Người dùng → Chọn user → "Vô hiệu hóa"
   (User không đăng nhập được, data của họ vẫn còn)

□ Bước 2: Chuyển giao ownership
   Kiểm tra records nào user này đang phụ trách → chuyển sang người khác

□ Bước 3: Thu hồi quyền truy cập các service liên quan
   VPN, email, v.v. (ngoài phạm vi hệ thống này)

□ Bước 4: Log lại trong Security Audit
   Ghi nhận: tên user, ngày nghỉ, ai thực hiện offboarding
```

---

### 9.6. Audit Log

Hệ thống tự động ghi lại các thao tác quan trọng:

| Hành động được log | Thông tin ghi lại |
|---------------------|------------------|
| Đăng nhập / Đăng xuất | User, thời gian, IP |
| Tạo / Sửa / Xóa record | User, thời gian, record ID, giá trị cũ/mới |
| Thay đổi quyền user | Admin thực hiện, user bị thay đổi, role cũ/mới |
| Export data | User, thời gian, số lượng records |
| Đăng nhập thất bại | Email, thời gian, IP, số lần thất bại |

**Xem audit log:**
```
Admin → Quản trị → Audit Log
Lọc theo: User / Thời gian / Loại hành động
Xuất báo cáo: Hỗ trợ xuất Excel
Lưu trữ: [N] tháng / năm
```

---

### 9.7. Bảo Mật Tài Khoản

```
Password policy:
  - Tối thiểu 8 ký tự
  - Phải có: chữ hoa, chữ thường, số
  - Không được dùng lại 5 mật khẩu gần nhất
  - Bắt buộc đổi mật khẩu sau [N] ngày (nếu được cấu hình)

Session policy:
  - Tự động đăng xuất sau [N] giờ không hoạt động
  - Chỉ cho phép đăng nhập từ 1 thiết bị cùng lúc (nếu được cấu hình)
  - Đăng nhập từ IP lạ → yêu cầu xác thực thêm

Account lockout:
  - Khóa tạm thời 15 phút sau 5 lần nhập sai liên tiếp
  - Admin có thể mở khóa thủ công sớm hơn
```

---

## 10. Bảo Trì & Vận Hành (Maintenance & Operations)

> Hướng dẫn vận hành, bảo trì, nâng cấp và xử lý sự cố.

### 10.1. Routine Maintenance Schedule

| Tác vụ | Tần suất | Lệnh / Cách thực hiện | Người thực hiện |
|--------|---------|----------------------|----------------|
| Database backup | Hàng ngày (2:00 AM) | Auto (cron job) | DevOps |
| Log rotation | Hàng tuần | Auto (logrotate) | DevOps |
| Kiểm tra disk usage | Hàng tuần | `df -h` trên server | DevOps |
| Dependency security audit | Hàng tháng | `npm audit` / `pip audit` | Dev Lead |
| SSL certificate check | Hàng tháng | `openssl s_client -connect [domain]:443` | DevOps |
| DB slow query review | Hàng tháng | Xem slow query log | Dev Lead |
| Performance review | Hàng quý | Xem Grafana/Datadog dashboards | Dev Lead |
| SSL certificate renewal | Hàng năm | Auto (Let's Encrypt) / Manual | DevOps |
| Dependency major update | Hàng năm | Theo quy trình major upgrade | Dev Team |

---

### 10.2. Monitoring Checklist

**Daily Check**

```
□ Error rate < 0.1%
□ P95 response time < 500ms
□ DB connection pool utilization < 80%
□ Disk usage < 70%
□ Không có CRITICAL alerts chưa xử lý
□ Backup hàng đêm chạy thành công
```

**Weekly Check**

```
□ Memory usage trend (tăng dần → có thể memory leak)
□ Slow query log — có query nào cần optimize?
□ Security audit log — có hành động bất thường?
□ Disk growth trend — cần mở rộng không?
□ Error patterns — lỗi mới nào xuất hiện thường xuyên?
```

**Monthly Check**

```
□ Dependency vulnerabilities (npm audit / pip audit)
□ SSL certificate còn hạn (cảnh báo khi còn < 30 ngày)
□ DB statistics update (ANALYZE để query planner chính xác)
□ Unused indexes (xóa để giảm overhead)
□ Archive logs cũ (> 90 ngày)
```

---

### 10.3. Backup & Restore

**Backup Database**

```bash
# Manual backup (khi cần trước khi thực hiện thay đổi lớn)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_[project]_${TIMESTAMP}.sql"

pg_dump $DATABASE_URL > $BACKUP_FILE
gzip $BACKUP_FILE
echo "✅ Backup: ${BACKUP_FILE}.gz"

# Upload lên S3/storage
aws s3 cp ${BACKUP_FILE}.gz s3://[bucket]/backups/
echo "✅ Uploaded to S3"
```

**Restore Database**

```bash
# ⚠️ NGUY HIỂM — Ghi đè toàn bộ dữ liệu hiện tại
# Chỉ thực hiện khi thực sự cần thiết và có approval

# Bước 1: Stop application (không cho user kết nối)
kubectl scale deployment [app-name] --replicas=0

# Bước 2: Restore
gunzip backup_[project]_YYYYMMDD_HHMMSS.sql.gz
psql $DATABASE_URL < backup_[project]_YYYYMMDD_HHMMSS.sql
echo "✅ Restore complete"

# Bước 3: Verify data
psql $DATABASE_URL -c "SELECT COUNT(*) FROM [main_table];"

# Bước 4: Start application lại
kubectl scale deployment [app-name] --replicas=2
echo "✅ Application restarted"
```

---

### 10.4. Upgrade Procedure

**Minor Version (v1.x → v1.y — Bug fixes, small features)**

```
1. Đọc CHANGELOG.md để biết thay đổi
2. Deploy lên staging theo deployment-guide.md
3. Run smoke tests
4. Nếu OK → deploy production theo quy trình chuẩn
5. Monitor 30 phút sau deploy
```

**Major Version (v1.x → v2.x — Breaking changes)**

```
1. Đọc migration guide từ v1 → v2
2. Tạo feature branch: git checkout -b chore/upgrade-v2
3. Update dependencies từng bước:
   a. Update một dependency lớn
   b. Fix breaking changes
   c. Run tests — đảm bảo pass
   d. Lặp lại cho dependency tiếp theo
4. Full regression test trên staging (tối thiểu 1 tuần)
5. UAT với key users
6. Deploy production với rollback plan sẵn sàng
7. Monitor chặt chẽ 48h sau deploy
```

**Database Migration**

```
Trước khi migrate:
  □ Backup database
  □ Test migration trên staging
  □ Có rollback script sẵn sàng
  □ Chọn thời điểm ít traffic (ban đêm / cuối tuần)

Chạy migration:
  npm run migration:run     # Chạy tất cả pending migrations
  npm run migration:status  # Xem status các migrations
  npm run migration:revert  # Rollback migration cuối

Sau khi migrate:
  □ Verify data integrity
  □ Test các features liên quan
  □ Monitor performance (index mới / schema change có thể ảnh hưởng)
```

---

### 10.5. Troubleshooting Guide

| Triệu chứng | Nguyên nhân có thể | Hành động |
|------------|-------------------|-----------|
| 500 errors tăng đột biến | Deploy lỗi / DB issue | Check logs → nếu do deploy: rollback ngay |
| Response time tăng cao | DB queries chậm / N+1 / High load | Check slow query log, DB connections, CPU |
| Memory leak (RAM tăng dần) | Event listener chưa cleanup / Cache không expire | Restart pod tạm thời, investigate sau |
| DB connections exhausted | Connection pool không đủ / Connections không được release | Tăng pool size, tìm leaked connections |
| Auth failures spike | JWT secret thay đổi / Token service down | Verify ENV vars, check auth service logs |
| Disk full | Logs không rotate / Data growth lớn / Backup tích lũy | Xóa logs cũ, archive data, mở rộng disk |
| Cache miss rate cao | Redis restart / Cache eviction | Check Redis memory, tăng memory nếu cần |
| External API errors | Third-party service down / Rate limit | Check service status page, implement retry |

**Log Locations**

```bash
# Application logs
kubectl logs deployment/[app-name] -n production --tail=100
kubectl logs deployment/[app-name] -n production --since=1h

# Database logs
# PostgreSQL: /var/log/postgresql/postgresql-*.log

# Nginx/Gateway logs
# /var/log/nginx/access.log
# /var/log/nginx/error.log
```

**Useful Debug Commands**

```bash
# Kiểm tra DB connections đang mở
psql $DATABASE_URL -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# Tìm slow queries đang chạy (> 5 giây)
psql $DATABASE_URL -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds';"

# Kiểm tra disk usage
df -h
du -sh /var/log/* | sort -rh | head -20

# Kiểm tra memory usage theo process
ps aux --sort=-%mem | head -10

# Check Redis memory
redis-cli info memory | grep used_memory_human
```

---

### 10.6. Incident Response

**Mức độ Severity**

| Severity | Mô tả | Response time | Escalation |
|----------|-------|--------------|------------|
| P0 — Critical | Hệ thống down hoàn toàn | 15 phút | Ngay lập tức |
| P1 — High | Tính năng core không dùng được | 1 giờ | Sau 30 phút không fix |
| P2 — Medium | Tính năng phụ bị ảnh hưởng | 4 giờ | Sau 2 giờ |
| P3 — Low | Lỗi nhỏ, workaround có | 1 ngày làm việc | Không cần |

**Incident Protocol**

```
1. PHÁT HIỆN sự cố
   → Alert từ monitoring / User report / Tự phát hiện

2. ĐÁNH GIÁ severity (P0/P1/P2/P3)

3. THÔNG BÁO ngay (nếu P0/P1)
   → Team channel: "[P0] Hệ thống X đang down — đang xử lý"
   → Stakeholders nếu ảnh hưởng users

4. ĐIỀU TRA
   → Check logs → Tìm root cause
   → Isolate vấn đề

5. XỬ LÝ
   → Fix hoặc rollback (rollback nếu do deploy)
   → Verify fix

6. THÔNG BÁO resolved
   → "[Resolved] Hệ thống X đã hoạt động bình thường lúc HH:MM"

7. POST-MORTEM (cho P0/P1)
   → Viết trong 48h sau incident
   → Timeline, root cause, fix, prevention
```
