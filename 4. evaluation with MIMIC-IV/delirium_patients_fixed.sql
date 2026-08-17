SELECT
  COUNT(*) AS total_icu_stays,
  COUNT(DISTINCT subject_id) AS unique_patients
FROM `physionet-data.mimiciv_3_1_icu.icustays`;
CREATE OR REPLACE TABLE yonsei-487322.delirium.delirium_patients AS
WITH

/* [1] 입실 후 24시간 이내 혼수 상태(RASS <= -4) 환자 식별
   - RASS itemid: 228096
   - ICU 입실 시점(intime)부터 24시간 이내 RASS <= -4가 기록된 stay 제외
*/
coma_rass AS (
  SELECT DISTINCT ce.stay_id
  FROM `physionet-data.mimiciv_3_1_icu.chartevents` ce
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` icu USING (stay_id)
  WHERE ce.itemid = 228096
    AND ce.valuenum IS NOT NULL
    AND ce.valuenum <= -4
    AND ce.charttime BETWEEN icu.intime AND TIMESTAMP_ADD(icu.intime, INTERVAL 24 HOUR)
),

/* [2] CAM-ICU 구성요소 라벨링 및 시간 구간 추출
   - 4개 구성요소:
       ① 급성 정신상태 변화 (ms_change)
       ② 주의력 장애 (inattention)
       ③ 의식수준 변화 (rass_loc)
       ④ 사고의 와해 (disorg)
   - is_after_24h: ICU 입실 후 24시간 경과 여부
*/
cam_labeled AS (
  SELECT
    ce.subject_id, ce.hadm_id, ce.stay_id, ce.charttime, ce.valuenum,
    DATE(ce.charttime) AS chart_date,
    ce.charttime > TIMESTAMP_ADD(icu.intime, INTERVAL 24 HOUR) AS is_after_24h,
    CASE
      WHEN ce.itemid IN (228300, 228337, 229326) THEN 'ms_change'
      WHEN ce.itemid IN (228301, 228336, 229325) THEN 'inattention'
      WHEN ce.itemid IN (228302, 228334)          THEN 'rass_loc'
      WHEN ce.itemid IN (228303, 228335, 229324)  THEN 'disorg'
    END AS category
  FROM `physionet-data.mimiciv_3_1_icu.chartevents` ce
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` icu USING (stay_id)
  WHERE ce.itemid IN (
    228300, 228337, 229326,
    228301, 228336, 229325,
    228302, 228334,
    228303, 228335, 229324
  )
  AND ce.charttime >= icu.intime
),

/* [3] CAM-ICU 4개 항목을 단일 평가 시점 기준으로 정리
*/
cam_pivoted AS (
  SELECT
    subject_id, hadm_id, stay_id, charttime, is_after_24h,
    MAX(IF(category = 'ms_change',  valuenum, NULL)) AS ms_change,
    MAX(IF(category = 'inattention', valuenum, NULL)) AS inattention,
    MAX(IF(category = 'rass_loc',    valuenum, NULL)) AS rass_loc,
    MAX(IF(category = 'disorg',      valuenum, NULL)) AS disorg
  FROM cam_labeled
  GROUP BY subject_id, hadm_id, stay_id, charttime, is_after_24h
  -- [수정 2026-08-06] 기존: 4개 항목이 모두 (0,1) 로 기록된 평가만 통과시켰음.
  --   CAM-ICU 는 알고리즘상 4개 항목이 모두 기록되지 않는다.
  --     - Feature 1(급성변화) 또는 2(주의력장애)가 음성이면 3·4 는 평가하지 않음
  --     - Feature 3(의식수준)에서 양성이면 4(사고와해)는 평가하지 않음
  --   따라서 NULL 은 결측이 아니라 알고리즘의 정상 동작이며, 이를 제외하면
  --   CAM-ICU 양성 판정의 약 90%(117,016건 중 105,134건)가 소실된다.
  --   양성 판정식 자체가 NULL-safe 하므로(NULL 비교는 FALSE), 최소 요건만 남긴다.
  HAVING ms_change IS NOT NULL
    AND inattention IS NOT NULL
),

