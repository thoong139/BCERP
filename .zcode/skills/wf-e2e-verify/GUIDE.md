# Hướng Dẫn Sử Dụng: /wf-e2e-verify

Skill này **kiểm thử một tính năng từ đầu đến cuối** — từ hiểu nghiệp vụ, kiểm tra database, gọi API, xem giao diện, xử lý lỗi, cho đến sinh kịch bản test và hướng dẫn sử dụng bằng tiếng Việt.

> **v7.0.0:** Kiến trúc mới — 1 orchestrator điều phối **8 sub-skills (F1-F8)** tuần tự, tự skip/retry theo điều kiện. `--cross-module` và `--parallel-safe` không còn cần thiết (luôn bật). Browser testing (F2/F7/F8) mặc định chạy trong pipeline.

---

## Skill này làm gì?

| Sub-skill | Làm gì | Khi nào chạy |
|-----------|--------|--------------|
| **F1** `wf-e2e-test` | Phase 0-6 code-based: nghiệp vụ, DB, API, UI, integration | LUÔN |
| **F2** `wf-e2e-browser` | Playwright pre-scan + browser tests | LUÔN (live browser BẮT BUỘC, auto-start) |
| **F3** `wf-e2e-unblock` | Tháo gỡ test bị blocked (env thiếu, permission, data...) | Nếu F1/F2 phát hiện blocked |
| **F4** `wf-e2e-implement` | Delegate sang `wf-implement-feature` implement tính năng còn thiếu | Nếu F1/F2 phát hiện implement-required |
| **F5** `wf-e2e-retest` | Retest sau F4 hoặc các item còn PENDING | Sau F4 hoặc khi có PENDING |
| **F6** `wf-e2e-fix` | Auto-fix open issues, max 3 vòng F6↔F5 | Nếu còn issues open |
| **F7** `wf-e2e-scenario` | Playwright: hoàn thiện `test-scenario.md` với kết quả thực tế | LUÔN (auto-start mandatory) |
| **F8** `wf-e2e-demo` | Playwright: sinh `user-guide.md` hoàn chỉnh | LUÔN (auto-start mandatory) |

Mọi issue phát hiện ghi realtime vào `issues.json`. Tổng kết trong `orchestrator-summary.md` và `phase-summary.md`.

---

## Cú pháp cơ bản

```
/wf-e2e-verify <FEAT-ID> [các cờ tùy chọn]
```

---

## Các cờ hay dùng

| Cờ | Ý nghĩa |
|----|---------|
| *(không có cờ)* | Chạy F1-F8, dừng hỏi xác nhận nghiệp vụ ở F1 |
| `--auto` | Tự động xác nhận mọi prompt, tự fix FAIL trên đường đi |
| `--resume` | Tiếp tục session đang dở |
| `--from-step=<F1-F8>` | Jump đến sub-skill cụ thể (validate prereq trước) |
| `--skip=<F2,F3>` | Opt-out sub-skills cụ thể (comma-separated) |
| `--status` | Xem dashboard 8-step pipeline rồi dừng |
| `--session=<id>` | Chỉ định session ID cụ thể |
| `--show-browser` | Hiển thị browser khi Playwright (không headless) |
| `--mobile` | Mobile viewport khi Playwright |
| `--max-impl-items=<N>` | Giới hạn số item implement trong F4 (ưu tiên P0) |

### Legacy flags (vẫn hoạt động nhưng không cần thiết nữa)

| Legacy flag | Behavior hiện tại | Ghi chú |
|-------------|-------------------|---------|
| `--parallel-safe` | No-op — luôn bật | WARN: deprecated |
| `--cross-module` | No-op — luôn bật | WARN: deprecated |
| `--playwright-mcp` | No-op — Playwright BẮT BUỘC F2/F5/F7/F8 | WARN: deprecated |
| `--no-playwright` | **DEPRECATED v7.1.0** — ignored. Live browser BẮT BUỘC. Muốn bỏ qua UI test: dùng `--skip=F2,F5,F7,F8` explicit. | WARN: deprecated, ignored |
| `--fix=<path>` | Jump sang F6 với report path đó | Vẫn hoạt động |
| `--retest` | Jump sang F5 standalone | Vẫn hoạt động |
| `--unblock-test` | Jump sang F3 standalone | Vẫn hoạt động |
| `--phase=<0-6>` | Alias `--from-step=F1` | Vẫn hoạt động, WARN |
| `--phase=7` | Alias `--from-step=F7` | Vẫn hoạt động, WARN |

