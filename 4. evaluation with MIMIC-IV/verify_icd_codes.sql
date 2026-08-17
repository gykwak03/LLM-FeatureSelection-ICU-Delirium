-- ==============================================================================
-- verify_icd_codes.sql — ICD 코드 선언 검증 (mimic_iv_107.sql 부속)
--
--   목적 : 사람이 눈으로 100여 개 코드를 대조하는 대신, MIMIC-IV 자체 사전과
--          mimic-code 공식 파생 테이블을 기준으로 기계적으로 검증한다.
--
--   [V1] 존재성 검증 — 선언한 코드 접두사가 d_icd_diagnoses 에 실제로 존재하는가
--   [V2] 일치도 검증 — 직접 구현한 동반질환 vs mimic-code derived.charlson
--   [V3] 유병률 검증 — 각 변수의 유병률이 임상적으로 납득 가능한 범위인가
--   [V4] CVD 개별 코드 조회 — 신규 정의 23개 코드의 공식 병명 출력
--
--   ※ 각 블록을 따로 실행할 것. 전부 읽기 전용이다.
-- ==============================================================================


-- ==============================================================================
-- [V1] 존재성 검증
--   선언한 접두사로 매칭되는 코드가 0건이면 오타이거나 MIMIC-IV 에 없는 코드다.
--   n_codes = 0 인 행이 있으면 반드시 확인할 것.
-- ==============================================================================
WITH declared AS (
  SELECT 'nicotine_dependence' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['3051', 'V1582']) AS p
  UNION ALL
  SELECT 'nicotine_dependence' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['F17']) AS p
  UNION ALL
  SELECT 'has_anemia' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['280', '281', '282', '283', '284', '285']) AS p
  UNION ALL
  SELECT 'has_anemia' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['D50', 'D51', 'D52', 'D53', 'D55', 'D56', 'D57', 'D58', 'D59', 'D60', 'D61', 'D62', 'D63', 'D64']) AS p
  UNION ALL
  SELECT 'alcohol_abuse' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['2915', '2916', '2917', '2918', '2919', '3030', '3039', '3050', '3575', '4255', '5353', '5710', '5711', '5712', '5713', '980', 'V113']) AS p
  UNION ALL
  SELECT 'alcohol_abuse' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['E52', 'F10', 'G621', 'K292', 'K700', 'K703', 'K709', 'T51', 'Z502', 'Z714', 'Z721']) AS p
  UNION ALL
  SELECT 'heart_failure' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['39891', '40201', '40211', '40291', '40401', '40403', '40411', '40413', '40491', '40493', '4254', '4255', '4256', '4257', '4258', '4259', '428']) AS p
  UNION ALL
  SELECT 'heart_failure' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['P290']) AS p
  UNION ALL
  SELECT 'cerebrovascular_disease' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['36234', '430', '431', '432', '433', '434', '435', '436', '437', '438']) AS p
  UNION ALL
  SELECT 'cerebrovascular_disease' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['G45', 'G46', 'H340']) AS p
  UNION ALL
  SELECT 'copd' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['4168', '4169', '490', '491', '492', '493', '494', '495', '496', '497', '498', '499', '500', '501', '502', '503', '504', '505', '5064', '5081', '5088']) AS p
  UNION ALL
  SELECT 'copd' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['J40', 'J41', 'J42', 'J43', 'J44', 'J45', 'J46', 'J47', 'J60', 'J61', 'J62', 'J63', 'J64', 'J65', 'J66', 'J67', 'J684', 'J701', 'J703']) AS p
  UNION ALL
  SELECT 'dementia' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['290', '2941', '3312']) AS p
  UNION ALL
  SELECT 'dementia' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['F00', 'F01', 'F02', 'F03', 'F051', 'G30', 'G311']) AS p
  UNION ALL
  SELECT 'depression' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['2962', '2963', '2965', '3004', '309', '311']) AS p
  UNION ALL
  SELECT 'depression' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['F204', 'F313', 'F314', 'F315', 'F32', 'F33', 'F341', 'F412', 'F432']) AS p
  UNION ALL
  SELECT 'diabetes' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['250']) AS p
  UNION ALL
  SELECT 'diabetes' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['E10', 'E11', 'E12', 'E13', 'E14']) AS p
  UNION ALL
  SELECT 'hypertension' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['401', '402', '403', '404', '405']) AS p
  UNION ALL
  SELECT 'liver_disease' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['07022', '07023', '07032', '07033', '07044', '07054', '0706', '0709', '4560', '4561', '4562', '570', '571', '5722', '5723', '5724', '5725', '5726', '5727', '5728', '5733', '5734', '5738', '5739', 'V427']) AS p
  UNION ALL
  SELECT 'liver_disease' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['B18', 'K70', 'K711', 'K713', 'K714', 'K715', 'K717', 'K721', 'K729', 'K73', 'K74', 'K760', 'K762', 'K763', 'K764', 'K765', 'K766', 'K767', 'K768', 'K769', 'Z944']) AS p
  UNION ALL
  SELECT 'peripheral_vascular_disease' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['0930', '4373', '440', '441', '4431', '4432', '4433', '4434', '4435', '4436', '4437', '4438', '4439', '4471', '5571', '5579', 'V434']) AS p
  UNION ALL
  SELECT 'peripheral_vascular_disease' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['K551', 'K558', 'K559', 'Z958', 'Z959']) AS p
  UNION ALL
  SELECT 'renal_disease' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['40301', '40311', '40391', '40402', '40403', '40412', '40413', '40492', '40493', '582', '5830', '5831', '5832', '5833', '5834', '5835', '5836', '5837', '585', '586', '5880', 'V420', 'V451', 'V56']) AS p
  UNION ALL
  SELECT 'renal_disease' AS variable, 10 AS icd_version, p AS prefix FROM UNNEST(['N032', 'N033', 'N034', 'N035', 'N036', 'N037', 'N052', 'N053', 'N054', 'N055', 'N056', 'N057', 'N18', 'N19', 'N250', 'Z490', 'Z491', 'Z492', 'Z940', 'Z992']) AS p
  UNION ALL
  SELECT 'acute_myocardial_infarction' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['410']) AS p
  UNION ALL
  SELECT 'stroke' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['430', '431', '432', '433', '434', '436']) AS p
  UNION ALL
  SELECT 'cardiovascular_disease' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['396', '397', '410', '411', '412', '413', '414', '425', '4275', '428', '440']) AS p
  UNION ALL
  SELECT 'cabg' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['3611', '3612', '3613', '3614', '3615', '3616']) AS p
  UNION ALL
  SELECT 'heart_valve_surgery' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['3511', '3512', '3514', '3521', '3522', '3523', '3524', '3527']) AS p
  UNION ALL
  SELECT 'aortic_surgery' AS variable, 9  AS icd_version, p AS prefix FROM UNNEST(['3845']) AS p
)
SELECT
  d.variable,
  d.icd_version,
  d.prefix,
  COUNT(DISTINCT di.icd_code) AS n_codes,
  COUNT(*)                    AS n_diagnoses,
  STRING_AGG(DISTINCT di.long_title, ' | ' ORDER BY di.long_title LIMIT 2) AS sample_title
