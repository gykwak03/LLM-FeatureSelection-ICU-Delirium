"""Fail when public repository candidates violate the code-only policy."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = {
    ".env.example",
    ".gitignore",
    "LICENSE",
    "README.md",
    "environment.yml",
    "requirements.txt",
    "notebooks/01_feature_pool_construction.ipynb",
    "notebooks/02_cohort_and_baseline.ipynb",
    "notebooks/03_llm_feature_selection.ipynb",
    "notebooks/04_ranking_reproducibility.ipynb",
    "notebooks/05_downstream_evaluation.ipynb",
    "scripts/figure_export.py",
    "scripts/render_sql.py",
    "scripts/validate_figure_quality.py",
    "scripts/verify_repository.py",
    "sql/extract_mimic_features.sql",
    "sql/validate_icd_codes.sql",
}

FORBIDDEN_SUFFIXES = {
    ".csv",
    ".tsv",
    ".xls",
    ".xlsx",
    ".jsonl",
    ".parquet",
    ".feather",
    ".npz",
    ".npy",
    ".pkl",
    ".pickle",
    ".sav",
    ".dta",
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
    ".tif",
    ".tiff",
    ".doc",
    ".docx",
    ".ppt",
    ".pptx",
}

FORBIDDEN_PATH_PARTS = {
    "_local_archive",
    "cited_papers",
    "data",
    "results",
    "outputs",
    "figures",
    "rendered_sql",
}
FORBIDDEN_PATH_PREFIXES = (
    "_audit_",
    "_consistency_",
    "_docx_",
    "_render_",
    "_revision_",
    "_supp_",
    "_validation_",
    "journal_submission_code_",
)
TEXT_SUFFIXES = {".py", ".ipynb", ".sql", ".md", ".txt", ".yml", ".yaml", ".example"}
HANGUL = re.compile(r"[\uac00-\ud7a3]")
ABSOLUTE_USER_PATH = re.compile(r"(?:[A-Za-z]:\\Users\\|/Users/|/home/)")
SECRET_PATTERN = re.compile(
    r"(?:sk-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{20,}|"
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)"
)
INSTITUTIONAL_SQL_PREFIX = "yonsei1" + ".delirium"


def public_candidates() -> list[Path]:
    command = [
        "git",
        "ls-files",
        "--cached",
        "--others",
        "--exclude-standard",
    ]
    completed = subprocess.run(
        command,
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return sorted(
        path
        for line in completed.stdout.splitlines()
        if line and (path := ROOT / line).is_file()
    )


def main() -> int:
    errors: list[str] = []
    candidates = public_candidates()
    relative_paths = {path.relative_to(ROOT).as_posix() for path in candidates}

    missing = sorted(REQUIRED_FILES - relative_paths)
    errors.extend(f"missing required file: {path}" for path in missing)

    for path in candidates:
        relative = path.relative_to(ROOT)
        relative_text = relative.as_posix()
        lower_parts = {part.lower() for part in relative.parts}

        if path.suffix.lower() in FORBIDDEN_SUFFIXES:
            errors.append(f"non-code artifact is publicly visible: {relative_text}")
        if lower_parts & FORBIDDEN_PATH_PARTS:
            errors.append(f"generated/data directory is publicly visible: {relative_text}")
        if any(
            part.lower().startswith(FORBIDDEN_PATH_PREFIXES) for part in relative.parts
        ):
            errors.append(f"local working directory is publicly visible: {relative_text}")

        if path.suffix.lower() not in TEXT_SUFFIXES and path.name not in {
            ".gitignore",
            "LICENSE",
        }:
            continue

        text = path.read_text(encoding="utf-8", errors="replace")
        if path.resolve() != Path(__file__).resolve() and ABSOLUTE_USER_PATH.search(text):
            errors.append(f"absolute user path found: {relative_text}")
        if INSTITUTIONAL_SQL_PREFIX in text.lower():
            errors.append(f"institution-specific SQL identifier found: {relative_text}")
        if SECRET_PATTERN.search(text) and path.name != ".env.example":
            errors.append(f"possible credential found: {relative_text}")
        if path.suffix.lower() in {".py", ".ipynb", ".sql"} and HANGUL.search(text):
            errors.append(f"Korean text found in public code: {relative_text}")

        if path.suffix.lower() == ".ipynb":
            notebook = json.loads(text)
            for index, cell in enumerate(notebook.get("cells", [])):
                if cell.get("cell_type") == "code":
                    if cell.get("execution_count") is not None or cell.get("outputs"):
                        errors.append(
                            f"stored notebook output found: {relative_text}, cell {index}"
                        )

    if errors:
        print("Repository verification failed:")
        for error in sorted(set(errors)):
            print(f"  - {error}")
        return 1

    print(f"Repository verification passed: {len(candidates)} public code files checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
