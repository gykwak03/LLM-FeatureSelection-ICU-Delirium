# Final Methods and Results Outline

현재 원고의 **Downstream evaluation → Statistical analysis** Methods 순서는 유지하면서, Results는 **재현성 → 순위 차이 → run별 성능 → 전체 downstream → conventional 비교**로 전개한다.

## Final Methods

### 1. Study Design and Cohort

- MIMIC-IV version 및 연구 설계
- ICU 입원 후 첫 24시간을 observation window로 설정
- Incident delirium 정의
- CAM-ICU 및 RASS 기준
- 포함·제외 기준
- 최종 코호트 32,574명, 섬망 2,728명(8.37%)

### 2. Candidate Feature Pool

- 11편의 기존 ICU delirium prediction 연구
- 215개 원래 변수명을 107개 feature로 통합
- Identity rule
- Determinacy rule
- 전체 feature mapping과 제외 사유는 Supplementary에 수록

### 3. Feature Extraction and Operational Definitions

- 첫 24시간 내 변수 추출
- 107 features에서 151 columns 생성
- 반복 측정 변수의 minimum/maximum 처리
- MIMIC Code Repository 활용
- 결측값 처리 정책
- 데이터 누출 방지 기준

### 4. LLM-Based Feature Importance Estimation

#### 4.1 Scoring-Based Importance

- 각 feature를 독립적으로 평가
- 0–1 importance score 생성
- 평균 score를 이용한 최종 순위

#### 4.2 Direct Ranking-Based Importance

- Feature들의 상대적 순위를 직접 생성
- Group 분할 및 pairwise merging 과정
- Run별 순위 산출

#### 4.3 Sequencing-Based Importance

- 이미 선택된 feature를 조건으로 다음 feature를 반복 선택
- 선택 순서를 최종 ranking으로 사용

#### 4.4 Log-Prior-Based Importance

- **log P(Y) − log P(N)** 사용
- GPT-4.1에서만 수행
- Token-level log probability 사용
- Floor truncation이 발생하지 않았음을 확인

### 5. Experimental Setup and Rank Aggregation

- GPT-4.1, Claude Sonnet 4.5, Gemini 2.5 Pro
- Temperature=0, top-p=1
- 5회의 반복 실행
- GPT에서는 API seed를 사용하고, Claude/Gemini에서는 42–46이 반복 실행 식별자라는 점을 명확히 기술
- Run별 결과와 aggregated ranking을 모두 생성

Aggregation 방식:

- Scoring: run별 score를 평균한 후 ranking
- Ranking·Sequencing·LMprior: run별 rank를 평균
- Aggregated ranking은 주 downstream 분석에 사용
- 개별 run ranking은 run-level sensitivity analysis에 사용

### 6. Downstream Evaluation

#### 6.1 Primary Feature-Budget Analysis

- Aggregated ranking 사용
- XGBoost를 대표 classifier로 사용
- k = 5, 10, 20, 30, …, 107
- 10개 LLM procedure
- Random-k 및 bottom-k control
- Stratified 5-fold cross-validation

#### 6.2 Run-Level Downstream Stability Analysis

새로 추가할 핵심 분석이다.

- 각 procedure의 5개 run에서 Top-30을 각각 선택
- 총 50개 run-specific feature set 평가
- 동일한 CV folds와 XGBoost 사용
- 각 procedure에서 AUROC/AUPRC의 평균, SD, 범위 산출
- Aggregated ranking의 성능과 개별 run 성능을 비교

핵심 질문:

> Feature membership의 run-to-run instability가 downstream performance instability로 이어지는가?

#### 6.3 Procedure-Specific Performance at k=30

- 10개 LLM procedure 각각 평가
- AUROC 및 95% CI
- AUPRC 및 95% CI
- 최고 AUROC 방법을 기준으로 paired bootstrap difference 계산
- AUROC는 primary discrimination metric
- AUPRC는 class imbalance를 고려한 key secondary metric

#### 6.4 Robustness Across Downstream Classifiers

k=30에서 다음 classifier를 비교한다.

- XGBoost
- LightGBM
- Random forest
- L2-regularised logistic regression

#### 6.5 Comparison with Conventional Feature Selection