---

## Kết quả được lưu ở đâu?

Mỗi lần chạy tạo một **session** riêng tại:
```
.mc-data/work/wf-e2e-verify/sessions/{FEAT-ID}-{ngày-giờ}/
```

> ⚠️ Cấu trúc thư mục là **cố định** — mọi file PHẢI nằm đúng vị trí bên dưới.

```
├── e2e-status.json              ← ORCHESTRATOR SSOT 8-step (trạng thái F1-F8)
├── session-log.json             ← Execution trace
├── error-ledger.json            ← Log lỗi theo phase
├── prompt-context.md            ← Input người dùng verbatim
├── .lock                        ← Session lock + heartbeat
│
├── issues.json                  ← Tất cả issues (F1/F2 thêm, F6 cập nhật)
├── block-test.json              ← Test bị blocked (F1/F2 thêm, F3 giải quyết)
├── implement-required.json      ← Tính năng cần implement (F4 xử lý)
├── manual.json                  ← Items cần xác nhận thủ công
│
├── findings/                    ← F1: business-understanding, db, api, ui, fix-log
├── outputs/
│   ├── test-scenario.md         ← Kịch bản test (F1 tạo khung, F7 hoàn thiện)
│   └── user-guide.md            ← Hướng dẫn tiếng Việt (F1 tạo khung, F8 hoàn thiện)
│
├── screenshots/                 ← Ảnh Playwright (prefix: browser-/scenario-/demo-)
│
├── F1-test/                     ← Workspace F1
├── F2-browser/                  ← Workspace F2
├── F3-unblock/                  ← Workspace F3 (nếu có blocked)
├── F4-implement/                ← Workspace F4 (nếu có implement-required)
├── F5-retest/                   ← Workspace F5
├── F6-fix/                      ← Workspace F6 (nếu có open issues)
├── F7-scenario/                 ← Workspace F7
├── F8-demo/                     ← Workspace F8
│
├── _locks/
│   ├── browser-mcp.lock         ← F2/F5/F7/F8 tự xếp hàng
│   ├── migration.lock           ← F1 DB migrate
│   └── module-{id}.lock         ← Cross-session safety
│
├── orchestrator-summary.md      ← Tổng kết orchestrator
└── phase-summary.md             ← Tổng kết tiếng Việt cho người dùng
```

---

# 🟢 Tình huống 1 — Chạy 1 feature

## Bước 1 — Khởi động hạ tầng

```bash
# DB + Redis
docker compose -f docker-compose.minimal.yml up -d

# Backend
dotnet run --project apps/backend/Eureka.Api &
# Đợi Swagger load: http://localhost:5048/swagger

# Frontend (cần cho F2/F7/F8 Playwright)
cd apps/erp-web && pnpm dev &
```

## Bước 2 — Chạy toàn bộ pipeline F1-F8

```bash
/wf-e2e-verify FEAT-EW-CRM-001 --auto
```

Orchestrator tự chạy tuần tự F1→F8, tự skip bước không cần thiết, tự fix issues khi có thể.

> Không có `--auto`: skill dừng ở F1 hỏi xác nhận nghiệp vụ. Trả lời xong tự chạy tiếp.

### Chỉ test code, không cần browser (explicit opt-out)
```bash
/wf-e2e-verify FEAT-EW-CRM-001 --auto --skip=F2,F5,F7,F8
```

Chạy F1 (code-based), bỏ qua F2/F5/F7/F8. Nhanh hơn, không cần FE chạy. **Lưu ý:** UI test sẽ KHÔNG được verify ở runtime — chỉ phù hợp khi user chấp nhận rủi ro (CI không có browser, smoke test API-only).

> Cờ cũ `--no-playwright` đã bị deprecated (v7.1.0) và IGNORED. Live browser BẮT BUỘC khi F2/F5/F7/F8 chạy — KHÔNG có đường thoát silent fallback static analysis. Muốn bỏ qua → dùng `--skip=` explicit.

## Bước 3 — Xem kết quả

```bash
# Dashboard realtime
/wf-e2e-verify FEAT-EW-CRM-001 --status

# Số issue theo loại
cat .mc-data/work/wf-e2e-verify/sessions/FEAT-EW-CRM-001-*/issues.json | jq '.summary'

# Chi tiết từng finding
ls .mc-data/work/wf-e2e-verify/sessions/FEAT-EW-CRM-001-*/findings/
```

---

## Jump đến sub-skill cụ thể

