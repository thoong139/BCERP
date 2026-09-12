# TEMPLATE: Workflow Analysis — {WF-id}

> Sinh bởi Phase 1 ANALYZE. Populate từ WF-L*.md spec + analysis-raw.json.

---

# Workflow Analysis — {WF-id}: {Tên workflow}

**Session:** {SESSION_ID}
**Spec source:** .mc-data/docs/phase1-business/workflows/{WF-id}-*.md
**Generated:** {ISO8601}

## 1. Actors & Test Accounts

| Actor (§3) | Vai | Test account | Ghi chú |
|------------|-----|--------------|---------|
| {actor}    | {vai} | {account} | {nếu override từ test-accounts} |

## 2. Test Plan

### Happy Path (từ §15 Happy + §7)
- TC-HAPPY: {mô tả} — các bước §7 {N..M}

### Edge Cases (từ §15 Edge)
| TC | Input | Expected | Assertion type |
|----|-------|----------|----------------|
| TC-{NN} | | | API / UI |

### Negative (từ §15 Negative)
| TC | Input | Expected HTTP | Expected error message |
|----|-------|---------------|------------------------|
| TC-{NN} | | | |

## 3. Systems & Endpoints (cross-validated)

| Endpoint | Method | System/Module | Naming gap? |
|----------|--------|---------------|-------------|
| | | | MINOR/MAJOR/none |

## 4. State Machine Assertions (§8)

| From state | Event | To state | Assert cách |
|------------|-------|----------|-------------|
| | | | API status / UI element |

## 5. Business Rules → Assertions (§9)

| BR-ID | Rule | Assert tại bước |
|-------|------|-----------------|
| BR-WF{xx}-{NN} | | |

## 6. SLA Timing Checks (§11)

| SLA constraint | Ngưỡng | Assert cách |
|----------------|--------|-------------|
| | | |

## 7. Naming Gap Notes (nếu naming-alignment-matrix tồn tại)

- MAJOR gaps ảnh hưởng WF này: {list hoặc "không có"}
- Quyết định user (E005): {chạy / bỏ}
