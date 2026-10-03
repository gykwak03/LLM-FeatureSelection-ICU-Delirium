# LLM-Based Feature Selection for ICU Delirium Prediction

This is the code-only reproducibility repository for the study of large-language-model-based feature prioritisation for incident ICU delirium prediction.

## Data policy

No MIMIC-IV records, cohort extracts, derived patient-level data, LLM response logs, analysis tables, or generated figures are distributed in this repository. MIMIC-IV data remain subject to the PhysioNet credentialing process and data use agreement.

The root `.gitignore` intentionally excludes all `data/`, `results/`, `outputs/`, and `figures/` directories as well as common tabular, image, and model-output formats. Keep restricted inputs outside the repository when possible. If local files are stored under the repository for analysis, confirm they remain ignored before every commit:

```bash
git status --short --ignored
git ls-files
```

## Repository structure

```text
notebooks/
  01_feature_pool_construction.ipynb
  02_cohort_and_baseline.ipynb
  03_llm_feature_selection.ipynb
  04_ranking_reproducibility.ipynb
  05_downstream_evaluation.ipynb
scripts/
  figure_export.py
  generate_workflow_figure.py
  render_sql.py
  validate_figure_quality.py
  verify_repository.py
sql/
  extract_mimic_features.sql
  validate_icd_codes.sql
```

The two-digit filename prefixes define the recommended notebook execution order.

## Environment

Python 3.12 was used for the final analysis. Create a local environment with either:

```bash
python -m venv .venv
.venv/Scripts/activate
pip install -r requirements.txt
```

or:

```bash
conda env create -f environment.yml
conda activate llm-delirium-fs
```

The virtual environment is local-only and must not be committed.

## MIMIC-IV SQL

The SQL files are templates rather than institution-specific queries. Render them with identifiers for your own credentialed BigQuery environment:

```bash
python scripts/render_sql.py \
  --work-project YOUR_GCP_PROJECT \
  --work-dataset YOUR_WORKING_DATASET \
  --cohort-table YOUR_DELIRIUM_COHORT_TABLE
```

This writes executable queries to the ignored `rendered_sql/` directory. The feature-extraction query expects the cohort table to contain `subject_id`, `hadm_id`, `stay_id`, `first_delirium_time`, and `has_delirium_ever`. It creates `mimic_iv_dataset_107` by default. The public MIMIC-IV v3.1 project and dataset names can also be overridden; run `python scripts/render_sql.py --help` for all options.

Never export a BigQuery result into a tracked repository path.

## Reproduction workflow

1. Run `notebooks/01_feature_pool_construction.ipynb` with the locally available literature-extraction input.
2. Render and run `sql/validate_icd_codes.sql` and `sql/extract_mimic_features.sql` in a credentialed BigQuery environment.
3. Point `MIMIC_IV_DATA_PATH` to the restricted local cohort extract.
4. Run `notebooks/02_cohort_and_baseline.ipynb`.
5. Configure API credentials in an ignored `.env` file and run `notebooks/03_llm_feature_selection.ipynb` if the LLM experiment is to be repeated.
6. Run `notebooks/04_ranking_reproducibility.ipynb` and `notebooks/05_downstream_evaluation.ipynb` using locally generated results.

LLM calls may incur cost, and provider-side model changes can prevent bit-for-bit reproduction even when a dated model identifier is requested.

## Artwork export

Scientific plots are generated as font-embedded vector PDF files for primary journal submission. Matplotlib and seaborn plots are kept vector and are not rasterized. PNG files are generated only as supplementary or fallback output.

The export helper follows the Smart Health artwork categories:

- photographs or continuous-tone raster images: at least 300 dpi;
- bitmap line drawings: at least 1,000 dpi;
- code-generated charts and diagrams: vector PDF whenever possible.

Run `python scripts/validate_figure_quality.py` after figure generation to report the actual format, PDF font embedding, raster content, PNG dimensions, and dpi metadata. Generated artwork is ignored by Git and must be uploaded separately through the journal submission system if required.

## Repository safety check

Before publishing or creating an archive, run:

```bash
python scripts/verify_repository.py
```

The check fails when a tracked file appears to contain data, generated output, credentials, an absolute user path, Korean code comments, or institution-specific SQL identifiers.

## License

The source code is released under the MIT License. MIMIC-IV and all third-party datasets retain their own access and licensing terms and are not covered by this repository license.
