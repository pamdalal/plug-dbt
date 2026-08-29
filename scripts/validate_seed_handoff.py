#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import io
import json
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

CUTOFF = datetime(2026, 7, 31, tzinfo=timezone.utc)

COMMON_COLUMNS = (
    "source_record_id",
    "source_system",
    "source_batch_id",
    "schema_version",
    "synthetic_vin",
    "request_id",
    "source_updated_at",
    "ingested_at",
)

SEED_CONTRACTS = {
    "raw_valuation_requests.csv": {
        "row_count": 2000,
        "source_system": "valuation_portal",
        "header": COMMON_COLUMNS
        + (
            "seller_id",
            "submission_channel",
            "market_region",
            "odometer_value",
            "odometer_unit",
            "submitted_at",
        ),
        "timestamp_columns": (
            "source_updated_at",
            "ingested_at",
            "submitted_at",
        ),
    },
    "raw_vehicle_assessments.csv": {
        "row_count": 1916,
        "source_system": "vehicle_assessment",
        "header": COMMON_COLUMNS
        + (
            "assessment_id",
            "assessment_version",
            "assessment_status",
            "assessment_method_version",
            "vehicle_model_family",
            "vehicle_segment",
            "model_year",
            "assessed_odometer_value",
            "assessed_odometer_unit",
            "battery_soh_value",
            "battery_soh_unit",
            "condition_grade",
            "observed_at",
            "assessment_completed_at",
            "available_to_model_at",
        ),
        "timestamp_columns": (
            "source_updated_at",
            "ingested_at",
            "observed_at",
            "assessment_completed_at",
            "available_to_model_at",
        ),
    },
    "raw_offer_events.csv": {
        "row_count": 3391,
        "source_system": "offer_service",
        "header": COMMON_COLUMNS
        + (
            "source_event_id",
            "offer_id",
            "event_type",
            "event_sequence",
            "offer_version",
            "event_at",
            "reason_code",
            "pricing_evaluation_id",
            "feature_cutoff_at",
            "pricing_evaluated_at",
            "pricing_model_version",
            "pricing_policy_version",
            "assessment_id_used",
            "assessment_version_used",
            "predicted_wholesale_value_amount",
            "net_policy_adjustment_amount",
            "seller_offer_amount",
            "pricing_amount_unit",
            "pricing_currency_code",
            "expires_at",
        ),
        "timestamp_columns": (
            "source_updated_at",
            "ingested_at",
            "event_at",
            "feature_cutoff_at",
            "pricing_evaluated_at",
            "expires_at",
        ),
    },
    "raw_marketplace_events.csv": {
        "row_count": 2951,
        "source_system": "dealer_marketplace",
        "header": COMMON_COLUMNS
        + (
            "source_event_id",
            "offer_id",
            "auction_id",
            "event_sequence",
            "event_type",
            "event_at",
            "scheduled_close_at",
            "bid_id",
            "dealer_id",
            "transaction_id",
            "event_amount",
            "event_amount_unit",
            "currency_code",
            "amount_role",
            "auction_result_code",
        ),
        "timestamp_columns": (
            "source_updated_at",
            "ingested_at",
            "event_at",
            "scheduled_close_at",
        ),
    },
}


def parse_timestamp(value: str) -> datetime:
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ValueError("timestamp lacks an explicit offset")
    return parsed.astimezone(timezone.utc)


def read_canonical_csv(path: Path) -> tuple[tuple[str, ...], list[dict[str, str]]]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ValueError(f"{path}: UTF-8 BOM is prohibited")
    if b"\r" in raw:
        raise ValueError(f"{path}: only LF line endings are allowed")
    if not raw.endswith(b"\n") or raw.endswith(b"\n\n"):
        raise ValueError(f"{path}: require exactly one terminal LF and no blank final row")

    text = raw.decode("utf-8")
    parsed_rows = list(csv.reader(io.StringIO(text, newline=""), strict=True))
    if not parsed_rows or not parsed_rows[0]:
        raise ValueError(f"{path}: missing header")
    if any(not row for row in parsed_rows):
        raise ValueError(f"{path}: blank rows are prohibited")

    rendered = io.StringIO(newline="")
    writer = csv.writer(
        rendered,
        delimiter=",",
        quotechar='"',
        quoting=csv.QUOTE_ALL,
        lineterminator="\n",
    )
    writer.writerows(parsed_rows)
    if rendered.getvalue().encode("utf-8") != raw:
        raise ValueError(f"{path}: CSV must use canonical quote-all encoding")

    header = tuple(parsed_rows[0])
    if len(set(header)) != len(header):
        raise ValueError(f"{path}: duplicate header names")

    rows: list[dict[str, str]] = []
    for line_number, values in enumerate(parsed_rows[1:], start=2):
        if len(values) != len(header):
            raise ValueError(
                f"{path}:{line_number}: expected {len(header)} fields, got {len(values)}"
            )
        if "null" in values:
            raise ValueError(f"{path}:{line_number}: literal lowercase null is prohibited")
        rows.append(dict(zip(header, values)))
    return header, rows