FROM declared d
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses` di
  ON di.icd_version = d.icd_version
 AND STARTS_WITH(di.icd_code, d.prefix)
GROUP BY d.variable, d.icd_version, d.prefix
ORDER BY n_codes ASC, d.variable, d.icd_version, d.prefix;


-- ==============================================================================
-- [V2] 일치도 검증 — 직접 구현 vs mimic-code derived.charlson
--   가장 강력한 검증이다. MIT-LCP 공식 구현과 환자별로 대조한다.
--   agree_pct 가 99% 이상이면 사실상 동일 정의로 봐도 된다.
--   only_mine / only_mimic 이 한쪽으로 크게 치우치면 코드 누락 또는 과포함이다.
--
--   ※ 대응 관계 주의
--      - heart_failure 는 Elixhauser 판, charlson 은 Charlson 판이라 정의가 다르다.
--        완전 일치가 아니라 '방향이 맞는지'를 본다.
--      - diabetes 는 charlson 의 without_cc + with_cc 를 합쳐서 비교한다.
--      - liver_disease 는 mild + severe 를 합쳐서 비교한다.
-- ==============================================================================
/*
WITH mine AS (
  SELECT hadm_id, heart_failure, peripheral_vascular_disease, cerebrovascular_disease,
         dementia, copd, liver_disease, renal_disease, diabetes,
         acute_myocardial_infarction
  FROM `yonsei1.delirium.mimic_iv_dataset_107`
)
SELECT * FROM UNNEST([
  STRUCT('heart_failure'               AS variable, 'congestive_heart_failure' AS mimic_col),
  STRUCT('peripheral_vascular_disease',      'peripheral_vascular_disease'),
  STRUCT('cerebrovascular_disease',          'cerebrovascular_disease'),
  STRUCT('dementia',                         'dementia'),
  STRUCT('copd',                             'chronic_pulmonary_disease'),
  STRUCT('renal_disease',                    'renal_disease'),
  STRUCT('acute_myocardial_infarction',      'myocardial_infarct')
]);
-- ↑ 대응표. 실제 비교는 아래 쿼리를 변수마다 바꿔가며 실행한다.

SELECT
  COUNT(*)                                                   AS n,
  ROUND(100*AVG(CAST(m.dementia = c.dementia AS INT64)), 2)  AS agree_pct,
  COUNTIF(m.dementia = 1 AND c.dementia = 1)                 AS both,
  COUNTIF(m.dementia = 1 AND c.dementia = 0)                 AS only_mine,
  COUNTIF(m.dementia = 0 AND c.dementia = 1)                 AS only_mimic
FROM mine m
JOIN `physionet-data.mimiciv_3_1_derived.charlson` c USING (hadm_id);
*/


-- ==============================================================================
-- [V3] 유병률 검증
--   각 동반질환 유병률을 한 번에 출력한다. 일반 ICU 코호트에서 통상 기대되는
--   범위를 벗어나면 정의 오류를 의심할 것.
--     참고 범위(성인 ICU) : hypertension 50-70 / diabetes 25-40 /
--       heart_failure 25-40 / renal 20-35 / copd 15-30 / cancer 10-20 /
--       liver 8-15 / stroke 5-12 / dementia 2-8 / alcohol 5-15
--       anemia 30-50 (정의 확대 후. 확대 전 결핍성 빈혈만일 때는 5-8)
-- ==============================================================================
/*
SELECT
  COUNT(*) AS n,
  ROUND(100*AVG(hypertension), 1)                AS hypertension,
  ROUND(100*AVG(diabetes), 1)                    AS diabetes,
  ROUND(100*AVG(heart_failure), 1)               AS heart_failure,
  ROUND(100*AVG(renal_disease), 1)               AS renal_disease,
  ROUND(100*AVG(copd), 1)                        AS copd,
  ROUND(100*AVG(cancer), 1)                      AS cancer,
  ROUND(100*AVG(liver_disease), 1)               AS liver_disease,
  ROUND(100*AVG(cerebrovascular_disease), 1)     AS cerebrovascular,
  ROUND(100*AVG(stroke), 1)                      AS stroke,
  ROUND(100*AVG(dementia), 1)                    AS dementia,
  ROUND(100*AVG(alcohol_abuse), 1)               AS alcohol_abuse,
  ROUND(100*AVG(has_anemia), 1)                  AS anemia,
  ROUND(100*AVG(peripheral_vascular_disease), 1) AS pvd,
  ROUND(100*AVG(acute_myocardial_infarction), 1) AS ami,
  ROUND(100*AVG(nicotine_dependence), 1)         AS nicotine,
  ROUND(100*AVG(cardiovascular_disease), 1)      AS cvd
FROM `yonsei1.delirium.mimic_iv_dataset_107`;
*/


-- ==============================================================================
-- [V4] cardiovascular_disease 23개 코드의 공식 병명 조회
--   이번에 새로 선언한 유일한 변수이므로, 코드별 공식 병명을 직접 눈으로 확인한다.
--   Zipser et al. 2021 Suppl. Table 1 의 6개 클러스터와 대조할 것.
-- ==============================================================================
/*
WITH cvd AS (
  SELECT 'valvular (I08)'          AS cluster,  9 AS v, p AS prefix FROM UNNEST(['396','397']) p
  UNION ALL SELECT 'valvular (I08)',           10, p FROM UNNEST(['I08']) p
  UNION ALL SELECT 'ischemic (I20-I25)',        9, p FROM UNNEST(['410','411','412','413','414']) p
  UNION ALL SELECT 'ischemic (I20-I25)',       10, p FROM UNNEST(['I20','I21','I22','I23','I24','I25']) p
  UNION ALL SELECT 'cardiomyopathy (I42-I43)',  9, p FROM UNNEST(['425']) p
  UNION ALL SELECT 'cardiomyopathy (I42-I43)', 10, p FROM UNNEST(['I42','I43']) p
  UNION ALL SELECT 'cardiac arrest (I46)',      9, p FROM UNNEST(['4275']) p
  UNION ALL SELECT 'cardiac arrest (I46)',     10, p FROM UNNEST(['I46']) p
  UNION ALL SELECT 'cardiac insuff. (I50)',     9, p FROM UNNEST(['428']) p
  UNION ALL SELECT 'cardiac insuff. (I50)',    10, p FROM UNNEST(['I50']) p
  UNION ALL SELECT 'atherosclerosis (I70)',     9, p FROM UNNEST(['440']) p
  UNION ALL SELECT 'atherosclerosis (I70)',    10, p FROM UNNEST(['I70']) p
)
SELECT
  cvd.cluster, cvd.v AS icd_version, cvd.prefix,
  di.icd_code, di.long_title
FROM cvd
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses` di
  ON di.icd_version = cvd.v AND STARTS_WITH(di.icd_code, cvd.prefix)
