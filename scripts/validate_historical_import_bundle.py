#!/usr/bin/env python3
"""Read-only preflight validator for the BOKAN ERP historical import CSV bundle.

This tool never connects to a database and never writes/imports ERP records.
Run: python scripts/validate_historical_import_bundle.py /path/to/unzipped-bundle
"""
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path


EXPECTED = {
    "purchase_transactions": (25, 9582),
    "purchase_lines": (25, 9582),
    "sales_transactions": (50, 7670),
    "sales_lines": (56, 7670),
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def number(row: dict[str, str], key: str) -> int:
    value = (row.get(key) or "0").strip()
    return int(float(value or 0))


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    errors: list[str] = []
    warnings: list[str] = []

    names = [
        "purchase_transactions",
        "purchase_lines",
        "sales_transactions",
        "sales_lines",
    ]
    data = {name: read_csv(root / f"{name}.csv") for name in names}

    for name, (expected_rows, expected_qty) in EXPECTED.items():
        rows = data[name]
        quantity_key = "total_quantity" if name.endswith("transactions") else "quantity"
        actual_qty = sum(number(row, quantity_key) for row in rows)
        if len(rows) != expected_rows:
            errors.append(f"{name}: expected {expected_rows} rows, found {len(rows)}")
        if actual_qty != expected_qty:
            errors.append(f"{name}: expected quantity total {expected_qty}, found {actual_qty}")

    for name in ("purchase_transactions", "sales_transactions"):
        ids = [row["import_transaction_id"] for row in data[name]]
        if len(ids) != len(set(ids)):
            errors.append(f"{name}: duplicate import_transaction_id detected")

    # Ensure each transaction header total equals the sum of its line rows.
    for header_name, line_name in (
        ("purchase_transactions", "purchase_lines"),
        ("sales_transactions", "sales_lines"),
    ):
        totals: dict[str, int] = defaultdict(int)
        for line in data[line_name]:
            totals[line["import_transaction_id"]] += number(line, "quantity")
        for header in data[header_name]:
            key = header["import_transaction_id"]
            expected_total = number(header, "total_quantity")
            actual_total = totals.get(key, 0)
            if actual_total != expected_total:
                errors.append(
                    f"{key}: header quantity {expected_total} does not match line quantity {actual_total}"
                )
        extra_ids = sorted(set(totals) - {r["import_transaction_id"] for r in data[header_name]})
        if extra_ids:
            errors.append(f"{line_name}: line rows reference missing headers: {', '.join(extra_ids)}")

    issues = read_csv(root / "review_issues.csv")
    blockers = [r for r in issues if (r.get("Severity") or "").strip().upper() == "HIGH"]
    warnings.append(f"Source review issues: {len(issues)} total, {len(blockers)} HIGH severity")
    warnings.append("This validator checks CSV integrity only; it does not approve the source data for posting.")

    if errors:
        print("FAIL — import bundle integrity checks failed:")
        for error in errors:
            print(f" - {error}")
        return 1

    print("PASS — CSV structure and quantity totals match expected source snapshot.")
    for name, (expected_rows, expected_qty) in EXPECTED.items():
        print(f" - {name}: {expected_rows} rows; {expected_qty} pcs")
    for warning in warnings:
        print(f"REVIEW — {warning}")
    print("SAFEGUARD — no database connection or production writes were performed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