/* [4] 입실 24시간 이내 섬망 발생 환자 식별 (제외 대상)
   - CAM-ICU 양성 정의:
       ms_change = 1 AND inattention = 1 AND (rass_loc = 1 OR disorg = 1)
*/
early_delirium AS (
  SELECT DISTINCT stay_id
  FROM cam_pivoted
  WHERE NOT is_after_24h
    AND ms_change = 1.0
    AND inattention = 1.0
    AND (rass_loc = 1.0 OR disorg = 1.0)
),

/* [5] 입실 24시간 이후 RASS >= -3 시점의 CAM-ICU 양성 여부 판정
   - RASS itemid: 228096
   - 동일 charttime 기준 RASS >= -3 이면서 CAM-ICU 양성인 경우 섬망으로 판정
*/
rass_after24 AS (
  SELECT
    ce.stay_id,
    ce.charttime,
    ce.valuenum AS rass_score
  FROM `physionet-data.mimiciv_3_1_icu.chartevents` ce
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` icu USING (stay_id)
  WHERE ce.itemid = 228096
    AND ce.valuenum IS NOT NULL
    AND ce.charttime > TIMESTAMP_ADD(icu.intime, INTERVAL 24 HOUR)
),

delirium_after24 AS (
  SELECT
    cp.stay_id,
    cp.charttime,
    CASE
      WHEN cp.ms_change = 1.0
       AND cp.inattention = 1.0
       AND (cp.rass_loc = 1.0 OR cp.disorg = 1.0)
      THEN TRUE
      ELSE FALSE
    END AS delirium
  FROM cam_pivoted cp
  WHERE cp.is_after_24h
),

/* [6] stay 단위 섬망 요약
   - RASS >= -3 시점에서 CAM-ICU 양성이 한 번이라도 있으면 섬망
   - RASS와 CAM-ICU 시점을 1시간 이내로 매칭
*/
delirium_with_rass AS (
  SELECT
    d.stay_id,
    d.charttime,
    d.delirium
  FROM delirium_after24 d
  JOIN rass_after24 r
    ON d.stay_id = r.stay_id
    AND ABS(TIMESTAMP_DIFF(d.charttime, r.charttime, MINUTE)) <= 60
    AND r.rass_score >= -3
  WHERE d.delirium = TRUE
),

delirium_summary AS (
  SELECT
    stay_id,
    TRUE AS has_delirium_ever,
    MIN(charttime) AS first_delirium_time
  FROM delirium_with_rass
  GROUP BY stay_id
),

/* [7] 전체 ICU 환자 기반 코호트 구성
   - icustays를 기준 테이블로 사용
   - delirium_summary를 LEFT JOIN하여 섬망 여부 결합
   - CAM-ICU 평가가 없거나 음성인 환자는 has_delirium_ever = FALSE
*/
cohort AS (
  SELECT
    i.subject_id,
    i.hadm_id,
    i.stay_id,
    COALESCE(ds.has_delirium_ever, FALSE) AS has_delirium_ever,
    ds.first_delirium_time,
    p.anchor_age,
    i.intime,
    i.outtime,
    adm.deathtime,
    ROW_NUMBER() OVER (PARTITION BY i.subject_id ORDER BY i.intime) AS rn,
    TIMESTAMP_DIFF(i.outtime, i.intime, HOUR) AS icu_hours
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.patients` p ON i.subject_id = p.subject_id
  JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm ON i.hadm_id = adm.hadm_id
  LEFT JOIN delirium_summary ds ON i.stay_id = ds.stay_id
)

/* [8] 최종 코호트 조건 적용
   - 첫 ICU stay
   - ICU 재원기간 24시간 이상
   - 성인(18세 이상)
   - 입실 후 48시간 이내 사망 환자 제외
   - 초기 혼수 및 초기 섬망 환자 제외
*/
SELECT
  subject_id,
  hadm_id,
  stay_id,
  has_delirium_ever,
  first_delirium_time,
  0 AS total_assessments
FROM cohort
WHERE rn = 1
  AND icu_hours >= 24
  AND anchor_age >= 18
  AND (deathtime IS NULL OR TIMESTAMP_DIFF(deathtime, intime, HOUR) > 48)
  AND stay_id NOT IN (SELECT stay_id FROM coma_rass)
  AND stay_id NOT IN (SELECT stay_id FROM early_delirium);