ORDER BY cvd.cluster, cvd.v, di.icd_code;
*/


-- ==============================================================================
-- [V5] 시술코드 존재성 검증  ※ [V1] 보정
--   [V1] 은 모든 접두사를 d_icd_diagnoses(진단 사전)에서 조회했으나,
--   cabg / heart_valve_surgery / aortic_surgery 는 procedures_icd 기반이므로
--   d_icd_procedures(시술 사전)에서 조회해야 한다. 아래로 다시 확인할 것.
-- ==============================================================================
/*
WITH declared AS (
  SELECT 'cabg' AS variable, 9 AS v, p AS prefix
    FROM UNNEST(['3611','3612','3613','3614','3615','3616']) p
  UNION ALL SELECT 'cabg', 10, p FROM UNNEST([
    '0210093','0210099','0211093','0211099','0212093','0212099','0213093','0213099',
    '021009W','02100A3','02100A8','02100A9','02100AW','02100Z8','02100Z9',
    '021109W','02110A9','02110AW','02110Z3','02110Z8','02110Z9',
    '021209W','02120AW','02120Z3','02120Z9','021309W']) p
  UNION ALL SELECT 'heart_valve_surgery', 9, p
    FROM UNNEST(['3511','3512','3514','3521','3522','3523','3524','3527']) p
  UNION ALL SELECT 'heart_valve_surgery', 10, p FROM UNNEST([
    '02QF0ZZ','02QG0ZZ','02RF08Z','02RF0JZ','02RF0KZ',
    '02RG08Z','02RG0JZ','02RG0KZ','02RJ08Z']) p
  UNION ALL SELECT 'aortic_surgery', 9, p FROM UNNEST(['3845']) p
  UNION ALL SELECT 'aortic_surgery', 10, p
    FROM UNNEST(['02RW0JZ','02RX08Z','02RX0JZ']) p
)
SELECT
  d.variable, d.v AS icd_version, d.prefix,
  COUNT(DISTINCT pr.icd_code) AS n_codes,
  STRING_AGG(DISTINCT pr.long_title, ' | ' ORDER BY pr.long_title LIMIT 1) AS sample_title
FROM declared d
LEFT JOIN `physionet-data.mimiciv_3_1_hosp.d_icd_procedures` pr
  ON pr.icd_version = d.v AND STARTS_WITH(pr.icd_code, d.prefix)
GROUP BY d.variable, d.v, d.prefix
ORDER BY n_codes ASC, d.variable, d.prefix;
*/