- L1-regularised logistic regression
- Mutual information
- Gradient-boosted tree gain importance
- Selection은 각 training fold 내부에서 수행해 leakage 방지
- k=10, 30, 50에서 LLM과 비교
- AUROC와 AUPRC 모두 제시
- k=30은 pre-specified primary comparison
- 각 conventional method에서 5개 fold에 공통으로 선택된 feature 수 보고

#### 6.6 Missingness Sensitivity Analysis

- 전체 107 features
- Missingness <70%
- Missingness <50%
- Missingness <30%

위 조건에서 full-pool 성능을 비교한다. 전체 결과는 Supplementary에 수록하고, 본문에는 한 문장만 제시한다.

### 7. Statistical Analysis

#### 7.1 Ranking Reproducibility

- Run pair 간 Kendall τ-b
- Spearman ρ
- Scoring의 ties 때문에 Kendall τ-b를 primary measure로 사용
- Run-level agreement를 cross-model/cross-method correlation의 ceiling으로 사용

#### 7.2 Top-Rank Agreement

- RBO
- Top-10 overlap
- Top-20 overlap
- Top-30 overlap

#### 7.3 Variance Decomposition

- Model
- Method
- Model×method interaction
- Within-condition run-to-run variability

세 가지 estimator를 나란히 보고하고, 정확한 점추정값보다 성분의 순서를 해석한다.

#### 7.4 Score Resolution

- Scoring의 distinct score 수
- Tied features 수
- Top-k boundary의 동률 여부

Terminal-digit/rounding-bias 분석은 삭제한다.

#### 7.5 Predictive Performance

- Pooled out-of-fold predictions
- 환자 단위 bootstrap 2,000회
- AUROC/AUPRC 95% CI
- 동일 환자를 평가하므로 paired bootstrap difference 사용
- Run-level 성능은 5개 반복의 평균, SD 및 범위로 기술

## Final Results

Results 시작에는 별도의 **Highly Ranked Clinical Features** 절을 두지 않는다. 코호트 규모와 outcome prevalence만 2–3문장으로 간단히 제시하고, 전체 feature ranking은 Supplementary로 보낸다.

### 1. Inter-Run Reproducibility and Score Resolution

현재 Table 1 중심으로 구성한다.

핵심 결과:

- Scoring이 가장 안정적
- Sequencing은 중간
- Ranking은 가장 불안정
- Claude Sonnet–Scoring의 run-to-run 변동이 가장 작음
- Scoring은 distinct score가 16–32개에 불과하고 ties가 많음
- 따라서 높은 안정성을 높은 score resolution 또는 높은 predictive performance로 해석할 수 없음

Seed/run ceiling 전체 표는 Supplementary로 보내고 본문에는 범위만 제시한다.

### 2. Cross-Model and Cross-Method Agreement

핵심 메시지:

> 같은 LLM에서 서로 다른 방법을 사용한 경우보다, 같은 방법을 서로 다른 LLM에 적용한 경우에 ranking similarity가 전반적으로 높았다.

- 본문: 9×9 Kendall τ-b heatmap
- Supplementary: 전체 Spearman/Kendall correlation tables

### 3. Top-k Agreement and Sources of Ranking Variability

#### 3.1 Top-k Agreement

- 같은 method·다른 LLM
  - Top-10 평균 7.56
  - Top-20 평균 14.67
  - Top-30 평균 21.44
- 같은 LLM·다른 method
  - Top-10 평균 6.56
  - Top-20 평균 13.22
  - Top-30 평균 18.56

핵심 해석:

> 임상적으로 중요한 공통 core는 존재했지만, 실제 선택되는 feature membership은 method와 model에 따라 의미 있게 달라졌다.

#### 3.2 Variance Decomposition

- Method: 가장 큰 systematic source
- Run-to-run variability: 두 번째
- Model×method interaction: 중간
- Model 자체: 가장 작은 기여

Top-k overlap과 variance decomposition은 하나의 composite figure로 묶을 수 있다.

### 4. Characteristics of Log-Prior Scoring

- 재현성은 Scoring·Sequencing보다 낮고 Ranking보다 높음
- 535 observations에서 410 distinct scores
- Score resolution이 가장 높음
- Scoring과 가장 높은 rank correlation
- Flat ranking distribution

Small-k downstream 성능은 이 절에서 결론 내리지 않고 뒤의 Downstream section에서 다룬다.

