# Testing - Model Validation Tools & Metrics

> **Domain**: Testing / ML Model Quality Assurance
> **Last Updated**: 2026-03-15

---

## 1. Population Stability Index (PSI)

```python
import numpy as np
import pandas as pd

def compute_psi(expected: pd.Series, actual: pd.Series, bins: int = 10) -> float:
    """
    Tính Population Stability Index giữa 2 distributions.
    < 0.10 → Ổn định (xanh)
    0.10–0.25 → Drift vừa, cần theo dõi (vàng)
    >= 0.25 → Drift đáng kể, cần hành động (đỏ)
    """
    breakpoints = np.linspace(0, 100, bins + 1)
    expected_pcts = np.percentile(expected.dropna(), breakpoints)
    expected_counts = np.histogram(expected, bins=expected_pcts)[0]
    actual_counts = np.histogram(actual, bins=expected_pcts)[0]
    exp_pct = (expected_counts + 1) / (expected_counts.sum() + bins)
    act_pct = (actual_counts + 1) / (actual_counts.sum() + bins)
    psi = np.sum((act_pct - exp_pct) * np.log(act_pct / exp_pct))
    return round(psi, 6)
```

### PSI Thresholds

| PSI | Trạng thái | Hành động |
|-----|-----------|-----------|
| < 0.10 | Ổn định | Không cần hành động |
| 0.10 – 0.25 | Drift vừa | Theo dõi, điều tra |
| ≥ 0.25 | Drift đáng kể | Retrain/recalibrate |

---

## 2. Discrimination Metrics

```python
from sklearn.metrics import roc_auc_score
from scipy.stats import ks_2samp

def discrimination_report(y_true: pd.Series, y_score: pd.Series) -> dict:
    """Tính AUC, Gini coefficient, và KS statistic."""
    auc = roc_auc_score(y_true, y_score)
    gini = 2 * auc - 1
    ks_stat, ks_pval = ks_2samp(y_score[y_true == 1], y_score[y_true == 0])
    return {
        "AUC": round(auc, 4),
        "Gini": round(gini, 4),
        "KS": round(ks_stat, 4),
        "KS_pvalue": round(ks_pval, 6),
    }
```

### Discrimination Thresholds

| Metric | Excellent | Good | Acceptable | Poor |
|--------|-----------|------|-----------|------|
| AUC | > 0.90 | 0.80–0.90 | 0.70–0.80 | < 0.70 |
| Gini | > 0.80 | 0.60–0.80 | 0.40–0.60 | < 0.40 |
| KS | > 0.40 | 0.30–0.40 | 0.20–0.30 | < 0.20 |

---

## 3. Calibration Test (Hosmer-Lemeshow)

```python
from scipy.stats import chi2

def hosmer_lemeshow_test(y_true: pd.Series, y_pred: pd.Series, groups: int = 10) -> dict:
    """
    Hosmer-Lemeshow goodness-of-fit test.
    p-value < 0.05 → miscalibration đáng kể.
    """
    data = pd.DataFrame({"y": y_true, "p": y_pred})
    data["bucket"] = pd.qcut(data["p"], groups, duplicates="drop")
    agg = data.groupby("bucket", observed=True).agg(
        n=("y", "count"), observed=("y", "sum"), expected=("p", "sum"),
    )
    hl_stat = (((agg["observed"] - agg["expected"]) ** 2)
               / (agg["expected"] * (1 - agg["expected"] / agg["n"]))).sum()
    dof = len(agg) - 2
    p_value = 1 - chi2.cdf(hl_stat, dof)
    return {"HL_statistic": round(hl_stat, 4), "p_value": round(p_value, 6), "calibrated": p_value >= 0.05}
```

---

## 4. QA Domains — 10 Domain Checklist

| # | Domain | Kiểm tra |
|---|--------|----------|
| 1 | Documentation & Governance | Methodology docs, approval controls, model inventory |
| 2 | Data Reconstruction | Population reconstruction, exclusion logic, extraction validation |
| 3 | Target / Label Analysis | Label distribution, stability, quality, observation windows |
| 4 | Segmentation & Cohort | Segment materiality, heterogeneity, boundary stability |
| 5 | Feature Analysis | Feature selection, distribution stability, PSI, SHAP importance |
| 6 | Model Replication | Train/val/test partition, re-train, parameter delta |
| 7 | Calibration Testing | Hosmer-Lemeshow, Brier score, reliability diagrams |
| 8 | Performance & Monitoring | Gini, KS, AUC, F1, parsimony, monitoring setup |
| 9 | Interpretability & Fairness | SHAP global/local, PDP, demographic parity, equalized odds |
| 10 | Business Impact | Economic impact, stakeholder communication, finding tracking |

---

## 5. Severity Classification

| Severity | Định nghĩa | Hành động |
|----------|------------|-----------|
| High | Mô hình unsound — kết quả không tin cậy | KHÔNG deploy, remediate ngay |
| Medium | Material weakness — ảnh hưởng đáng kể | Remediate trước next review |
| Low | Improvement opportunity | Lên kế hoạch |
| Info | Observation | Theo dõi |

---

## 6. Fairness Metrics

| Metric | Định nghĩa | Target |
|--------|------------|--------|
| Demographic Parity | P(ŷ=1\|A=0) ≈ P(ŷ=1\|A=1) | Ratio 0.8–1.25 |
| Equalized Odds | TPR và FPR tương đương across groups | Difference < 5% |
| Calibration Parity | Predicted probabilities calibrated per group | H-L p > 0.05 per group |
