# 10 — Vietnamese Keyword Pool Cho IPS Domain Detection

> **Trạng thái:** Design v2.1 · **Draft** · Bắt buộc implement trong Phase C
> **Đọc trước:** [05-profiles-ips.md](05-profiles-ips.md)
> **Mục đích:** Bổ sung signal detection cho dự án Việt Nam — nơi directory names, variable names, comments dùng tiếng Việt không dấu hoặc viết tắt theo convention địa phương.

---

## 1. Vấn Đề

IPS v2.0 detect domain qua 5 loại signals:
1. Package dependency (`decimal.js`, `fhir`, ...)
2. Directory name (`billing/`, `patient/`, ...)
3. Import pattern (`invoice|payment|tax`)
4. File pattern (`*.ledger.ts`)
5. Framework detect (`healthcare-fhir`)

**Tất cả 5 loại đều English keyword-based.** Dự án Việt Nam phổ biến dùng:
- `qlkh/` = quản lý khách hàng (sales/CRM)
- `hoadon/` = hoá đơn (finance)
- `qlns/` = quản lý nhân sự (HR)
- `chamcong/` = chấm công (HR)
- `nhapkho/`, `xuatkho/` = nhập/xuất kho (operations)
- `baohiem/` = bảo hiểm (insurance)
- `kho/` = kho (operations/logistics)
- `gd/` = giao dịch (finance)

→ IPS v2.0 sẽ **miss hoàn toàn** các dự án này, fallback `business-analyst` only, **mất lợi thế domain expert** (giảm confidence M3 từ 0.82 → 0.65).

---

## 2. Vietnamese Keyword Pool (per Domain)

### 2.1 Core 7 (v4.1 BACKWARD-COMPAT)

#### Finance

| Keyword VN | Nghĩa | Weight | Context |
|-----------|-------|--------|---------|
| `hoadon`, `hoa-don` | hoá đơn | 0.3 | dir, file, import |
| `thanhtoan`, `thanh-toan` | thanh toán | 0.25 | dir, file, import |
| `giaodich`, `giao-dich`, `gd` | giao dịch | 0.2 | dir (`gd/` viết tắt), file |
| `congno`, `cong-no` | công nợ | 0.3 | dir, file |
| `sotu`, `so-tu`, `tuquy` | sổ thu, thủ quỹ | 0.25 | dir, file |
| `ketoan`, `ke-toan`, `kt` | kế toán | 0.3 | dir, file |
| `thue`, `thuevat`, `vat` | thuế, thuế VAT | 0.25 | dir, file, import |
| `nganhang`, `ngan-hang`, `nh` | ngân hàng | 0.2 | dir, file |
| `ngansach`, `ngan-sach` | ngân sách | 0.2 | dir, file |
| `luong`, `bangluong` | lương, bảng lương | 0.15 | dir (conflict HR — cần cross-check) |

**Multi-signal boost:** Nếu ≥3 keyword trong cùng 1 module → +0.15 boost.

#### HR

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `nhansu`, `nhan-su`, `ns`, `qlns` | nhân sự, QL nhân sự | 0.4 |
| `chamcong`, `cham-cong`, `cc` | chấm công | 0.4 |
| `bangluong`, `bang-luong` | bảng lương | 0.4 |
| `nghiphep`, `nghi-phep` | nghỉ phép | 0.35 |
| `nhanvien`, `nhan-vien`, `nv` | nhân viên | 0.25 |
| `tuyendung`, `tuyen-dung` | tuyển dụng | 0.3 |
| `daotao`, `dao-tao`, `dt` | đào tạo | 0.25 |
| `hopdongld`, `hop-dong-ld`, `hdld` | hợp đồng lao động | 0.3 |
| `bhxh`, `baohiemxh` | bảo hiểm xã hội | 0.3 |

#### Sales / CRM

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `khachhang`, `khach-hang`, `kh`, `qlkh` | khách hàng | 0.4 |
| `banhang`, `ban-hang`, `bh` | bán hàng | 0.35 |
| `donhang`, `don-hang`, `dh` | đơn hàng | 0.35 |
| `baogia`, `bao-gia`, `bg` | báo giá | 0.3 |
| `hopdong`, `hop-dong`, `hd` | hợp đồng | 0.25 |
| `cohoi`, `co-hoi` | cơ hội (opportunity) | 0.25 |
| `chamsoc`, `cskh` | chăm sóc khách hàng | 0.3 |

