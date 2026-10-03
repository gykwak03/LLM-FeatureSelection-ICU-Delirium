# ICU 섬망 예측을 위한 LLM 기반 변수 선택

이 저장소는 논문의 재현을 위한 **코드 전용 저장소**입니다.

## 데이터 공개 원칙

다음 파일은 저장소에 포함하지 않습니다.

- MIMIC-IV 원자료 및 cohort 추출본
- 환자 수준 파생 데이터와 예측 결과
- CSV, XLS/XLSX, JSONL, NPZ 등의 분석 산출물
- LLM 원응답 로그
- 생성된 figure와 PDF

루트 `.gitignore`는 `data/`, `results/`, `outputs/`, `figures/` 디렉터리와 주요 데이터·이미지 형식을 전역적으로 제외합니다. 가능하면 제한 데이터는 저장소 외부에 보관하고, 분석 직전 `MIMIC_IV_DATA_PATH`로 경로를 지정하십시오.

공개 전에는 반드시 다음 명령으로 추적 파일을 확인합니다.

```bash
git status --short --ignored
git ls-files
python scripts/verify_repository.py
```

## 코드 구성

두 자리 숫자 접두사로 권장 실행 순서를 표시합니다.

```text
notebooks/
  01_feature_pool_construction.ipynb
  02_cohort_and_baseline.ipynb
  03_llm_feature_selection.ipynb
  04_ranking_reproducibility.ipynb
  05_downstream_evaluation.ipynb
scripts/
sql/
```

노트북 실행 순서는 위 목록 순서입니다.

## SQL 사용

SQL에는 기관 프로젝트명이 직접 들어 있지 않습니다. 다음 명령으로 자신의 BigQuery 식별자를 주입한 실행용 SQL을 생성합니다.

```bash
python scripts/render_sql.py \
  --work-project YOUR_GCP_PROJECT \
  --work-dataset YOUR_WORKING_DATASET \
  --cohort-table YOUR_DELIRIUM_COHORT_TABLE
```

생성된 SQL은 Git에서 제외되는 `rendered_sql/`에 저장됩니다. BigQuery 결과를 Git이 추적하는 경로로 export하지 마십시오.

## Figure 출력

코드로 생성하는 일반 scientific figure는 폰트를 포함한 vector PDF를 primary submission format으로 사용합니다. PNG는 supplementary/fallback 용도로만 생성합니다.

- photograph/continuous-tone raster: 최소 300 dpi
- bitmap line drawing: 최소 1,000 dpi
- Matplotlib·seaborn plot, line chart, scatter plot, flow diagram: 가능한 한 vector 유지

생성 후 `python scripts/validate_figure_quality.py`로 PDF 폰트 포함 여부, raster 객체 여부, PNG 실제 픽셀 크기 및 dpi를 검증합니다. Figure 출력물은 코드 저장소가 아니라 저널 제출 시스템에 별도로 올립니다.

## 라이선스

소스 코드는 MIT License로 배포합니다. MIMIC-IV 및 제3자 데이터는 해당 데이터 제공자의 접근·사용 조건을 따르며 이 라이선스에 포함되지 않습니다.