### 5. Downstream Predictive Utility of LLM-Selected Features

#### 5.1 Run-Level Downstream Stability

새 분석을 가장 먼저 제시한다.

질문:

> 개별 run에서 Top-30 feature가 달라지면 AUROC/AUPRC도 함께 달라지는가?

제시할 결과:

- Procedure별 5개 점
- AUROC/AUPRC 평균, SD, 범위
- Aggregated ranking 성능을 별도 표시
- 가능하면 Ranking, Scoring, Sequencing의 performance variability 비교

성능이 안정적이라면:

> Feature membership varied across runs, whereas downstream discrimination remained comparatively stable.

성능도 흔들린다면:

> Aggregating rankings across repeated runs improved the stability of downstream performance.

#### 5.2 Feature-Budget Analysis

현재 Table 8과 Figure 5 내용이다.

- LLM vs random
- LLM vs bottom-k
- k 증가에 따른 AUROC/AUPRC
- k=30에서 full-pool AUROC의 약 93% 회복
- 작은 feature budget에서 LLM의 이점이 가장 큼

#### 5.3 Comparison Among the Ten LLM Procedures

현재 Table 10을 확장한다.

| Procedure | AUROC (95% CI) | AUPRC (95% CI) | ΔAUROC vs best (95% CI) | p |
|---|---|---|---|---|

핵심 결과:

- GPT Ranking이 AUROC 기준 수치상 1위
- 상위 3개 procedure는 AUROC에서 명확하게 분리되지 않음
- AUROC와 AUPRC의 procedure 순위가 완전히 동일하지 않음
- LMprior는 작은 k에서 상대적으로 낮지만 random보다는 높음

#### 5.4 Robustness Across Classifiers

현재 Table 9 내용이다.

- 비선형 classifier 간 procedure 순위는 대체로 유지
- Logistic regression에서는 일부 순서가 달라짐
- LLM selection의 유용성이 특정 classifier 하나에만 의존하지 않음

#### 5.5 Missingness Sensitivity

본문에는 다음 한 문장만 제시한다.

> Excluding features with missingness exceeding 30%, 50% or 70% produced virtually unchanged discrimination, with AUROC ranging from 0.8403 to 0.8412.

전체 결과는 Supplementary로 보낸다.

### 6. Comparison with Conventional Data-Driven Feature Selection

논문의 마지막 Results subsection이다.

#### 6.1 Comparison Across Feature Budgets

- k=10
- k=30
- k=50

위 feature budget에서 LLM과 conventional methods를 비교한다.

가능하면 다음 항목을 figure로 함께 표시한다.

- LLM mean/range
- XGBoost gain
- L1
- Mutual information

#### 6.2 Detailed Comparison at k=30

현재 Table 11을 확장한다.

| Selection procedure | Type | AUROC (95% CI) | AUPRC (95% CI) | Features stable across folds |
|---|---|---|---|---:|

최종 메시지:

> LLM-based selection produced informative and compact feature subsets without access to patient-level data. However, at the pre-specified feature budget of k=30, and where labelled training data were available, gain-based and L1-regularised selection achieved higher discrimination.

## 본문과 Supplementary 배치

| 본문 | Supplementary |
|---|---|
| Reproducibility Table | 전체 run-pair ceiling |
| Kendall heatmap | 전체 cross-model/cross-method correlation |
| Top-k 요약 또는 composite figure | 27개 RBO/Top-k pair |
| Variance decomposition | Feature별 variance components |
| LMprior 요약 | 전체 LMprior feature scores |
| Run별 downstream figure | Run별 상세 성능표 |
| k-sweep figure | 전체 k×procedure 결과 |
| 10개 procedure AUROC/AUPRC CI | 전체 paired bootstrap table |
| Classifier robustness | Fold별 상세 결과 |
| Conventional comparison | Conventional selection feature 목록 |
| Missingness 결과 한 문장 | 전체 missingness sensitivity table |
| — | 전체 feature rankings |

표를 Supplementary로 이동하거나 새 분석을 추가하면 현재 Table 8–11의 번호는 바뀐다. 지금 단계에서는 **현재 Table 8의 내용**처럼 관리하고, 원고 구조가 확정된 뒤 마지막에 일괄 재번호를 매기는 것이 좋다.