def profile_column(
    rows: list[dict[str, str]],
    column: str,
    timestamp_columns: frozenset[str],
) -> dict[str, Any]:
    values = [row[column] for row in rows]
    non_null = [value for value in values if value != ""]
    counts = Counter(non_null)
    result: dict[str, Any] = {
        "null_count": len(values) - len(non_null),
        "null_rate": round((len(values) - len(non_null)) / len(values), 6),
        "distinct_count": len(counts),
        "duplicate_count": len(non_null) - len(counts),
    }

    if column in timestamp_columns and non_null:
        parsed = [parse_timestamp(value) for value in non_null]
        result["timestamp_min_utc"] = min(parsed).isoformat()
        result["timestamp_max_utc"] = max(parsed).isoformat()
    elif non_null:
        try:
            numeric = [Decimal(value) for value in non_null]
        except InvalidOperation:
            numeric = []
        if numeric:
            result["numeric_min"] = str(min(numeric))
            result["numeric_max"] = str(max(numeric))

    if 0 < len(counts) <= 20:
        result["frequencies"] = dict(sorted(counts.items()))
    return result


def validate_seed(path: Path, contract: dict[str, Any]) -> dict[str, Any]:
    header, rows = read_canonical_csv(path)
    expected_header = tuple(contract["header"])
    if header != expected_header:
        raise ValueError(f"{path}: header does not match the approved ordered contract")
    if len(rows) != contract["row_count"]:
        raise ValueError(
            f"{path}: expected {contract['row_count']} data rows, got {len(rows)}"
        )

    expected_source = contract["source_system"]
    physical_keys: set[tuple[str, str]] = set()
    previous_order: tuple[datetime, str] | None = None
    for line_number, row in enumerate(rows, start=2):
        if row["source_system"] != expected_source:
            raise ValueError(
                f"{path}:{line_number}: source_system must be {expected_source}"
            )
        physical_key = (row["source_system"], row["source_record_id"])
        if physical_key in physical_keys:
            raise ValueError(f"{path}:{line_number}: duplicate physical delivery key")
        physical_keys.add(physical_key)

        for column in contract["timestamp_columns"]:
            if row[column] != "":
                try:
                    parse_timestamp(row[column])
                except ValueError as error:
                    raise ValueError(
                        f"{path}:{line_number}: invalid {column}: {error}"
                    ) from error

        ingested_at = parse_timestamp(row["ingested_at"])
        if ingested_at >= CUTOFF:
            raise ValueError(f"{path}:{line_number}: ingested_at is not before cutoff")
        current_order = (ingested_at, row["source_record_id"])
        if previous_order is not None and current_order < previous_order:
            raise ValueError(f"{path}:{line_number}: rows are not canonically ordered")
        previous_order = current_order

    timestamp_columns = frozenset(contract["timestamp_columns"])
    return {
        "column_count": len(header),
        "columns": {
            column: profile_column(rows, column, timestamp_columns) for column in header
        },
        "physical_key_count": len(physical_keys),
        "row_count": len(rows),
        "source_system": expected_source,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate and profile the four canonical dbt seed handoff CSVs."
    )
    parser.add_argument(
        "--seed-dir",
        type=Path,
        default=Path("seeds"),
        help="Directory containing the four raw_*.csv seed files.",
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        help="Optional generator data directory for byte-for-byte comparison.",
    )
    arguments = parser.parse_args()

    actual_files = {path.name for path in arguments.seed_dir.glob("raw_*.csv")}
    expected_files = set(SEED_CONTRACTS)
    if actual_files != expected_files:
        raise ValueError(
            "seed directory must contain exactly the four approved raw_*.csv files; "
            f"missing={sorted(expected_files - actual_files)}, "
            f"extra={sorted(actual_files - expected_files)}"
        )

    profiles: dict[str, Any] = {}
    for filename, contract in sorted(SEED_CONTRACTS.items()):
        seed_path = arguments.seed_dir / filename
        if arguments.source_dir is not None:
            source_path = arguments.source_dir / filename
            if seed_path.read_bytes() != source_path.read_bytes():
                raise ValueError(f"{filename}: destination bytes differ from generator source")
        profiles[filename] = validate_seed(seed_path, contract)

    print(json.dumps(profiles, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
