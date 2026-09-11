---
$schema: entity-mapping-v1
migrate_id: {MIGRATE_ID}
---

# Anh xa Entity — {SOURCE_MODULE} → {TARGET_MODULE}

## Tong ket

| Entity cu | Entity moi | Kieu map | Ghi chu |
|-----------|-----------|----------|---------|
| {entity_name} | {new_entity_name} | 1-1 / split / merge / new / deprecate | {ghi chu} |

## Chi tiet tung entity

### {Entity cu} → {Entity moi} (1-1)

<!-- POPULATE: Khi entity cu map truc tiep sang entity moi -->

| Field cu | Field moi | Kieu du lieu | Khac biet |
|----------|----------|-------------|-----------|
| {field_old} | {field_new} | {type_old} → {type_new} | {none / changed / removed / added} |

### {Entity cu} → {Entity moi A, Entity moi B} (Split)

<!-- POPULATE: Khi 1 entity cu duoc tach thanh nhieu entity moi -->

### {Entity cu A, Entity cu B} → {Entity moi} (Merge)

<!-- POPULATE: Khi nhieu entity cu gop thanh 1 entity moi -->

### Entity khong map

| Entity cu | Rationale |
|-----------|-----------|
| {entity_name} | {ly do khong map: deprecate, da co trong EUREKA, ...} |