#### Procurement

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `muahang`, `mua-hang`, `mh`, `muasam` | mua hàng, mua sắm | 0.4 |
| `nhacungcap`, `nha-cung-cap`, `ncc` | nhà cung cấp | 0.4 |
| `dathang`, `dat-hang`, `donmuahang` | đặt hàng, đơn mua hàng | 0.35 |
| `yeucauchao`, `yeu-cau-chao`, `ycbg` | yêu cầu báo giá (RFQ) | 0.3 |
| `daugia`, `dau-gia` | đấu giá | 0.25 |

#### E-commerce

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `giohang`, `gio-hang`, `cart` | giỏ hàng | 0.35 |
| `sanpham`, `san-pham`, `sp` | sản phẩm | 0.3 |
| `danhmuc`, `danh-muc`, `dm`, `category` | danh mục | 0.2 (ambiguous) |
| `thanhtoan`, `thanh-toan` | thanh toán | 0.25 (cross finance) |
| `vanchuyen`, `van-chuyen`, `vc` | vận chuyển | 0.25 |
| `khuyenmai`, `khuyen-mai`, `km`, `voucher` | khuyến mãi | 0.25 |

#### Operations (Warehouse / Inventory)

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `kho`, `quanlykho`, `qlkho`, `warehouse` | kho | 0.4 |
| `nhapkho`, `nhap-kho` | nhập kho | 0.4 |
| `xuatkho`, `xuat-kho` | xuất kho | 0.4 |
| `tonkho`, `ton-kho` | tồn kho | 0.4 |
| `hanghoa`, `hang-hoa`, `hh` | hàng hoá | 0.25 |
| `vattu`, `vat-tu`, `vt` | vật tư | 0.3 |
| `dieuchuyen`, `dieu-chuyen` | điều chuyển | 0.3 |
| `kiemke`, `kiem-ke` | kiểm kê | 0.3 |

#### Compliance

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `tuanthu`, `tuan-thu` | tuân thủ | 0.4 |
| `kiemtoan`, `kiem-toan`, `kt` | kiểm toán | 0.35 (conflict finance "kt" → cần context) |
| `quyche`, `quy-che` | quy chế | 0.3 |
| `phaply`, `phap-ly`, `pl` | pháp lý | 0.3 |
| `bienban`, `bien-ban`, `bb` | biên bản | 0.25 |
| `ruiro`, `rui-ro`, `rr` | rủi ro | 0.3 |

### 2.2 Optional 7 (v5.0 mở rộng)

#### Healthcare

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `benhnhan`, `benh-nhan`, `bn` | bệnh nhân | 0.5 |
| `khambenh`, `kham-benh`, `kb` | khám bệnh | 0.4 |
| `hosoba`, `ho-so-ba`, `hsba` | hồ sơ bệnh án | 0.5 |
| `donthuoc`, `don-thuoc`, `keđon`, `kedon` | đơn thuốc, kê đơn | 0.45 |
| `bhyt`, `baohiemyte`, `bao-hiem-y-te` | bảo hiểm y tế | 0.5 |
| `xetnghiem`, `xet-nghiem`, `xn` | xét nghiệm | 0.4 |
| `chuan-doan`, `chandoan`, `cd` | chẩn đoán | 0.4 |
| `duoc`, `duocpham`, `dp` | dược, dược phẩm | 0.4 |
| `nhapvien`, `xuatvien` | nhập/xuất viện | 0.4 |

#### Logistics

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `vanchuyen`, `van-chuyen`, `vc` | vận chuyển | 0.4 |
| `giaonhan`, `giao-nhan`, `gn` | giao nhận | 0.4 |
| `haiquan`, `hai-quan`, `hq` | hải quan | 0.5 |
| `xuatnhapkhau`, `xuat-nhap-khau`, `xnk` | xuất nhập khẩu | 0.5 |
| `container`, `cont` | container | 0.35 |
| `vandon`, `van-don` | vận đơn | 0.4 |
| `lenhgiao`, `lenh-giao` | lệnh giao | 0.35 |
| `tuyenduong`, `tuyen-duong` | tuyến đường | 0.3 |
| `khobai`, `kho-bai` | kho bãi | 0.35 |

