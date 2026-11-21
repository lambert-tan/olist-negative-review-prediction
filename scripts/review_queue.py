"""Shared ranking and holdout summaries for interpretation and Power BI."""
import numpy as np
import pandas as pd
from sklearn.metrics import average_precision_score, f1_score, precision_score, recall_score, roc_auc_score


def ranked_orders(frame, probability):
    """Highest score first. The order ID resolves ties independently of input order."""
    if frame.order_id.isna().any() or not frame.order_id.is_unique:
        raise ValueError("Expected one non-missing ID per order")
    if not frame[probability].between(0, 1).all():
        raise ValueError(f"Invalid probabilities in {probability}")
    return frame.sort_values([probability, "order_id"], ascending=[False, True])


def queue_size(n, share):
    return int(np.ceil(n * share))


def rebuild_holdout(pred_dir, metric_dir):
    summaries, decile_tables, rankings = [], [], {}
    for stage, model in [("placement", "LightGBM"), ("delivery", "CatBoost")]:
        frame = pd.read_csv(pred_dir / f"{stage}_predictions.csv", dtype={"order_id": str})
        score = f"{stage}_probability"
        ranked = ranked_orders(frame, score).reset_index(drop=True)
        target = ranked.actual_review_bad
        threshold = ranked[f"{stage}_threshold"]
        if set(target.unique()) != {0, 1} or threshold.nunique(dropna=False) != 1 or not threshold.between(0, 1).all():
            raise ValueError(f"Invalid holdout labels or threshold for {stage}")
        predicted = ranked[score] >= threshold
        label = "At " + stage.title()
        summaries.append(dict(stage=label, model=model,
                              precision=precision_score(target, predicted, zero_division=0),
                              recall=recall_score(target, predicted), f1=f1_score(target, predicted),
                              roc_auc=roc_auc_score(target, ranked[score]),
                              pr_auc=average_precision_score(target, ranked[score]), threshold=threshold.iloc[0]))
        ranked["risk_decile"] = np.arange(len(ranked)) * 10 // len(ranked) + 1
        table = ranked.groupby("risk_decile", as_index=False).agg(
            orders=("order_id", "size"), avg_score=(score, "mean"),
            negative_review_rate=("actual_review_bad", "mean"), negative_reviews=("actual_review_bad", "sum"))
        table.insert(0, "stage", label)
        decile_tables.append(table)
        rankings[stage] = ranked

    labels = [frame.set_index("order_id").actual_review_bad.sort_index() for frame in rankings.values()]
    if not labels[0].equals(labels[1]):
        raise ValueError("Both stages must use the same held-out orders and outcomes")
    comparison = pd.DataFrame(summaries)
    comparison.to_csv(metric_dir / "placement_vs_delivery.csv", index=False)
    pd.concat(decile_tables).to_csv(pred_dir / "score_deciles.csv", index=False)
    return comparison, rankings
