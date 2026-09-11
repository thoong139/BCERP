# Project Context — [TEN_DU_AN]
Generated: [YYYY-MM-DD] | Scan Confidence: [0.XX] | Strategy: [S1-S7]: [STRATEGY_NAME]

---
## 0. Tong quan Du an

**Linh vuc:** [LINH_VUC]
**Mo ta:** [1-2 cau mo ta du an]
**Quy mo:** [SO_APPS] apps | [SO_MODULES] modules | [SO_FILES] files source

---
## 1. He Thong & Ung Dung (Multi-App Overview)

> Chi them section nay khi phat hien >= 2 apps rieng biet (apps/, packages/, vv.)
> Neu single-app → bo section nay, giu Module Map o Section 2.

| He thong (App) | Duong dan | Muc dich | Doi tuong su dung | Trang thai |
|----------------|-----------|----------|-------------------|------------|
| [APP_NAME]     | [APP_PATH] | [APP_MUC_DICH] | [APP_DOI_TUONG] | [APP_TRANG_THAI] |

---
## 2. Tech Stack (Verified tu code — CORE-014)
| Layer | Tech | Nguon xac minh |
|-------|------|----------------|
| [LAYER] | [TECH] | [NGUON] |

---
## 3. Module Map
| Module (canonical) | He thong | Backend Project | Files | Hoan thien uoc tinh | Chat luong code |
|-------------------|----------|-----------------|-------|---------------------|-----------------|
| [MODULE_NAME] | [MODULE_HE_THONG] | [MODULE_PROJECT] | [MODULE_FILES] | [MODULE_HOAN_THIEN] | [MODULE_CHAT_LUONG] |

---
## 4. Tai lieu Hien co (Doc Quality Assessment)
| File | Loai | Do tin cay | Khuyen nghi |
|------|------|-----------|-------------|
| [DOC_FILE] | [DOC_LOAI] | [DOC_TIN_CAY] | [DOC_KHUYEN_NGHI] |

---
## 5. Features Extracted (per module, top 5 per confidence)
> Full data: extracted/{module}.json

**[Module: MODULE_NAME]**
- [FEATURE_DESC] (conf: [CONF_SCORE]) — [CODE_REF]

---
## 6. Implementation Status (Feature-Level)
PARTIAL ([N] modules — can attention nhat):
| Module | Features | Done est. | Partial est. | Not Started |
|--------|----------|-----------|--------------|-------------|
| [MODULE] | [FEATURES] | [DONE_EST] | [PARTIAL_EST] | [NOT_STARTED_EST] |

NOT_STARTED: [NOT_STARTED_LIST]

---
## 7. Nhung Diem Can Chu y
1. [DIEM_CHU_Y_1 — uu tien CRITICAL truoc]
2. [DIEM_CHU_Y_2]

---
## 8. Maturity & Strategy
Maturity Level: [MATURITY_LEVEL]
Strategy: [STRATEGY_ID]: [STRATEGY_NAME]
Recommended approach: [RECOMMENDED_APPROACH]

Next step: /wf-brainstorm (legacy flow)
