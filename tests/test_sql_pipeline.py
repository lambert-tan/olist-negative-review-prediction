"""Parity tests for the DuckDB SQL pipeline.

The raw Olist data is not committed, so these tests build a small synthetic dataset
with the same schema and deliberately awkward edge cases, then check that

  1. sql/01_build_master_orders.sql produces the same table as the code in
     notebooks/01_data_join_and_clean.ipynb (the notebook cells are executed as the
     reference, not re-typed), and
  2. sql/04_scorecard_metrics.sql reproduces outputs/model_metrics/scorecard_metrics.csv
     and rank_ordering.csv from scripts/validation_metrics.py.

Run:  pytest tests/ -q        (or: python tests/test_sql_pipeline.py)
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd

REPO = Path(__file__).resolve().parents[1]
RUNNER = REPO / "scripts" / "run_sql_pipeline.py"
NOTEBOOK = REPO / "notebooks" / "01_data_join_and_clean.ipynb"


# --------------------------------------------------------------------------- synthetic data
def make_raw_tables(seed: int = 7, n_orders: int = 4000) -> dict[str, pd.DataFrame]:
    """Synthetic Olist-shaped tables with edge cases the pipeline has to handle."""
    rng = np.random.default_rng(seed)
    states = ["SP", "RJ", "MG", "BA", "RS", "PR"]
    cats_pt = ["beleza_saude", "informatica", "moveis", "esporte", "livros", None, "sem_traducao"]
    translation = pd.DataFrame({
        "product_category_name": ["beleza_saude", "informatica", "moveis", "esporte", "livros"],
        "product_category_name_english": ["health_beauty", "computers", "furniture", "sports", "books"],
    })  # 'sem_traducao' has no translation; None is a missing category

    n_products, n_sellers, n_customers = 300, 40, n_orders  # one customer_id per order, like Olist
    products = pd.DataFrame({
        "product_id": [f"p{i}" for i in range(n_products)],
        "product_category_name": rng.choice(cats_pt, n_products),
        "product_weight_g": rng.integers(50, 5000, n_products).astype(float),
        "product_length_cm": rng.integers(5, 80, n_products).astype(float),
        "product_height_cm": rng.integers(2, 60, n_products).astype(float),
        "product_width_cm": rng.integers(5, 60, n_products).astype(float),
    })
    products.loc[rng.choice(n_products, 15, replace=False), ["product_weight_g"]] = np.nan
    products.loc[rng.choice(n_products, 10, replace=False), ["product_length_cm"]] = np.nan

    sellers = pd.DataFrame({
        "seller_id": [f"s{i}" for i in range(n_sellers)],
        "seller_zip_code_prefix": rng.integers(1000, 99999, n_sellers),
        "seller_city": [f"city{i % 9}" for i in range(n_sellers)],
        "seller_state": rng.choice(states, n_sellers),
    })
    customers = pd.DataFrame({
        "customer_id": [f"c{i}" for i in range(n_customers)],
        "customer_unique_id": [f"u{i // 2}" for i in range(n_customers)],
        "customer_zip_code_prefix": rng.integers(1000, 99999, n_customers),
        "customer_city": [f"town{i % 17}" for i in range(n_customers)],
        "customer_state": rng.choice(states, n_customers),
    })
    # Edge: some customers / sellers missing from their dimension tables.
    customers = customers.drop(rng.choice(customers.index, 25, replace=False)).reset_index(drop=True)
    sellers_missing = sellers.drop(rng.choice(sellers.index, 3, replace=False)).reset_index(drop=True)

    purchase = pd.Timestamp("2017-01-01") + pd.to_timedelta(rng.integers(0, 600 * 24 * 3600, n_orders), unit="s")
    status = rng.choice(["delivered", "shipped", "canceled", "invoiced"], n_orders, p=[0.88, 0.05, 0.04, 0.03])
    approved = purchase + pd.to_timedelta(rng.integers(0, 3 * 86400, n_orders), unit="s")
    carrier = approved + pd.to_timedelta(rng.integers(-2 * 86400, 6 * 86400, n_orders), unit="s")  # some negative
    delivered = carrier + pd.to_timedelta(rng.integers(1 * 86400, 25 * 86400, n_orders), unit="s")
    estimated = purchase + pd.to_timedelta(rng.integers(8 * 86400, 35 * 86400, n_orders), unit="s")
    orders = pd.DataFrame({
        "order_id": [f"o{i}" for i in range(n_orders)],
        "customer_id": [f"c{i}" for i in range(n_orders)],
        "order_status": status,
        "order_purchase_timestamp": purchase,
        "order_approved_at": approved,
        "order_delivered_carrier_date": carrier,
        "order_delivered_customer_date": delivered,
        "order_estimated_delivery_date": estimated,
    })
    # Edge: missing timestamps on delivered orders.
    for col, k in [("order_approved_at", 20), ("order_delivered_carrier_date", 30),
                   ("order_delivered_customer_date", 12)]:
        orders.loc[rng.choice(n_orders, k, replace=False), col] = pd.NaT

    # Items: 1-4 per order, several sellers, tied prices, zero prices, unknown products.
    rows = []
    for oid in orders["order_id"]:
        if rng.random() < 0.02:      # edge: order without items
            continue
        for k in range(1, rng.integers(1, 5) + 1):
            pid = f"p{rng.integers(0, n_products)}" if rng.random() > 0.01 else "p_unknown"
            price = float(rng.choice([0.0, 19.9, 19.9, 49.9, rng.uniform(5, 300)]))
            rows.append((oid, k, pid, f"s{rng.integers(0, n_sellers)}", round(price, 2),
                         round(float(rng.uniform(0, 40)), 2)))
    items = pd.DataFrame(rows, columns=["order_id", "order_item_id", "product_id", "seller_id",
                                        "price", "freight_value"])

    # Payments: 0-3 rows per order; equal values across types force the alphabetical tie-break.
    rows = []
    for oid in orders["order_id"]:
        if rng.random() < 0.02:      # edge: order without payments
            continue
        for k in range(1, rng.integers(1, 4) + 1):
            rows.append((oid, k, str(rng.choice(["credit_card", "boleto", "voucher", "debit_card"])),
                         int(rng.integers(1, 12)), float(rng.choice([25.0, 25.0, round(rng.uniform(5, 200), 2)]))))
    payments = pd.DataFrame(rows, columns=["order_id", "payment_sequential", "payment_type",
                                           "payment_installments", "payment_value"])

    # Reviews: duplicates, missing timestamps, exact-timestamp ties, orders with no review,
    # and free text with quotes and line breaks to exercise CSV parsing.
    rows, rid = [], 0
    for oid in orders["order_id"]:
        if rng.random() < 0.05:      # edge: no review
            continue
        n_rev = 1 if rng.random() > 0.08 else int(rng.integers(2, 4))
        base = pd.Timestamp("2017-02-01") + pd.to_timedelta(int(rng.integers(0, 600)), unit="D")
        for _ in range(n_rev):
            rid += 1
            tie = rng.random() < 0.3
            created = base if tie else base + pd.to_timedelta(int(rng.integers(0, 5)), unit="D")
            answered = created + pd.to_timedelta(int(rng.integers(0, 3 * 86400)), unit="s")
            if tie:
                answered = base + pd.to_timedelta(3600, unit="s")
            if rng.random() < 0.04:
                answered = pd.NaT
            if rng.random() < 0.02:
                created = pd.NaT
            text = rng.choice(["", 'Chegou "rápido"', "linha 1\nlinha 2", "ok, bom"])
            rows.append((f"r{rid:06d}", oid, int(rng.choice([1, 2, 3, 4, 5], p=[.1, .05, .1, .25, .5])),
                         text, created, answered))
    reviews = pd.DataFrame(rows, columns=["review_id", "order_id", "review_score", "review_comment_message",
                                          "review_creation_date", "review_answer_timestamp"])
    reviews = reviews.sample(frac=1.0, random_state=seed).reset_index(drop=True)  # file order != id order
    return {
        "olist_orders_dataset.csv": orders,
        "olist_order_items_dataset.csv": items,
        "olist_order_payments_dataset.csv": payments,
        "olist_order_reviews_dataset.csv": reviews,
        "olist_products_dataset.csv": products,
        "olist_sellers_dataset.csv": sellers_missing,
        "olist_customers_dataset.csv": customers,
        "product_category_name_translation.csv": translation,
    }


def write_raw(tables: dict[str, pd.DataFrame], folder: Path) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    for name, df in tables.items():
        df.to_csv(folder / name, index=False)


# --------------------------------------------------------------------------- reference + SQL
def reference_master(raw_dir: Path) -> pd.DataFrame:
    """Run the notebook's own cells (join, features, cleaning) as the pandas reference.

    The shared train/test split and the final asserts are cut off: the split is not part of
    the SQL pipeline, and the asserts are fixed to the real-data row counts.
    """
    nb = json.loads(NOTEBOOK.read_text())
    cells = ["".join(c["source"]) for c in nb["cells"] if c["cell_type"] == "code"]
    cells[0] = cells[0].replace("Path('../data/raw')", f"Path({str(raw_dir)!r})").replace(
        "Path('../data/processed')", f"Path({str(raw_dir / 'processed')!r})")
    # code cells: 0 load, 1 dates + reviews, 2 items/payments, 3 master join, 4 features,
    # 5 cleaning + split. Run all of them, stopping cell 5 just before the split.
    cleaning = cells[5].split("train_ids, test_ids")[0]
    ns: dict = {}
    for src in cells[:5] + [cleaning]:
        exec(compile(src, "<notebook01>", "exec"), ns)
    return ns["master"]


def sql_master(raw_dir: Path, out_dir: Path, steps=("01", "02", "03")) -> pd.DataFrame:
    master_csv = out_dir / "master_from_sql.csv"
    proc = subprocess.run(
        [sys.executable, str(RUNNER), "--raw-dir", str(raw_dir), "--out-dir", str(out_dir / "results"),
         "--steps", *steps, "--export-master", str(master_csv)],
        capture_output=True, text=True, cwd=REPO)
    assert proc.returncode == 0, f"runner failed:\nSTDOUT\n{proc.stdout[-3000:]}\nSTDERR\n{proc.stderr[-3000:]}"
    return pd.read_csv(master_csv)


# --------------------------------------------------------------------------- tests
def test_sql_master_matches_notebook(tmp_path):
    raw_dir = tmp_path / "raw"
    write_raw(make_raw_tables(), raw_dir)
    ref = reference_master(raw_dir).sort_values("order_id").reset_index(drop=True)
    got = sql_master(raw_dir, tmp_path).sort_values("order_id").reset_index(drop=True)

    assert len(ref) > 2000, "synthetic cohort unexpectedly small"
    assert list(ref["order_id"]) == list(got["order_id"]), "different order cohorts"

    shared = [c for c in ref.columns if c in got.columns and c != "order_id"]
    missing = [c for c in ref.columns if c not in got.columns and c != "split"]
    assert not missing, f"columns in the notebook but not in SQL: {missing}"

    problems = []
    for col in shared:
        a, b = ref[col], got[col]
        if pd.api.types.is_datetime64_any_dtype(a) or col.endswith(("_timestamp", "_at", "_date")):
            a, b = pd.to_datetime(a), pd.to_datetime(b)
            same = (a == b) | (a.isna() & b.isna())
        elif pd.api.types.is_numeric_dtype(a) and pd.api.types.is_numeric_dtype(b):
            same = np.isclose(a.astype(float), b.astype(float), rtol=1e-9, atol=1e-9, equal_nan=True)
        else:
            same = (a.astype(str) == b.astype(str)) | (a.isna() & b.isna())
        n_bad = int((~np.asarray(same)).sum())
        if n_bad:
            problems.append((col, n_bad))
    assert not problems, f"columns that differ between SQL and notebook: {problems}"


def test_edge_cases_are_present_in_the_synthetic_data(tmp_path):
    """Guard: the parity test is only meaningful if the edge cases it targets actually occur."""
    raw_dir = tmp_path / "raw"
    write_raw(make_raw_tables(), raw_dir)
    ref = reference_master(raw_dir)
    assert ref["carrier_timestamp_anomaly"].sum() > 20           # negative carrier intervals
    assert (ref["customer_state"] == "unknown").sum() > 0        # customers missing from the dimension
    assert (ref["primary_seller_state"] == "unknown").sum() > 0  # sellers missing
    assert (ref["primary_product_category"] == "unknown").sum() > 0
    assert (ref["total_price"] == 0).sum() > 0                   # freight_to_price_ratio -> NaN
    assert ref["n_distinct_sellers"].max() >= 3
    assert 0.1 < ref["review_bad"].mean() < 0.4


def test_quality_checks_pass_on_synthetic_data(tmp_path):
    raw_dir = tmp_path / "raw"
    write_raw(make_raw_tables(), raw_dir)
    sql_master(raw_dir, tmp_path)                                # runner exits 1 if any check fails
    checks = pd.read_csv(tmp_path / "results" / "quality_checks.csv")
    assert checks["passed"].all() and len(checks) == 13


def test_known_totals_check_fails_on_wrong_data(tmp_path):
    """--check-known-totals must fail loudly when the cohort is not the real 95,824-order one."""
    raw_dir = tmp_path / "raw"
    write_raw(make_raw_tables(), raw_dir)
    proc = subprocess.run(
        [sys.executable, str(RUNNER), "--raw-dir", str(raw_dir), "--out-dir", str(tmp_path / "r"),
         "--steps", "01", "02", "--check-known-totals"], capture_output=True, text=True, cwd=REPO)
    assert proc.returncode == 1
    assert "known_total_orders_95824" in proc.stdout


def test_scorecard_sql_matches_python(tmp_path):
    proc = subprocess.run([sys.executable, str(RUNNER), "--steps", "04", "--out-dir", str(tmp_path)],
                          capture_output=True, text=True, cwd=REPO)
    assert proc.returncode == 0, proc.stderr
    sql_head = pd.read_csv(tmp_path / "scorecard_headline.csv").set_index("stage")
    py_head = pd.read_csv(REPO / "outputs" / "model_metrics" / "scorecard_metrics.csv").set_index("stage")
    for stage in py_head.index:
        for sql_col, py_col in [("gini", "gini"), ("ks_decile", "ks_decile"),
                                ("ks_peak_decile", "ks_peak_decile"), ("roc_auc", "roc_auc")]:
            assert abs(sql_head.loc[stage, sql_col] - py_head.loc[stage, py_col]) < 1e-3, (stage, sql_col)

    sql_rank = pd.read_csv(tmp_path / "rank_ordering.csv")
    py_rank = pd.read_csv(REPO / "outputs" / "model_metrics" / "rank_ordering.csv")
    assert sql_rank["inversion"].sum() == py_rank["inversion"].sum()


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-q"]))
