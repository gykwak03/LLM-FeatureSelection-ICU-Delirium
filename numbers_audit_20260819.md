# 원고 수치 검증 — GYPaper_RY1_20260819.docx

노트북 3·4의 원자료(JSONL)에서 직접 재계산해 대조. 2026-08-19.

---

## A. 반드시 고쳐야 할 것

### A-1. "2.68" — 정의 불일치 + 사실 오류 (para 126)

> Run to run it was the most reproducible of the four methods: over the top 30 features
> the mean standard deviation of the rank across seeds was 2.68, below even the Scoring
> method with Claude Sonnet 4.5 (2.98)...

**문제 1 — Table 1과 다른 정의로 계산된 값이다.**

노트북의 `top30_std_mean()` 은 SD 내림차순 정렬 후 상위 30개를 취한다. 즉 **"가장 변동이 큰
30개"** 이지 "상위 30개 feature" 가 아니다. Table 1의 모든 값이 이 정의다.

| 방법 / 모델 | ① 변동 큰 30개 (Table 1 정의) | ② 상위 랭크 30개 | 전체 107개 |
|---|---|---|---|
| Scoring / GPT-4.1 | 5.8492 | 1.1572 | 2.5326 |
| Scoring / Gemini 2.5 Pro | 5.5484 | 1.1294 | 2.0398 |
| Scoring / Claude Sonnet 4.5 | 2.9847 | 1.0066 | 1.1784 |
| Ranking / GPT-4.1 | 28.1461 | 9.7626 | 16.8252 |
| Ranking / Gemini 2.5 Pro | 22.9632 | 7.1142 | 12.9650 |
| Ranking / Claude Sonnet 4.5 | 21.0322 | 7.7477 | 11.8312 |
| Sequencing / GPT-4.1 | 7.6255 | 2.0555 | 3.6646 |
| Sequencing / Gemini 2.5 Pro | 9.0305 | 1.8604 | 4.3681 |
| Sequencing / Claude Sonnet 4.5 | 9.1358 | 3.0638 | 4.5465 |
| **LMprior / GPT-4.1** | **11.7111** | **2.6750** | 4.8093 |

**2.68 = ②번 정의의 LMprior 값.** 그런데 이 문장은 그 값을 ①번 정의로 계산된
2.98 / 21.03 / 28.15 와 나란히 비교하고 있다. 서로 다른 자를 댄 것이다.
노트북 §4·§9 는 LMprior 값으로 **11.7111** 을 출력한다.

**문제 2 — "most reproducible of the four methods" 는 어느 정의로도 거짓이다.**

- ① 정의: LMprior 11.71 → Scoring(2.98–5.85), Sequencing(7.63–9.14) 보다 나쁨. **4개 중 3위.**
- ② 정의: LMprior 2.68 → Scoring(1.01–1.16) 보다 나쁨. **4개 중 3위.**

두 정의 모두에서 **가장 재현성 높은 방법은 Scoring** 이다.

**수정 방향 (권장):** Table 1 정의(①)를 유지하고 para 126을 다음 취지로 다시 쓴다 —
"LMprior 의 seed 간 변동은 11.71 로 Ranking(21.03–28.15)보다 뚜렷이 낮았으나
Scoring(2.98–5.85)과 Sequencing(7.63–9.14)에는 미치지 못했다."
LMprior 의 진짜 강점은 재현성이 아니라 **동점 없음(410/535 distinct)** 이므로 그쪽으로 논지를 옮길 것.

---

### A-2. Table 1 캡션·본문의 정의 서술이 코드와 다름 (Table 1 caption, para 99, 150, abstract)

> "computed over the top 30 features of each procedure"
> "Across the top 30 features of each procedure..."

독자는 "중요도 상위 30개"로 읽는다. 코드는 "변동 상위 30개"를 쓴다.
**숫자는 코드대로 맞지만 설명이 틀렸다.** Table 1 전체와 이를 인용한 모든 문장이 해당된다.

두 선택지:

- **(권장) 문구만 수정** → "the 30 features with the largest across-seed variation".
  기존 숫자 2.98 / 5.55 / 5.85 / 7.63 / 9.03 / 9.14 / 21.03 / 22.96 / 28.15 전부 유지.
  가장 보수적인(worst-case) 통계라는 점을 근거로 명시하면 오히려 강한 서술이 된다.
