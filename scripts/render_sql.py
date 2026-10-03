"""Render portable BigQuery SQL templates with validated table identifiers."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
SQL_DIRECTORY = REPOSITORY_ROOT / "sql"
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "rendered_sql"

PROJECT_PATTERN = re.compile(r"^[a-z][a-z0-9-]{4,28}[a-z0-9]$")
DATASET_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def valid_project_id(value: str) -> str:
    """Validate a Google Cloud project identifier before SQL substitution."""
    if not PROJECT_PATTERN.fullmatch(value):
        raise argparse.ArgumentTypeError(f"Invalid Google Cloud project ID: {value!r}")
    return value


def valid_bigquery_name(value: str) -> str:
    """Validate a BigQuery dataset or table identifier."""
    if not DATASET_PATTERN.fullmatch(value):
        raise argparse.ArgumentTypeError(f"Invalid BigQuery identifier: {value!r}")
    return value


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render the repository's BigQuery SQL templates."
    )
    parser.add_argument("--work-project", required=True, type=valid_project_id)
    parser.add_argument("--work-dataset", required=True, type=valid_bigquery_name)
    parser.add_argument("--cohort-table", required=True, type=valid_bigquery_name)
    parser.add_argument(
        "--output-table", default="mimic_iv_dataset_107", type=valid_bigquery_name
    )
    parser.add_argument("--mimic-project", default="physionet-data", type=valid_project_id)
    parser.add_argument(
        "--mimic-hosp-dataset", default="mimiciv_3_1_hosp", type=valid_bigquery_name
    )
    parser.add_argument(
        "--mimic-icu-dataset", default="mimiciv_3_1_icu", type=valid_bigquery_name
    )
    parser.add_argument(
        "--mimic-derived-dataset",
        default="mimiciv_3_1_derived",
        type=valid_bigquery_name,
    )
    parser.add_argument(
        "--output-directory",
        default=DEFAULT_OUTPUT_DIRECTORY,
        type=Path,
        help="Destination for rendered SQL (default: repository/rendered_sql).",
    )
    return parser.parse_args()


def render_template(template: Path, destination: Path, values: dict[str, str]) -> None:
    text = template.read_text(encoding="utf-8")
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)

    unresolved = sorted(set(re.findall(r"\{\{([A-Z0-9_]+)\}\}", text)))
    if unresolved:
        raise RuntimeError(
            f"Unresolved placeholders in {template.name}: {', '.join(unresolved)}"
        )

    destination.write_text(text, encoding="utf-8", newline="\n")


def main() -> None:
    args = parse_arguments()
    output_directory = args.output_directory.resolve()
    output_directory.mkdir(parents=True, exist_ok=True)

    values = {
        "WORK_PROJECT": args.work_project,
        "WORK_DATASET": args.work_dataset,
        "COHORT_TABLE": args.cohort_table,
        "OUTPUT_TABLE": args.output_table,
        "MIMIC_PROJECT": args.mimic_project,
        "MIMIC_HOSP_DATASET": args.mimic_hosp_dataset,
        "MIMIC_ICU_DATASET": args.mimic_icu_dataset,
        "MIMIC_DERIVED_DATASET": args.mimic_derived_dataset,
    }

    for template in sorted(SQL_DIRECTORY.glob("*.sql")):
        destination = output_directory / template.name
        render_template(template, destination, values)
        print(f"rendered: {destination}")


if __name__ == "__main__":
    main()