Sau khi có session, dùng `--from-step` để nhảy đến bước cần:

```bash
# Chỉ chạy lại Playwright (F7 + F8)
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F7

# Chỉ fix open issues (F6)
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F6

# Chỉ retest PENDING items (F5)
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F5

# Chỉ unblock blocked tests (F3)
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F3
```

---

# 🟠 Tình huống 2 — Chạy song song ≥2 feature

> **v7.0.0:** `--parallel-safe` không cần nữa — luôn bật. Chỉ cần mỗi session dùng **module khác nhau**.

## Quy tắc quan trọng

| Tình huống | Hành động |
|------------|-----------|
| Các session **khác module** (CRM + Finance + WMS) | OK — mở terminal và chạy bình thường |
| 2 session **cùng module** | **KHÔNG được** — skill block (E007). Chạy tuần tự |
| Session nào có Playwright | Tự động xếp hàng qua `browser-mcp.lock` — không cần đợi tay |

## Bước 1 — Khởi động hạ tầng (1 lần)

```bash
docker compose -f docker-compose.minimal.yml up -d
dotnet run --project apps/backend/Eureka.Api &
cd apps/erp-web && pnpm dev &
```

## Bước 2 — Mở 3 terminal, chạy đồng thời

**Terminal 1 — CRM:**
```
/wf-e2e-verify FEAT-EW-CRM-001 --auto
```

**Terminal 2 — Finance:**
```
/wf-e2e-verify FEAT-EW-FIN-001 --auto
```

**Terminal 3 — WMS:**
```
/wf-e2e-verify FEAT-EW-WMS-001 --auto
```

Cả 3 chạy song song an toàn vì:
- Mỗi session có seed namespace riêng → DB không đụng nhau
- Playwright xếp hàng qua `browser-mcp.lock` → không cookie conflict
- Migration serialize qua `migration.lock`

## Theo dõi tiến độ realtime

```bash
# Xem tất cả session đang chạy
ls .mc-data/work/wf-e2e-verify/sessions/

# Trạng thái F1-F8 của từng session
for s in .mc-data/work/wf-e2e-verify/sessions/*/e2e-status.json; do
  echo "=== $s ==="
  jq '.steps | to_entries[] | "\(.key): \(.value.status)"' "$s"
done

# Issues đang mở
for s in .mc-data/work/wf-e2e-verify/sessions/*/issues.json; do
  echo "=== $s ==="
  jq '.summary' "$s"
done
```

## Khắc phục sự cố khi song song

| Triệu chứng | Nguyên nhân | Cách xử lý |
|-------------|-------------|------------|
| `E007 Lock active` | 2 session cùng module hoặc session khác đang giữ lock | Đợi session kia xong, hoặc đổi sang feat khác module |
| `E012 migration.lock timeout` | Session khác kẹt khi `dotnet ef database update` | Kiểm tra terminal khác có lỗi không. Auto-clear sau 15 phút, hoặc xóa tay `migration.lock` |
| `E008 browser-mcp.lock timeout` (>30 min) | Session khác treo browser | Đóng browser Playwright của session đó, xóa lock |
| Audit log lẫn lộn | Không seed actor account riêng → fallback sysadmin | Seed `e2e_{namespace}@erktransport.local` (xem §Tạo actor accounts) |
| Lock cũ không tự xóa | Stale lock sau crash | TTL: module=180min, migration=15min, browser=30min. Xóa tay nếu cần |

---

# Tình huống thường gặp

### Xem trạng thái không chạy gì thêm
```
/wf-e2e-verify FEAT-EW-CRM-001 --status
```
Dashboard hiển thị 8 bước F1-F8 với status, duration, và counters (issues, blocks, implement-required).

### Resume sau khi bị gián đoạn
```
/wf-e2e-verify FEAT-EW-CRM-001 --resume
```
Skill tự đọc `e2e-status.json` → tìm bước tiếp theo → tiếp tục.

### Skip sub-skills không cần thiết
```bash
# Bỏ qua F7+F8 (không cần Playwright scenario + demo)
/wf-e2e-verify FEAT-EW-CRM-001 --auto --skip=F7,F8

# Bỏ qua F2 (không cần browser pre-scan)
/wf-e2e-verify FEAT-EW-CRM-001 --auto --skip=F2
```

### Retest case bị PENDING/SKIP do điều kiện ngoài tầm kiểm soát

Khi backend tắt lúc test, seed lỗi, thiếu permission, thiếu TMS data... sau khi khắc phục:

```bash
# Cách mới — jump thẳng F5
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F5

# Cách cũ — vẫn hoạt động
/wf-e2e-verify FEAT-EW-CRM-001 --retest --session=FEAT-EW-CRM-001-20260512-1430
```

F5 sẽ scan tất cả reports tìm PENDING/SKIP, re-check điều kiện, chỉ retest item nào điều kiện đã resolve.

### Fix issues sau khi test xong

```bash
# Cách mới — jump thẳng F6
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F6

# Cách cũ (fix theo report cụ thể) — vẫn hoạt động
/wf-e2e-verify FEAT-EW-CRM-001 \
  --fix=.mc-data/work/wf-e2e-verify/sessions/FEAT-EW-CRM-001-20260512-1430/findings/api-test-report.md \
  --session=FEAT-EW-CRM-001-20260512-1430
```

### Chạy lại Playwright cho test-scenario và demo
```bash
/wf-e2e-verify FEAT-EW-CRM-001 --resume --from-step=F7
```

### Hiển thị browser khi test (debug mode)
```bash
/wf-e2e-verify FEAT-EW-CRM-001 --auto --show-browser
```

### Test trên mobile viewport
```bash
/wf-e2e-verify FEAT-EW-CRM-001 --auto --mobile
```

### Giới hạn implement trong F4 (feature lớn)
```bash
# Chỉ implement tối đa 3 item ưu tiên cao nhất (P0 first)
/wf-e2e-verify FEAT-EW-CRM-001 --auto --max-impl-items=3
```

---

## Những điều skill KHÔNG làm

- Performance / load test
- Security / penetration test
- Code quality / clean code review
- SEO, analytics
- Offline mode, animation

---

## Tạo actor accounts cho parallel mode (tùy chọn)

Bỏ qua nếu không cần audit isolation. Skill tự fallback về `sysadmin@erktransport.local` với WARNING.

```bash
# Vào DB
docker exec -it eureka-postgres-1 psql -U eureka -d eureka

# Tạo account (thay <NAMESPACE> bằng prefix của session, vd FEATEWCR)
INSERT INTO identity.users (id, email, password_hash, full_name, is_active, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'e2e_<NAMESPACE>@erktransport.local',
  -- password "E2eTest@<NAMESPACE>" hash bằng bcrypt round 12
  '<bcrypt_hash_here>',
  'E2E Test Actor <NAMESPACE>',
  true, now(), now()
);

-- Gán role SystemAdmin
INSERT INTO identity.user_roles (user_id, role_id)
SELECT u.id, r.id FROM identity.users u, identity.roles r
WHERE u.email = 'e2e_<NAMESPACE>@erktransport.local' AND r.code = 'SystemAdmin';
```

> Cách tốt hơn: tự động seed qua `apps/backend/Eureka.Api/Seeders/UserSeeder.cs` khi env `EUREKA_E2E_SEED=true`.

---

## Cheat sheet

| Mục tiêu | Lệnh |
|----------|------|
| **Chạy đầy đủ** F1-F8, tự động | `/wf-e2e-verify <FEAT> --auto` |
| **Chỉ code test** (không browser, user chịu rủi ro) | `/wf-e2e-verify <FEAT> --auto --skip=F2,F5,F7,F8` |
| **Xem trạng thái** pipeline | `/wf-e2e-verify <FEAT> --status` |
| **Resume** bị gián đoạn | `/wf-e2e-verify <FEAT> --resume` |
| **Jump** đến bước cụ thể | `/wf-e2e-verify <FEAT> --resume --from-step=F6` |
| **Skip** sub-skills không cần | `/wf-e2e-verify <FEAT> --auto --skip=F7,F8` |
| **Retest** PENDING items | `/wf-e2e-verify <FEAT> --resume --from-step=F5` |
| **Fix** open issues | `/wf-e2e-verify <FEAT> --resume --from-step=F6` |
| **Playwright** scenario + demo | `/wf-e2e-verify <FEAT> --resume --from-step=F7` |
| **Hiện browser** khi Playwright | `/wf-e2e-verify <FEAT> --auto --show-browser` |
| **Mobile viewport** | `/wf-e2e-verify <FEAT> --auto --mobile` |
| **Song song** (khác module) | Mở N terminal: `/wf-e2e-verify <FEAT-N> --auto` |

---

*Cập nhật: 2026-05-14 | Skill version: 7.0.0 — orchestrator + 8 sub-skills F1-F8*
