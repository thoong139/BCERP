---
$schema: gap-analysis-v1
migrate_id: {MIGRATE_ID}
source_module: {SOURCE_MODULE}
source_system: {SOURCE_SYSTEM}
target_system: {TARGET_SYSTEM}
target_module: {TARGET_MODULE}
---

# Phan tich Gap — {SOURCE_MODULE} → {TARGET_MODULE}

## 1. Tong quan module cu

<!-- POPULATE: Mo ta ngan gon module cu — muc dich, pham vi, cong nghe -->

## 2. Module moi hien trang

<!-- POPULATE: Trang thai hien tai cua target module trong EUREKA (tu registry) -->

## 3. Danh sach feature

| # | Feature cu | Loai | API endpoints | Entities | Trang thai moi |
|---|-----------|------|---------------|----------|----------------|
| 1 | {ten feature} | CRUD / business rule / validation / integration / UI | {endpoints} | {entities} | thieu / co 1 phan / da co / trung lap |
| 2 | ... | | | | |

## 4. Phan tich khac biet (Gap)

### 4.1. Thieu (Missing)

<!-- POPULATE: Features/entities/API khong co trong he thong moi -->

### 4.2. Khac biet (Different)

<!-- POPULATE: Features co trong ca 2 nhung implement khac nhau -->

### 4.3. Trung lap (Overlap)

<!-- POPULATE: Features cua module cu da co san trong EUREKA -->

## 5. Dependencies

<!-- POPULATE: Module cu phu thuoc vao nhung gi? Thu vien, external service, module khac? -->

## 6. Khuyen nghi tong the

<!-- POPULATE: Khuyen nghi chung ve cach tiep can migration -->