#### Manufacturing

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `sanxuat`, `san-xuat`, `sx` | sản xuất | 0.4 |
| `dinhmuc`, `dinh-muc`, `bom` | định mức, BOM | 0.4 |
| `daychuyen`, `day-chuyen`, `dc` | dây chuyền | 0.35 |
| `lenhsx`, `lenh-sx`, `congviec` | lệnh sản xuất, công việc | 0.35 |
| `nguyenlieu`, `nguyen-lieu`, `nl` | nguyên liệu | 0.3 |
| `thanhpham`, `thanh-pham`, `tp` | thành phẩm | 0.35 |
| `banthanhpham`, `ban-thanh-pham`, `btp` | bán thành phẩm | 0.3 |

#### Retail

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `cuahang`, `cua-hang`, `ch` | cửa hàng | 0.4 |
| `diemban`, `diem-ban`, `db` | điểm bán | 0.4 |
| `thungan`, `thu-ngan`, `pos` | thu ngân, POS | 0.4 |
| `thetv`, `the-thanh-vien`, `loyalty` | thẻ thành viên | 0.35 |
| `ca`, `ca-ban-hang`, `shift` | ca bán hàng | 0.3 |
| `caidat`, `cai-dat` | cài đặt (ambiguous, lower weight) | 0.1 |

#### Legal

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `hopdong`, `hop-dong`, `hd`, `contract` | hợp đồng (cross-domain — context required) | 0.25 (legal) / 0.25 (sales) |
| `phaply`, `phap-ly`, `pl` | pháp lý | 0.45 |
| `dieukhoan`, `dieu-khoan`, `dk` | điều khoản | 0.4 |
| `thoathuan`, `thoa-thuan` | thoả thuận | 0.35 |
| `tranhchap`, `tranh-chap` | tranh chấp | 0.4 |
| `trongtai`, `trong-tai` | trọng tài | 0.35 |

#### Insurance

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `baohiem`, `bao-hiem`, `bh` | bảo hiểm | 0.5 |
| `boithuong`, `boi-thuong` | bồi thường | 0.5 |
| `hopdongbh`, `hop-dong-bh`, `hdbh` | hợp đồng bảo hiểm | 0.5 |
| `phibh`, `phi-bh`, `premium` | phí bảo hiểm | 0.4 |
| `thamdinh`, `tham-dinh` | thẩm định | 0.35 |
| `nhanthou`, `nhan-tho`, `phinhatho` | nhân thọ, phi nhân thọ | 0.4 |
| `daily`, `dai-ly` | đại lý | 0.3 |

#### Education

| Keyword VN | Nghĩa | Weight |
|-----------|-------|--------|
| `hocvien`, `hoc-vien`, `hv`, `hocsinh` | học viên, học sinh | 0.5 |
| `khoahoc`, `khoa-hoc`, `kh` | khoá học | 0.5 |
| `giaovien`, `giao-vien`, `gv` | giáo viên | 0.5 |
| `lophoc`, `lop-hoc`, `lop` | lớp học | 0.45 |
| `thoikhoabieu`, `tkb` | thời khoá biểu | 0.4 |
| `diemdanh`, `diem-danh` | điểm danh | 0.35 |
| `baithi`, `bai-thi`, `bai-kiem-tra` | bài thi, bài kiểm tra | 0.4 |
| `chungchi`, `chung-chi` | chứng chỉ | 0.35 |
| `hocphi`, `hoc-phi` | học phí | 0.4 |

---

## 3. Detection Algorithm

### 3.1 Normalization

Tiếng Việt có dấu → bỏ dấu để match consistent:

```python
def normalize_vn(text: str) -> str:
    """Chuẩn hoá tiếng Việt: bỏ dấu, lowercase, remove separator."""
    # Lowercase
    text = text.lower()
    # Remove Vietnamese diacritics (decomposition then strip combining marks)
    text = unicodedata.normalize('NFD', text)
    text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
    # Normalize separators: - _ / . → remove
    text = re.sub(r'[-_/.]', '', text)
    # Remove đ → d
    text = text.replace('đ', 'd')
    return text
```