- **정의 변경** → 위 표 ②열로 전부 교체. 논지(Scoring≪Sequencing≪Ranking)는 동일하나
  abstract·Results·Discussion 의 모든 인용 숫자를 바꿔야 한다.

---

## B. 확인이 필요한 불일치

### B-1. para 97 본문 ↔ Supplementary 평균 순위표 (상위 2개 순서가 바뀜)

본문 값은 **10개 절차의 "평균 순위"를 평균**한 것 — 재계산 결과 **전부 정확히 일치**한다.
그러나 `combined_ranks.csv` (= SI 표로 추정)는 **10개 절차의 "정수 순위 위치"를 평균**한다.

| Feature | 본문 (para 97) | combined_ranks.csv |
|---|---|---|
| Sedation Use | 3.82 (2위) | **3.4 (1위)** |
| Glasgow Coma Scale | **3.74 (1위)** | 3.6 (2위) |
| SOFA Score | 5.32 | 5.1 |
| Dementia | 5.68 | 5.1 |
| Mechanical Ventilation | 5.68 | 5.3 |
| Age | 7.80 | 7.6 |
| Sepsis | 7.84 | 7.7 |
| APACHE Score | 9.68 | 9.1 |
| Use Of Midazolam | 9.78 | 9.1 |
| Vasopressor Use | 10.76 | 10.3 |

**본문은 GCS 를 1위로, SI 는 Sedation Use 를 1위로 제시하게 된다.** 규약을 하나로 통일할 것.

### B-2. 분석부 top-30 ≠ downstream 에 실제 투입된 top-30

노트북 4는 `combined_ranks.csv` 에서 top-k 를 뽑고, 노트북 3은 JSONL 에서 재계산한다.
Scoring 계열에서 두 집합이 어긋난다.

| 절차 | top-30 일치 |
|---|---|
| score_gpt | 27/30 |
| score_gemini | 27/30 |
| score_claude | 28/30 |
| seq_gpt | 29/30 |
| 나머지 6개 | 30/30 |

**원인:** Scoring 이 16–32개 값으로 붕괴하므로 30위 경계가 동점 블록 안에 들어가
"top 30" 이 유일하게 정해지지 않는다. 논문이 이미 보고한 동점 현상의 직접적 귀결이다.

→ 숨기지 말고 Methods 또는 Limitations 에 한 문장으로 적을 것:
"Scoring 계열은 동점 때문에 30위 경계가 유일하지 않아, 동점 처리 방식에 따라 선택 집합이
30개 중 2–3개 달라진다." 오히려 논문의 동점 논지를 강화한다.

### B-3. para 117 서술이 과함

> the Ranking method ... exceeded its seed ceiling of 0.612 to 0.797

Ranking 의 교차모델 평균은 **0.779** 로 상한 범위 최댓값 0.797 을 넘지 않는다.

참인 서술 두 가지:
- 교차모델 평균(0.779) > **평균 천장(0.722)**
- **Gemini vs Claude 쌍(0.8578)** 은 Ranking 의 모든 모델 천장(0.612 / 0.757 / 0.797)을 초과

para 162 의 "meeting or exceeding" 이 정확한 표현. 두 문단을 일치시킬 것.

### B-4. para 101 ↔ para 112 서로 모순 (Figure 3 해석)

| | para 101 | para 112 |
|---|---|---|
| Ranking | "broader distributions with heavier tails" | "bell-shaped ... concentrate around central values" |
| Sequencing | "narrower and more sharply concentrated" | "flatter and closer to uniform" |

두 방법 모두 정반대로 서술돼 있다. para 101 이 구버전 잔재로 보인다.
(별도 권고: 평균순위 히스토그램은 107개 순열의 평균이라 구조적으로 균등에 가깝다.
정보량이 낮으므로 Figure 3 자체를 부록으로 내리고 Table 1 + 분산분해로 논지를 세우는 편이 낫다.)

---

## C. 재계산 결과 "정확함"으로 확인된 항목

전부 원자료에서 재계산해 일치를 확인했다.

**순위 일관성·상관 (§6)**
- seed 천장: Scoring 0.9853–0.9946, Sequencing 0.9658–0.9742, Ranking 0.6124–0.7969 ✓
- 교차모델 Spearman: Scoring 0.8476–0.9028, Sequencing 0.8246–0.8921 ✓
- 교차모델 평균: Scoring 0.881, Ranking 0.779 ✓ / 천장 대비 89% ✓
- 교차기법: Scoring–Sequencing 0.4648 / 0.5090 / 0.6314 ✓, Scoring–Ranking 0.7548–0.8417 ✓
- top-30 겹침: 교차모델 18–24, 교차기법 13–22, 천장 19.3–28.3 ✓

