"""Scorecard-style validation metrics for the placement and delivery models.

Runs on the outputs already saved in this repository, so it does not need the
raw Olist files:

    python scripts/validation_metrics.py

It writes outputs/model_metrics/scorecard_metrics.csv and
outputs/model_metrics/rank_ordering.csv.

Metrics
-------
- Gini = 2 * ROC-AUC - 1 (exact, from the test-set ROC-AUC).
- KS   = max gap between the cumulative share of negative and non-negative
         reviews, measured at decile cut points. Decile KS is a slightly
         conservative estimate of the order-level KS.
- Rank ordering: whether the negative-review rate falls from decile to decile.
- Validation-to-test gap: drift in ROC-AUC between the validation search and
  the frozen test set, as an overfitting check.

PSI (population stability index) needs the training-set scores, which are not
committed. After re-running notebook 04 locally, call `psi()` on the training
and test score arrays.
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
METRICS = ROOT / "outputs" / "model_metrics"
PRED = ROOT / "outputs" / "predictions"


def decile_ks(deciles: pd.DataFrame) -> tuple[float, int]:
    g = deciles.sort_values("risk_decile")
    bad = g["negative_reviews"]
    good = g["orders"] - bad
    gap = bad.cumsum() / bad.sum() - good.cumsum() / good.sum()
    i = gap.idxmax()
    return float(gap.max()), int(g.loc[i, "risk_decile"])


def rank_ordering(deciles: pd.DataFrame) -> pd.DataFrame:
    g = deciles.sort_values("risk_decile").copy()
    g["rate_change_vs_prior"] = g["negative_review_rate"].diff()
    g["inversion"] = g["rate_change_vs_prior"] > 0
    return g[["stage", "risk_decile", "orders", "negative_review_rate",
              "rate_change_vs_prior", "inversion"]]


def psi(expected: np.ndarray, actual: np.ndarray, bins: int = 10) -> float:
    """Population stability index using quantile bins of `expected`."""
    edges = np.unique(np.quantile(expected, np.linspace(0, 1, bins + 1)))
    edges[0], edges[-1] = -np.inf, np.inf
    e = np.histogram(expected, edges)[0] / len(expected)
    a = np.histogram(actual, edges)[0] / len(actual)
    e, a = np.clip(e, 1e-6, None), np.clip(a, 1e-6, None)
    return float(np.sum((a - e) * np.log(a / e)))


def main() -> None:
    deciles = pd.read_csv(PRED / "score_deciles.csv")
    test = pd.read_csv(METRICS / "placement_vs_delivery.csv")
    val = {
        "At Placement": pd.read_csv(METRICS / "placement_validation_search.csv"),
        "At Delivery": pd.read_csv(METRICS / "delivery_validation_search.csv"),
    }

    rows, ranks = [], []
    for stage, g in deciles.groupby("stage", sort=False):
        t = test.loc[test["stage"] == stage].iloc[0]
        ks, ks_decile = decile_ks(g)
        r = rank_ordering(g)
        ranks.append(r)
        best_val_auc = val[stage]["val_roc_auc"].max()
        rows.append({
            "stage": stage,
            "model": t["model"],
            "test_orders": int(g["orders"].sum()),
            "test_negative_reviews": int(g["negative_reviews"].sum()),
            "roc_auc": round(t["roc_auc"], 4),
            "gini": round(2 * t["roc_auc"] - 1, 4),
            "ks_decile": round(ks, 4),
            "ks_peak_decile": ks_decile,
            "pr_auc": round(t["pr_auc"], 4),
            "top_decile_rate": round(g.loc[g["risk_decile"] == 1, "negative_review_rate"].item(), 4),
            "bottom_decile_rate": round(g.loc[g["risk_decile"] == 10, "negative_review_rate"].item(), 4),
            "rank_inversions": int(r["inversion"].sum()),
            "best_validation_roc_auc": round(best_val_auc, 4),
            "validation_to_test_auc_gap": round(t["roc_auc"] - best_val_auc, 4),
        })

    out = pd.DataFrame(rows)
    out.to_csv(METRICS / "scorecard_metrics.csv", index=False)
    pd.concat(ranks).to_csv(METRICS / "rank_ordering.csv", index=False)
    print(out.T.to_string(header=False))


if __name__ == "__main__":
    main()
