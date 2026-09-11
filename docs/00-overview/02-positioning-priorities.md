# 02 — Định vị & Ưu tiên

> **Mức độ ràng buộc:** Tham khảo (overview) — concept này **bắt buộc tuân thủ** trong mọi quyết định kỹ thuật
> **File gốc:** [`docs/mcv3-development-priorities.md`](../mcv3-development-priorities.md), [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §0
> **Mục đích:** Khung quyết định khi có xung đột giữa chất lượng và tốc độ — bài đọc bắt buộc cho contributor

---

## 1. Định vị MCV3

MCV3 là **bộ công cụ hỗ trợ phát triển phần mềm cho người không chuyên** trên IDE Claude.

Repo này KHÔNG chỉ tạo ra code. Nó tạo ra:
- **Hệ thống tài liệu** (Phase 0-6) — đủ rõ để doanh nghiệp vận hành
- **Quy trình** (43 skills + 7 phases) — đảm bảo không skip bước
- **Đội ngũ agent/skill** (62 chuyên gia ảo) — biến ý tưởng thành sản phẩm

**Hệ quả định vị:**

1. **Tài liệu là tài sản vận hành thật**, không phải bản nháp tạm thời
2. **Mọi tối ưu tốc độ chỉ có giá trị khi không làm giảm chất lượng và truy vết**

---

## 2. Thứ tự ưu tiên BẮT BUỘC

```
┌─────────────────────────────────────────────────────────────┐
│  ƯU TIÊN 1: Độ chính xác, nhất quán, đầy đủ, kỹ thuật,    │
│              bảo mật                                          │
│              ▲                                                 │
│              │ (phải bảo vệ trước)                            │
│              │                                                 │
│  ƯU TIÊN 2: Tốc độ xử lý + song song hóa                    │
└─────────────────────────────────────────────────────────────┘
```

### Ưu tiên 1 — Chi tiết

MCV3 PHẢI ưu tiên:
- **Tài liệu logic, thống nhất**, có căn cứ rõ ràng giữa các phase
- **Code bám sát requirement**, không bỏ sót tính năng
- **Chất lượng kỹ thuật cao**: đúng logic, build được, test được, an toàn bảo mật
- **Đầu ra đủ rõ** cho doanh nghiệp vận hành VÀ đủ chuẩn cho AI làm context phát triển tiếp

### Ưu tiên 2 — Chi tiết

CHỈ sau khi bảo vệ Ưu tiên 1, mới tối ưu:
- Thời gian phân tích và sinh tài liệu
- Thời gian triển khai code
- Thời gian verify và sửa lỗi
- Mức độ song song hóa giữa agents/phases/workstreams

### Quy tắc chốt

> **Nếu xung đột giữa tốc độ và chất lượng → Chất lượng thắng.**
> Tốc độ chỉ được tối ưu trong **vùng an toàn của chất lượng**.

Ánh xạ rule chính:
- **CORE-023:** KHÔNG đánh đổi correctness/completeness/security để lấy tốc độ
- **CORE-024:** Mọi output downstream PHẢI có căn cứ từ upstream docs + registry
- **CORE-025:** Song song hóa CHỈ khi có owner rõ, write scope tách biệt, contract ổn định, re-verification

---

## 3. Năm hệ quả thực tế

### 3.1. Chuỗi truy vết xuyên phase

Mỗi output sinh ra sau phải chỉ rõ nó dựa trên input nào trước đó:

```
Ý tưởng → Requirements → Features → Design → Task → Code → Verify → Deployment
   │            │             │          │        │       │       │           │
   └─Phase 0──┘─Phase 1──────┘─Phase 2──┘─Phase 3┘─Phase 5┘─...─┘─Phase 6───┘
```

Áp dụng thực tế:
- Tài liệu phase sau phải đọc + bám tài liệu phase trước
- Mọi thay đổi lớn phải phản ánh vào `req-registry.json` (SSOT)
- Code phải trace được tới REQ-ID + FEAT-ID
- Verify phải đối chiếu cả code lẫn tài liệu

### 3.2. Tài liệu vừa cho doanh nghiệp, vừa cho AI

Tài liệu tốt trong MCV3 không chỉ "đúng", mà còn:

| Đối tượng | Yêu cầu |
|----------|---------|
| Người vận hành doanh nghiệp | Rõ ràng, đọc hiểu được |
| AI Claude Code | Ngắn gọn để không loãng context |
| AI tiếp tục phát triển | Đủ cấu trúc để trích xuất chính xác |
| Cả 2 đối tượng | Tránh trùng lặp thông tin giữa nhiều file |

Nguyên tắc thực thi:
- Mỗi file chỉ giữ đúng mục đích của phase/module/feature
- KHÔNG copy-paste nguyên văn — dùng reference
- Quyết định, giả định, ràng buộc, open issues tách rõ trong section riêng

### 3.3. Definition of Done — Tài liệu

Tài liệu chỉ DONE khi:
- ✅ Không mâu thuẫn với registry và tài liệu trước
- ✅ Diễn đạt đủ để doanh nghiệp hiểu + kiểm soát
- ✅ Đủ chặt để AI tiếp tục dùng mà không tự suy diễn
- ✅ Chỉ rõ nguồn căn cứ, giả định, giới hạn
- ✅ Không thừa thông tin làm nặng context

### 3.4. Definition of Done — Code

Code chỉ DONE khi:
- ✅ Map được tới requirements/features liên quan (REQ-ID comment)
- ✅ Không thiếu hành vi đã cam kết
- ✅ Không có lỗi logic/build/test/bảo mật rõ ràng
- ✅ Dependencies rà soát ở mức hợp lý
- ✅ Trạng thái tài liệu + registry đồng bộ lại

### 3.5. Song song hóa phải có kế hoạch

Song song hóa là **công cụ tăng tốc, không phải mục tiêu tự thân**.

CHỈ song song khi trả lời rõ:
- Phần việc nào độc lập?
- Ai sở hữu mỗi output?
- Ranh giới ghi file ở đâu?
- Contract/interface nào đã chốt?
- Bước verify sau khi hợp nhất là gì?

Chưa trả lời được → **KHÔNG nên song song hóa.**

---

## 4. Mẫu song song hóa AN TOÀN

### 4.1. Song song theo miền nghiệp vụ

Phù hợp khi: phân tích nhiều department, nhiều module độc lập, audit nhiều nhóm agent.

**Điều kiện:** Mỗi luồng đọc cùng SSOT (registry) nhưng ghi vào subfolder riêng. Sau merge, audit lại cross-reference.

### 4.2. Song song frontend/backend sau khi chốt API contract

Phù hợp khi: API schema đã version + freeze. Frontend/backend cùng implement theo contract.

**Điều kiện:** OpenAPI/JSON Schema đã chốt. Cả 2 phía PHẢI verify với mock server.

### 4.3. Song song docs/code/QA cùng bám 1 SSOT

Phù hợp khi: cùng 1 feature, 3 hoạt động (write docs, implement, write tests) chạy đồng thời.

**Điều kiện:** Tất cả 3 cùng đọc 1 task file. Sync checkpoint sau khi 1 hoạt động chốt.

---

## 5. Khi nào KHÔNG được song song

| Tình huống | Lý do |
|-----------|-------|
| 2 agents cùng ghi 1 file output | Race condition, không deterministic |
| Schema chưa freeze | Lãng phí khi schema đổi |
| Owner không rõ ràng | "Cha chung không ai khóc" — mỗi output cần owner |
| Không có verify sau merge | Không biết kết quả có đúng không |
| Dependency chéo phức tạp | Cascading retry sẽ mất nhiều hơn tiết kiệm |

---

## 6. Ví dụ Pass/Fail ưu tiên

### ✅ PASS — Chất lượng thắng

```
Phase 4 (Find Bugs) chạy 10 lane agents song song.
Lane QD3 (Security) báo timeout sau 8 phút.
Auto-fix retry 2 lần đều fail.

Tùy chọn:
  A) Cut loss, advance phase 5 với 9/10 lane data
  B) Stop, ask user: scope hẹp hơn / tăng timeout / skip lane

Chọn (B) — Chất lượng thắng.
Vì: cut loss = mất 1 dimension data → false healthy → cascade.
```

### ❌ FAIL — Tốc độ thắng sai cách

```
Phase 5 (Plan modules) cần đọc 50 feature specs.
Đọc tuần tự ~10 phút. Cố tình parallelize 10 worker đọc cùng lúc.

Worker 1-10 cùng update `dependency-graph.md` song song.
→ Race condition, file cuối cùng overwrite mất 9 worker
→ Output corrupted, không biết để fix

Vi phạm: 1 file = 1 writer (CORE-037 §7)
```

---

## 7. Khung quyết định khi có doubt

```
Tôi muốn làm X để nhanh hơn. Có nên không?
│
├─ X có giảm correctness/completeness/security?
│   ├─ CÓ → KHÔNG làm (Ưu tiên 1 bảo vệ)
│   └─ KHÔNG ↓
│
├─ X có làm output downstream mất căn cứ upstream?
│   ├─ CÓ → KHÔNG làm (CORE-024)
│   └─ KHÔNG ↓
│
├─ X cần song song hóa?
│   ├─ CÓ → Kiểm tra 5 câu hỏi §3.5
│   │       └─ Trả lời đủ 5 → OK, làm
│   │       └─ Thiếu câu nào → KHÔNG làm
│   └─ KHÔNG → LÀM (nằm trong vùng an toàn)
│
└─ Có verify-checkpoint sau X không?
    ├─ KHÔNG → THÊM verify-checkpoint trước khi làm
    └─ CÓ → OK, làm
```

---

## 8. Trách nhiệm theo vai trò

### Skill author

- Đọc + tuân thủ 38 CORE rules + 4 BHV principles
- Mọi output tuân thủ POST-GATE T1→T4
- KHÔNG skip phase
- KHÔNG đánh đổi correctness cho tốc độ

### Agent author

- Tuân thủ 8-section prompt template (CORE-037)
- Output spot-check trước khi advance (CORE-029)
- 1 file = 1 writer
- KHÔNG override Safe-Write của skill

### Reviewer (PR review)

- Block PR nếu vi phạm Ưu tiên 1
- Yêu cầu ADR khi có exception
- Verify cross-skill contract + Protocol 21 sync

### End user

- Tin cậy quy trình — không skip phase
- Đọc Phase reports tiếng Việt
- Xác nhận CDG (Critical Decision Gates) khi được hỏi
- KHÔNG yêu cầu AI "làm nhanh hơn bằng cách bỏ qua check"

---

## 9. Khi không thể follow priorities

Hiếm khi xảy ra — nhưng nếu phải:

| Tình huống | Quy trình |
|-----------|-----------|
| Production incident urgent | Tạm thời bypass POST-GATE T3 → fix → audit lại sau 24h |
| Customer demo 30 phút nữa | Skip stakeholder review → demo → review chính thức sau |
| Compliance freeze period | Chỉ critical bug fix, skip Phase 4 documentation update tạm thời |

**Trong mọi trường hợp:**
- Viết ADR ghi rõ lý do bypass
- Set follow-up issue để fix root cause
- Đồng ý từ stakeholder (không tự quyết)
- Đăng ký exception trong `04-skill-design/{skill}/08-tradeoffs-adr.md`

---

## 10. Liên kết

- **Canonical:** [`docs/mcv3-development-priorities.md`](../mcv3-development-priorities.md)
- **CORE rules:** [`.claude/rules/00-core.md`](../../.claude/rules/00-core.md) §0 (CORE-023..025)
- **Behavioral principles:** [`.claude/rules/00-behavioral.md`](../../.claude/rules/00-behavioral.md)
- **Trace patterns:** [`../02-standards/01-core-rules-index.md`](../02-standards/01-core-rules-index.md) §2
- **Project description:** [`01-project-description.md`](01-project-description.md)