**분산분해 (§7)**
- Method 37.1% [33.0, 41.3], Seed 31.2% [28.3, 34.2], 상호작용 17.1% [15.1, 19.2], Model 14.6% [12.2, 17.0] ✓

**LMprior (§8)**
- vs Scoring 0.843 / 0.666, vs Ranking 0.741 / 0.552, vs Sequencing 0.656 / 0.477 ✓
- distinct score 410 / 535 ✓, floor truncation 0건 (Y·N 모두 535회 전부 관측) ✓

**말단 숫자 편향** (노트북 외부 분석이나 원자료에서 전부 재현됨)
- GPT-4.1: 535개 중 433개(80.9%)가 2로 끝남, χ²=3057.2, distinct 32, 소수점 최대 3자리,
  상위 3개 값(0.712 / 0.312 / 0.642) 합계 214 ✓
- Gemini 2.5 Pro: 519개(97.0%)가 5로 끝남, χ²=4504.0, distinct 16, 0.785 가 164회, 평균 0.719 ✓
- Claude Sonnet 4.5: 447개(83.6%)가 0 또는 5로 끝남, distinct 23 ✓

**Downstream (§5–6)**
- k sweep 전 구간 ✓ (k=5 0.7007/0.6166/0.5974, k=10 0.7292/0.6862/0.6528,
  k=30 0.7826/0.7665/0.7170, k=50 0.8066/0.7896/0.7550, k=107 0.8404/0.8409/0.8410)
- 회수율 93.1% (k=30), 96.0% (k=50) ✓
- random 대비 우위 0.084 / 0.043 / 0.016 / 0.017 ✓
- k=30 AUROC 0.7603–0.7958, rank_gpt 0.7958 [0.7876, 0.8041] ✓
- paired diff: rank_gemini 0.0041 [−0.0018, 0.0097] p=0.159 ✓, seq_claude 0.0058 [−0.0003, 0.0117] p=0.061 ✓, 나머지 7개 유의 ✓
- 절차 간 폭 0.036 vs bottom-k 대비 공통 마진 0.066 ✓
- 분류기별 평균: XGBoost 0.7826, LightGBM 0.7817, RF 0.7773, LR 0.7501 ✓
  (본문 XGBoost 0.7825 → 0.7826 으로 통일 권장)
- 분류기 순서 상관: 비선형 3종 0.842–0.952 ✓, LR 대 나머지 0.503–0.600 ✓
- 최고 절차: XGB/LGBM/RF 는 rank_gpt, LR 은 score_gemini ✓
- 기법별 3모델 평균: Ranking 0.7154 / 0.7421 / 0.7922 / 0.8104 ✓, k=30 Sequencing 0.7796, Scoring 0.7792 ✓
- LMprior k=5 0.6598 (10위/10) → k=30 0.7725 (9위/10) ✓
- 통계적 대조군: xgb_gain 0.8282 [0.8208, 0.8359], LASSO 0.8199 [0.8123, 0.8277] vs 0.7958 ✓
  마진 0.032 / 0.024 ✓, 회수율 98.5% ✓, mutual_info 0.7822 → 13개 중 9위 ✓
- fold 간 유지 feature 11–21 / 30 ✓
- 코호트 32,574 / 2,728 (8.37%) / 107 feature → 151 컬럼 ✓

---

## D. 문장 오류

- **para 45**: "...of whom 2,728 (8.37%) developed delirium. **were male.**"
  — 문장 조각이 남아 있고 성별 분포 수치가 빠졌다.
- **para 28**: "achieving **achieving** areas under..." — 중복.
- **para 133 / 134**: k=30 LLM 평균이 0.7825 로 적혀 있으나 재계산값은 0.7826.

---

## E. 우선순위

1. A-1 (2.68 + "most reproducible" 주장) — 사실 오류. 심사자가 Table 1과 대조하면 바로 드러남
2. A-2 (Table 1 정의 서술) — 캡션 한 줄 수정으로 해결 가능
3. B-1 (본문 ↔ SI 순위 규약) — 1위 feature 가 달라짐
4. B-4 (para 101 ↔ 112 모순)
5. B-2 (top-30 동점 경계) — Limitations 한 문장
6. B-3, D