**Ví dụ:**
- `quản-lý-khách-hàng/` → `quanlykhachhang`
- `Hóa_Đơn` → `hoadon`
- `Nhập-Kho` → `nhapkho`

### 3.2 Matching Rules

1. **Exact match** trong normalized form → weight như bảng §2.
2. **Substring match** (keyword là prefix/suffix của normalized) → weight × 0.7.
3. **Multi-signal boost:** cùng domain có ≥3 keyword khác nhau trong cùng module → +0.15.
4. **Cross-domain penalty:** keyword xuất hiện trong ≥2 domain (VD `hopdong` xuất hiện cả sales và legal) → weight × 0.6, cần signal khác để tie-break.
5. **Viết tắt (2-3 ký tự) match exact only:** `ns`, `kh`, `hd`, `bh` — không substring match (noise cao).

### 3.3 Integration trong IPS

```python
def detect_domain_vn(module_files: list, module_name: str) -> list[DomainSignal]:
    """Detect domain hints từ tên module + file names (VN + EN)."""
    signals = []
    
    # Normalize module name
    norm_mod = normalize_vn(module_name)
    
    # Check English keywords (existing)
    en_signals = detect_domain_en(module_files, module_name)
    signals.extend(en_signals)
    
    # Check Vietnamese keywords (MỚI)
    for domain, keywords in VN_KEYWORD_POOL.items():
        for kw in keywords:
            norm_kw = normalize_vn(kw['keyword'])
            if norm_kw in norm_mod:
                weight = kw['weight']
                if not kw['exact_only'] and norm_kw == norm_mod:
                    pass  # exact match — keep weight
                elif kw['exact_only'] and norm_kw != norm_mod:
                    continue  # skip — viết tắt cần exact
                else:
                    weight *= 0.7  # substring
                signals.append(DomainSignal(domain=domain, confidence=weight, source=f'vn:{kw["keyword"]}'))
    
    # Multi-signal boost
    signals = apply_multi_signal_boost(signals)
    
    # Cross-domain penalty
    signals = apply_cross_domain_penalty(signals)
    
    return signals
```

### 3.4 Output Schema Extension

`domain-hints.json` v2.1 thêm field `language`:

```json
{
  "detected_domains": [
    {
      "domain": "sales",
      "confidence": 0.82,
      "language": "vn",
      "signals": [
        {"type": "directory_name", "value": "qlkh/", "weight": 0.4, "lang": "vn"},
        {"type": "file_pattern", "value": "donhang_*.ts", "weight": 0.35, "lang": "vn"}
      ],
      "recommended_expert": "sales-expert"
    }
  ]
}
```

---

## 4. Storage Location

### 4.1 Keyword Pool File

- **Path:** `.claude/skills/workflow/wf-legacy-scan/_shared/ips/vietnamese-keywords.json`
- **Schema version:** `vn-keywords-v1`
- **Maintainability:** JSON để dễ update không cần đổi code. IPS load 1 lần per scan.

```json
{
  "$schema": "vn-keywords-v1",
  "version": "1.0",
  "last_updated": "2026-04-22",
  "normalization": {
    "strip_diacritics": true,
    "lowercase": true,
    "d_to_d": true,
    "strip_separators": ["-", "_", "/", "."]
  },
  "domains": {
    "finance": {
      "keywords": [
        {"keyword": "hoadon", "variants": ["hoa-don", "hóa-đơn"], "weight": 0.3, "exact_only": false},
        {"keyword": "thanhtoan", "variants": ["thanh-toan", "thanh-toán"], "weight": 0.25, "exact_only": false}
      ],
      "abbreviations": [
        {"keyword": "gd", "weight": 0.2, "exact_only": true}
      ]
    }
  }
}
```

### 4.2 Bash Support (L2 Assessment Script)

Bash `legacy-scan-assess.sh` cần helper để match keyword. Tái dùng `legacy-scan-common.sh`:

```bash
# In legacy-scan-common.sh
normalize_vn() {
  local text="$1"
  # Strip diacritics (requires iconv hoặc Python fallback)
  if command -v python3 &>/dev/null; then
    echo "$text" | python3 -c "
import sys, unicodedata, re
t = sys.stdin.read().strip().lower()
t = unicodedata.normalize('NFD', t)
t = ''.join(c for c in t if unicodedata.category(c) != 'Mn')
t = t.replace('đ', 'd')
t = re.sub(r'[-_/.]', '', t)
print(t)
"
  else
    # Fallback: basic lowercase + strip separators (no diacritic strip)
    echo "$text" | tr '[:upper:]' '[:lower:]' | tr -d '-_/.'
  fi
}

detect_domain_vn() {
  local module_name="$1"
  local output_json="$2"
  local normalized
  normalized=$(normalize_vn "$module_name")
  
  # Read VN keyword pool
  local pool=".claude/skills/workflow/wf-legacy-scan/_shared/ips/vietnamese-keywords.json"
  [[ ! -f "$pool" ]] && { log_warn "VN keyword pool not found at $pool"; return 0; }
  
  # Match per domain via jq
  jq -r --arg name "$normalized" '
    .domains | to_entries[] | .key as $domain |
    .value.keywords[] | select(.keyword as $kw | $name | contains($kw)) |
    "\($domain)\t\(.keyword)\t\(.weight)"
  ' "$pool" >> "$output_json"
}
```

---

## 5. Test Cases (Fixture cần chuẩn bị)

### 5.1 Fixture VN Small Project

```
qlkh-demo/
├── qlkh/          # customer management
├── qlns/          # HR
├── chamcong/      # attendance
├── hoadon/        # invoicing
└── bangluong/     # payroll
```

**Expected:**
- `sales: 0.7+` (qlkh strong)
- `hr: 0.75+` (qlns + chamcong + bangluong multi-signal boost)
- `finance: 0.35+` (hoadon alone) — below 0.6 threshold → fallback business-analyst only

### 5.2 Fixture Mixed VN/EN

```
project-mixed/
├── src/
│   ├── customer/          # EN
│   ├── sales/             # EN
│   └── modules/
│       ├── qlkho/         # VN — operations
│       ├── nhapxuatkho/   # VN — operations
│       └── billing/       # EN — finance
```

**Expected:**
- `sales: 0.6+` (customer + sales EN)
- `operations: 0.7+` (qlkho + nhapxuatkho VN multi-signal)
- `finance: 0.4` (billing alone) → below threshold → business-analyst only

### 5.3 Fixture VN With Diacritics

```
du-an-vn/
├── Quản_Lý_Khách_Hàng/
├── Hóa_Đơn/
└── Nhập_Kho/
```

**Expected (sau normalization):**
- `quanlykhachhang` → sales 0.4
- `hoadon` → finance 0.3
- `nhapkho` → operations 0.4

---

## 6. Scope Limitations

1. **Chỉ Core 7 + Optional 7 domains** — không phủ all 25 business agents. Lý do: giới hạn maintenance keyword pool.
2. **Không support dialect/region-specific** (Bắc/Trung/Nam) — dùng keyword phổ biến nhất.
3. **Không handle typos** — user phải đặt tên module đúng chính tả tiếng Việt.
4. **Không hỗ trợ camelCase tiếng Việt** (VD `khachHang`) — user nên dùng kebab-case hoặc snake_case.
5. **Keyword pool cần update** khi thêm domain mới — maintainer responsibility.

---

## 7. Phase C Implementation Checklist

- [ ] Tạo file `.claude/skills/workflow/wf-legacy-scan/_shared/ips/vietnamese-keywords.json`
- [ ] Populate với 14 domains × ~8 keywords avg = ~110 keywords
- [ ] Thêm `normalize_vn()` + `detect_domain_vn()` vào `legacy-scan-common.sh`
- [ ] Update `legacy-scan-assess.sh` gọi `detect_domain_vn()`
- [ ] Update IPS-A algorithm (inline trong procedure file hoặc `_shared/ips/` Python module — xem Patch 3)
- [ ] Extend `domain-hints.json` schema thêm field `language`
- [ ] Tạo 3 test fixtures (§5.1-5.3)
- [ ] Validate trên fixture: precision ≥80%, recall ≥70% cho domain detection VN

---

## 8. Future Work (v5.1+)

- Machine learning domain detection từ code content (AST imports, function signatures).
- Hybrid matching: combine keyword + embeddings (dùng small VN BERT).
- Community keyword contribution qua pull request.
- Support cho các ngôn ngữ khác trong ASEAN (Thai, Indonesian).