-- ==============================================================================
-- [V6] diabetes — ICD-10-CM 누락 코드(E08/E09) 실재 여부 및 규모 확인
--   [V1] 결과: 선언한 E12/E14 는 매칭 0건. WHO ICD-10 에는 있으나
--   ICD-10-CM 에는 없는 코드이기 때문이며, ICD-10-CM 의 당뇨는 E08-E13 이다.
--   따라서 현재 정의는 E08(기저질환에 의한 당뇨)과 E09(약물유발성 당뇨)를
--   놓치고 있다. 아래로 규모를 확인한 뒤 포함 여부를 결정할 것.
--   ※ ICU 에서 스테로이드 유발 당뇨(E09)는 드물지 않다.
-- ==============================================================================
/*
SELECT
  SUBSTR(di.icd_code, 1, 3) AS code3,
  COUNT(DISTINCT d.hadm_id) AS n_admissions,
  ANY_VALUE(dd.long_title)  AS sample_title
FROM `yonsei1.delirium.delirium_patients_v2` d
JOIN `physionet-data.mimiciv_3_1_hosp.diagnoses_icd` di ON d.hadm_id = di.hadm_id
JOIN `physionet-data.mimiciv_3_1_hosp.d_icd_diagnoses` dd
  ON dd.icd_code = di.icd_code AND dd.icd_version = di.icd_version
WHERE di.icd_version = 10
  AND SUBSTR(di.icd_code, 1, 3) IN ('E08','E09','E10','E11','E13')
GROUP BY code3
ORDER BY code3;
*/


-- ==============================================================================
-- [!!] 경고 — dementia 의 F05 계열은 절대 추가하지 말 것
--   [V1] 에서 dementia 의 'F051'(Quan 원표의 F05.1 "섬망 중첩 치매")이 0건으로
--   나왔다. WHO ICD-10 의 F05.1 이 ICD-10-CM 에는 없기 때문이다.
--   이를 'F05' 로 넓혀 "고치려" 하면 안 된다.
--     ICD-10-CM 의 F05 = "Delirium due to known physiological condition"
--     즉 본 연구의 결과변수(섬망) 그 자체다. 예측변수에 넣으면 치명적 누출이다.
--   현재 dementia 정의는 G30(알츠하이머), F01-F03, G31.1 로 ICD-10-CM 상
--   필요한 범위를 이미 포괄한다. 그대로 두는 것이 맞다.
-- ==============================================================================
