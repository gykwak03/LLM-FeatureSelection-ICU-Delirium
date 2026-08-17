-- ==============================================================================
-- mimic_iv_107.sql — feature_pool.txt(107개) 완전 대응 버전
--
--   [ mimic_iv_103.sql 대비 변경점 ]
--
--   (A) 신규 변수 6개 추가 — 101개 -> 107개
--       1. body_mass_index            : 기존 height/weight 로 산출
--       2. mean_blood_glucose (MBG)   : Wang & Mei, Front Endocrinol 2024;15:1400207
--       3. mean_absolute_glucose (MAG): 동 논문, MAG = Σ|Δglucose| / Σ Δtime
--       4. charlson_comorbidity_index : mimic-code derived.charlson (이미 JOIN 되어 있었음)
--       5. infection                  : 24h 내 관찰가능한 "치료 의도" 기반 정의 (아래 (C) 참조)
--       6. cardiovascular_disease     : Zipser et al. 2021 Suppl. Table 1 의 심혈관
--                                       6개 ICD-10 클러스터 합산 (아래 (B) 참조)
--
--   (B) Cardiovascular Disease 정의 근거
--       Zipser CM, Hildenbrand FF, Haubner B, Deuel J, Ernst J, Petry H, Schubert M,
--       Jordan KD, von Känel R, Boettger S. "Predisposing and Precipitating Risk
--       Factors for Delirium in Elderly Patients Admitted to a Cardiology Ward: An
--       Observational Cohort Study in 1,042 Patients."
--       Front Cardiovasc Med. 2021;8:686665. doi:10.3389/fcvm.2021.686665
--
--       동 논문 Supplementary Table 1 (ICD-10 diagnostic clusters) 의 심혈관계
--       6개 클러스터를 그대로 채택하여 단일 변수로 합산한다:
--         Valvular heart disease I08 / Ischemic heart disease I20-I25 /
--         Cardiomyopathy I42-I43 / Cardiac arrest I46 /
--         Cardiac insufficiency I50 / Atherosclerosis I70
--
--       [채택 이유]
--       당초 출처 논문(Wang & Mei, Front Endocrinol 2024;15:1400207)은 CVD 를
--       공변량 목록에만 올리고 조작적 정의를 제시하지 않았다. 반면 Zipser et al.
--       은 섬망을 결과변수로 하는 연구에서 심혈관 진단 클러스터의 ICD-10 코드를
--       전면 공개한 사실상 유일한 문헌이므로 이를 정의 근거로 삼는다.
--
--       [주의 — 논문 Methods 에 반드시 명시할 것]
--       1) Zipser et al. 은 이 6개를 '개별 변수'로 분석했다(그 결과 valvular
--          heart disease 만 유의, OR 1.57; ischemic heart disease 는 p=1.0).
--          본 연구는 feature pool 이 CVD 를 단일 항목으로 규정하므로 6개를
--          OR 합산하여 하나의 이진변수로 만든다. 원 논문과 사용 단위가 다르다.
--       2) ICD-9 대응 코드는 Zipser et al. 에 없다(스위스 단일기관, ICD-10 only).
--          MIMIC-IV 는 ICD-9/10 이 혼재하므로 표준 대응 범위를 본 연구에서 적용했다.
--       3) 본 데이터셋의 heart_failure(I43,I50) / peripheral_vascular_disease(I70,I71)
--          / acute_myocardial_infarction(I21,I22) 과 포함관계가 발생한다.
--          다중공선성은 feature selection 단계에서 처리하는 것을 전제로 한다.
--
--   (C) Infection 정의 근거 — 세균 편향 및 24시간 관찰가능성 문제 해결
--       mimic-code 의 derived.suspicion_of_infection 은 derived.antibiotic 에
--       의존하는데, 이 목록은 항세균제 약 150종 + 항진균제 2종
--       (amphotericin, anidulafungin) 뿐이고 항바이러스제는 0종이다.
--       즉 바이러스 감염(헤르페스 뇌염, 인플루엔자 뇌증 등 — 섬망과 직결)은
--       구조적으로 누락된다.
--       -> 본 파일은 항세균제 + 항진균제 + 항바이러스제로 확장한 항미생물제
--          목록을 직접 구성하고, "항미생물제 투여 + 미생물 검사 시행"의
--          짝짓기(suspicion of infection 논리)를 ICU 입실 후 24시간 창 안으로
--          잘라서 정의한다.
--       -> 배양 '결과'(org_name)를 요구하지 않으므로 24시간 시점에 실제로
--          관찰 가능하다. ICD 진단코드는 퇴원 시 부여되므로 사용하지 않는다.
--
--   (D) 미생물 결과 변수의 정보 누출(leakage) 수정
--       기존 cte_micro_cls 는 microbiologyevents 를 charttime(검체 채취 시각)
--       기준 24시간으로 잘랐으나, 같은 행의 org_name(균 동정 결과)은 며칠 뒤에
--       확정되는 값이다. 혈액배양 양성 신호까지 통상 12~36h, 균 동정·감수성까지
--       추가 24~48h 가 소요되므로 24시간 시점에는 알 수 없다.
--       -> 결과 기반 변수(micro_gram_positive / micro_gram_negative /
--          micro_fungal / micro_other / micro_category)는 storetime(결과 등록
--          시각) 기준으로 변경했다.
--       -> culture_performed(배양 시행 여부)는 채취 시점 정보이므로 charttime
--          기준을 유지한다.
--       ※ storetime 기준으로 바꾸면 24시간 내 결과 확정 건수가 크게 줄 수 있다.
--          아래 [3] 검증 쿼리로 잔존 비율을 먼저 확인할 것.
--
--   [ 기존 정의 유지 ]
--     심장수술 ICD : Guo P et al., BMC Anesthesiol 2024;24:347, Suppl. Table 1
--     Statin       : WHO ATC C10AA (HMG-CoA reductase inhibitors)
--     미생물 분류  : org_name 285개 전수 분류, 미분류 0
--     Cancer       : mimic-code charlson (Quan et al., Med Care 2005)
--
--   ※ 실행 전 콘솔에서 dry run 으로 문법·비용을 먼저 확인할 것.
--   ※ delirium_patients_v2 는 stay_id 가 유니크하므로 별도 dedupe 불필요.
-- ==============================================================================

-- ==============================================================================
-- [0] 변수-출처 대조표  (Supplementary Table 용)
-- ==============================================================================
--
--   범례  [Q] Quan H, Sundararajan V, Halfon P, et al. Coding algorithms for
--             defining comorbidities in ICD-9-CM and ICD-10 administrative data.
--             Med Care. 2005;43(11):1130-9.  — 원표와 대조 검증 완료
--         [M] MIT-LCP mimic-code 공식 derived 테이블 정의를 그대로 사용
--         [P] 개별 출처 논문의 계산식/정의를 구현
--         [S] 본 연구에서 조작적으로 정의 (원 논문에 정의 부재)
--
-- ------------------------------------------------------------------------------
-- A. 동반질환 (diagnoses_icd 기반, hadm_id 단위)                        16개
-- ------------------------------------------------------------------------------
--   [S] has_anemia .................. 빈혈 전체 (ICD-9 280-285 / ICD-10 D50-D64)
--                                     Elixhauser 실혈성+결핍성 빈혈을 포괄하도록 확장
--   [Q] alcohol_abuse ............... Elixhauser "Alcohol abuse"          완전일치
--   [Q] heart_failure ............... Elixhauser "CHF" (Enhanced ICD-9)   완전일치
--   [Q] copd ........................ Elixhauser "Chronic pulmonary"      완전일치
--   [Q] depression .................. Elixhauser "Depression"             완전일치
--   [Q] peripheral_vascular_disease . Elixhauser "Peripheral vascular"    완전일치
--   [Q] liver_disease ............... Charlson mild+severe 합집합           완전일치
--                                     (mimic-code charlson.sql 과 코드 동일)
--   [Q] diabetes .................... Charlson without_cc+with_cc 합집합    완전일치
--                                     (= Elixhauser uncomplicated+complicated 합집합)
--   [Q] hypertension ................ Elixhauser uncomplicated+complicated 합집합
--                                     Enhanced ICD-9-CM 열과 일치. 임신성(642.x) 미포함
--   [Q] dementia .................... Charlson "Dementia"                 완전일치
--   [Q] cerebrovascular_disease ..... Charlson "Cerebrovascular disease"  완전일치
--   [Q] renal_disease ............... Charlson "Renal disease"            일치
--   [Q] acute_myocardial_infarction . Charlson "MI" 中 급성만 (의도적 축소)
--   [S] nicotine_dependence ......... WHO ICD 표준 분류 직접 적용
--   [S] stroke ...................... 급성 뇌졸중 사건 (cerebrovascular 의 부분집합)
--   [S] cardiovascular_disease ...... Zipser 2021 Suppl.T1 심혈관 6클러스터 합산
--
-- ------------------------------------------------------------------------------
-- B. 수술 / 처치                                                          6개
-- ------------------------------------------------------------------------------
--   [P] cabg, heart_valve_surgery, aortic_surgery, cardiac_surgery_type
--         Guo P et al., BMC Anesthesiol 2024;24:347, Suppl. Table 1 (원문 코드)
--   [M] mechanical_ventilation ...... derived.ventilation
--   [M] renal_replacement_therapy ... derived.first_day_rrt
--
-- ------------------------------------------------------------------------------
-- C. 중증도 점수                                                          8개
-- ------------------------------------------------------------------------------
--   [M] sofa_score(first_day_sofa) / gcs_min(first_day_gcs) / apache_score(apsiii)
--       logistic_organ_dysfunction_score(lods) / oxford_...(oasis)
--       simplified_acute_physiology_score_ii(sapsii) / ...response_syndrome(sirs)
--       sepsis(sepsis3)  — 전부 mimic-code derived 테이블 원본값
--
-- ------------------------------------------------------------------------------
-- D. 활력징후 · 검사실 소견 (min/max 쌍)                                 약 60개
-- ------------------------------------------------------------------------------
--   [M] derived.first_day_vitalsign / first_day_lab / first_day_bg_art /
--       first_day_urine_output / complete_blood_count / blood_differential
--   [S] magnesium, phosphate ........ derived 미제공. labevents itemid 50960/50970 직접
--
-- ------------------------------------------------------------------------------
-- E. 약물 / 미생물                                                        9개
-- ------------------------------------------------------------------------------
--   [M] antibiotic_drug_use ......... derived.antibiotic
--   [M] acute_kidney_injury ......... derived.kdigo_stages
--   [S] sedation_use, use_of_midazolam  inputevents itemid 직접 지정
--   [M] vasopressor_use ............. derived.norepinephrine_equivalent_dose
--   [S] statin_drugs ................ WHO ATC C10AA (원 논문 약물목록 부재)
--   [S] micro_* , culture_performed .. org_name 285개 전수 분류 (원 논문 정의 부재)
--   [S] infection ................... 항미생물제(항세균+항진균+항바이러스) 투여
--                                     + 미생물 검사 시행, 24h 창 내. 상단 (C) 참조
--
-- ------------------------------------------------------------------------------
-- F. 파생 지표 (계산식)                                                  11개
-- ------------------------------------------------------------------------------
--   [P] mbg, mag, mage, lage, gli ... Wang F & Mei X, Front Endocrinol 2024;15:1400207
--   [P] gnri ........................ Bouillanne 식 (albumin + 이상체중비)
--   [P] prognostic_nutritional_index  Onodera 식 = 10*Alb + 0.005*총림프구수
--   [P] lymphocyte_to_monocyte_ratio, neutrophil_to_lymphocyte_ratio,
--       platelet_to_lymphocyte_ratio  24h 평균값의 비
--   [S] egfr ........................ CKD-EPI 2021 (인종 미보정)
--   [S] body_mass_index ............. weight/height^2, 생리적 범위 10-80 제한
--   [M] charlson_comorbidity_index .. derived.charlson
--
-- ------------------------------------------------------------------------------
-- G. 인구학 / 행정                                                        7개
-- ------------------------------------------------------------------------------
--   [M] anchor_age, sex(gender), ethnicity(icustay_detail.race), insurance,
--       marital_status, type_of_initial_icu_admission(first_careunit)
--   [S] elective_surgery ............ admission_type IN ('ELECTIVE',
--                                     'SURGICAL SAME DAY ADMISSION')
--
-- ------------------------------------------------------------------------------
-- 요약 : [Q] 12 · [M] 다수 · [P] 9 · [S] 13
--   [S] 로 표시된 12개는 원 논문에 조작적 정의가 없어 본 연구에서 정의한 항목이며,
--   논문 Methods 또는 Supplementary 에 정의를 명시할 것.
-- ==============================================================================

-- ==============================================================================
-- [1] Sub Query (CTEs)
-- ==============================================================================
CREATE OR REPLACE TABLE `yonsei1.delirium.mimic_iv_dataset_107` AS
WITH 

-- hadm_id, has_anemia, alcohol_abuse, heart_failure, cerebrovascular_disease, copd, dementia, depression, diabetes, hypertension, liver_disease, peripheral_vascular_disease, renal_disease, acute_myocardial_infarction, stroke
cte_comorbidities AS (
  -- ===========================================================================
  -- 동반질환 16개 — 입원(hadm_id) 단위 ICD 진단코드 기반
  --   ※ 12개 변수가 Quan H et al., Med Care 2005;43(11):1130-9 의 Charlson/
  --     Elixhauser 코딩 알고리즘 원표와 대조 검증되었다 (파일 상단 [0] 대조표).
  --   ※ ICD 코드는 퇴원 시 부여되므로 엄밀히는 24시간 시점 관찰 자료가 아니다.
  --     선행 동반질환(chronic comorbidity)에 한해 MIMIC 문헌의 통상 관행을 따른다.
  -- ===========================================================================
  SELECT
    di.hadm_id,
    -- [nicotine_dependence]
    --   정의 : ICD-9 305.1, V15.82 | ICD-10 F17.x, Z87.891
    --   출처 : 본 연구 정의 (WHO ICD 표준 분류)
    --   비고 : Quan 2005 의 Charlson/Elixhauser 어디에도 없는 항목이라 표준 분류를 직접 적용함
    MAX(CASE WHEN (di.icd_version = 9 AND di.icd_code IN ('3051', 'V1582')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) = 'F17' OR di.icd_code = 'Z87891')) THEN 1 ELSE 0 END) AS nicotine_dependence,

    -- [has_anemia]
    --   정의 : ICD-9  280.x-285.x  (빈혈 전체)
    --          ICD-10 D50.x-D53.x, D55.x-D64.x  (빈혈 전체, D54 는 결번)
    --   출처 : 본 연구 정의 — Elixhauser "Blood loss anemia" + "Deficiency anemia"
    --          두 범주를 포괄하도록 ICD 분류상 빈혈 블록 전체로 확장
    --   비고 : [정의 확대] 기존에는 Elixhauser "Deficiency anemia"(D50.8/.9, D51-D53,
    --          ICD-9 280-281)만 사용하여 유병률이 5.5% 였다. 이는 철분·B12·엽산
    --          결핍성 빈혈만 포착한 값으로, 실혈성 빈혈(D50.0)·용혈성 빈혈(D55-D59)·
    --          재생불량성 빈혈(D60-D61)·급성 출혈후 빈혈(D62)·만성질환 빈혈(D63)·
    --          기타 빈혈(D64)이 모두 누락되어 있었다.
    --          feature pool 항목명이 "Anemia"(빈혈 일반)이고, 원 논문
    --          (Establishment and validation of a nomogram of postoperative delirium
    --          in cardiac surgery, MIMIC-IV) 도 anemia 로만 기술하였으므로
    --          ICD 분류상 빈혈 블록 전체를 사용한다.
    --          ※ ICD-10 D50-D64 = 영양성 빈혈(D50-D53) + 용혈성 빈혈(D55-D59)
    --            + 재생불량성 및 기타 빈혈(D60-D64). ICD-9 280-285 가 이에 대응.
    --          ※ 임신 합병 빈혈(ICD-9 648.2)은 hypertension 에서 임신성 고혈압을
    --            제외한 것과 동일한 기준으로 포함하지 않았다.
    --          ※ 기대 유병률 30-50%. 확대 전 5.5% 에서 크게 오르는 것이 정상이다.
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) IN ('280', '281', '282', '283', '284', '285')) OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('D50', 'D51', 'D52', 'D53', 'D55', 'D56', 'D57', 'D58', 'D59', 'D60', 'D61', 'D62', 'D63', 'D64')) THEN 1 ELSE 0 END) AS has_anemia,

    -- [alcohol_abuse]
    --   정의 : ICD-9 291.1-291.9, 303.x, 305.0, 357.5, 425.5, 535.3, 571.0-571.3, 980.x, V11.3
    --          ICD-10 F10, E52, G62.1, I42.6, K29.2, K70.0/.3/.9, T51.x, Z50.2, Z71.4, Z72.1
    --   출처 : Quan 2005, Elixhauser "Alcohol abuse"
    --   비고 : Quan 원표와 완전 일치
    MAX(CASE WHEN (di.icd_version = 9 AND (di.icd_code IN ('2915', '2916', '2917', '2918', '2919', '3030', '3039', '3050', '3575', '4255', '5353', '980', 'V113') OR SUBSTR(di.icd_code, 1, 4) IN ('5710', '5711', '5712', '5713'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('F10', 'T51') OR di.icd_code IN ('E52', 'G621', 'I426', 'K292', 'K700', 'K703', 'K709', 'Z502', 'Z714', 'Z721'))) THEN 1 ELSE 0 END) AS alcohol_abuse,

    -- [heart_failure]
    --   정의 : ICD-9 398.91, 402.01/.11/.91, 404.01/.03/.11/.13/.91/.93, 425.4-425.9, 428.x
    --          ICD-10 I09.9, I11.0, I13.0, I13.2, I25.5, I42.0, I42.5-I42.9, I43.x, I50.x, P29.0
    --   출처 : Quan 2005, Elixhauser "Congestive heart failure" (Enhanced ICD-9-CM)
    --   비고 : Quan 원표와 완전 일치. cardiovascular_disease(I50 포함)와 포함관계 있음
    MAX(CASE WHEN (di.icd_version = 9 AND (di.icd_code IN ('39891', '40201', '40211', '40291', '40401', '40403', '40411', '40413', '40491', '40493') OR SUBSTR(di.icd_code, 1, 3) = '428' OR SUBSTR(di.icd_code, 1, 4) IN ('4254', '4255', '4256', '4257', '4258', '4259'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('I43', 'I50') OR di.icd_code IN ('I099', 'I110', 'I130', 'I132', 'I255', 'I420', 'I425', 'I426', 'I427', 'I428', 'I429', 'P290'))) THEN 1 ELSE 0 END) AS heart_failure,

    -- [cerebrovascular_disease]
    --   정의 : ICD-9 430-438, 362.34 | ICD-10 G45.x, G46.x, H34.0, I60.x-I69.x
    --   출처 : Quan 2005, Charlson "Cerebrovascular disease"
    --   비고 : Quan 원표와 완전 일치. 아래 stroke 는 이 변수의 부분집합임
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('430', '431', '432', '433', '434', '435', '436', '437', '438') OR di.icd_code = '36234')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('G45', 'G46', 'I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67', 'I68', 'I69') OR di.icd_code = 'H340')) THEN 1 ELSE 0 END) AS cerebrovascular_disease,

    -- [copd]
    --   정의 : ICD-9 490-505, 416.8, 416.9, 506.4, 508.1, 508.8
    --          ICD-10 I27.8, I27.9, J40.x-J47.x, J60.x-J67.x, J68.4, J70.1, J70.3
    --   출처 : Quan 2005, Elixhauser "Chronic pulmonary disease"
    --   비고 : Quan 원표와 완전 일치
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('490', '491', '492', '493', '494', '495', '496', '497', '498', '499', '500', '501', '502', '503', '504', '505') OR di.icd_code IN ('4168', '4169', '5064', '5081', '5088'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('J40', 'J41', 'J42', 'J43', 'J44', 'J45', 'J46', 'J47', 'J60', 'J61', 'J62', 'J63', 'J64', 'J65', 'J66', 'J67') OR di.icd_code IN ('I278', 'I279', 'J684', 'J701', 'J703'))) THEN 1 ELSE 0 END) AS copd,

    -- [dementia]
    --   정의 : ICD-9 290.x, 294.1, 331.2 | ICD-10 F00.x-F03.x, F05.1, G30.x, G31.1
    --   출처 : Quan 2005, Charlson "Dementia"
    --   비고 : Quan 원표와 완전 일치. 섬망의 최대 위험인자이므로 유병률이 낮아도(2.15%) 제외하지 않음
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) = '290' OR di.icd_code IN ('2941', '3312'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('F00', 'F01', 'F02', 'F03', 'G30') OR di.icd_code IN ('F051', 'G311'))) THEN 1 ELSE 0 END) AS dementia,

    -- [depression]
    --   정의 : ICD-9 296.2, 296.3, 296.5, 300.4, 309.x, 311
    --          ICD-10 F20.4, F31.3-F31.5, F32.x, F33.x, F34.1, F41.2, F43.2
    --   출처 : Quan 2005, Elixhauser "Depression"
    --   비고 : Quan 원표와 완전 일치
    MAX(CASE WHEN (di.icd_version = 9 AND (di.icd_code IN ('2962', '2963', '2965', '3004', '311') OR SUBSTR(di.icd_code, 1, 3) = '309')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('F32', 'F33') OR di.icd_code IN ('F204', 'F313', 'F314', 'F315', 'F341', 'F412', 'F432'))) THEN 1 ELSE 0 END) AS depression,

    -- [diabetes]
    --   정의 : ICD-9 250.x | ICD-10 E10-E14
    --   출처 : Quan 2005, Charlson "Diabetes without/with chronic complication" 합집합
    --          (= Elixhauser "uncomplicated/complicated" 합집합. 두 기준의 합집합은
    --           동일한 코드 집합이 된다)
    --   비고 : 합병증 유무로 나뉜 두 범주를 합치면 ICD-9 250.x, ICD-10 E10-E14 전체가
    --          되어 본 정의와 정확히 일치한다. 누락·과포함 없음.
    --          ※ MIMIC-IV 는 ICD-10-CM 이라 E12/E14 는 없고 E08/E09 가 있다.
    --            포함 여부는 verify_icd_codes.sql [V6] 로 규모 확인 후 결정할 것.
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) = '250') OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')) THEN 1 ELSE 0 END) AS diabetes,

    -- [hypertension]
    --   정의 : ICD-9 401-405 | ICD-10 I10.x-I13.x, I15.x
    --   출처 : Quan 2005, Elixhauser "Hypertension uncomplicated" + "complicated" 합집합
    --          (Enhanced ICD-9-CM 열 기준 — 비합병 401.x, 합병 402.x-405.x)
    --   비고 : 두 범주의 합집합으로 Enhanced ICD-9-CM 열과 정확히 일치한다.
    --          ※ Quan 의 AHRQ-Web 열에만 있는 임신성 고혈압(642.0/.1/.2/.7/.9)은
    --            포함하지 않았다. 성인 ICU 코호트에서 기여가 미미하다.
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) IN ('401', '402', '403', '404', '405')) OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('I10', 'I11', 'I12', 'I13', 'I15')) THEN 1 ELSE 0 END) AS hypertension,

    -- [liver_disease]
    --   정의 : ICD-9 070.22/.23/.32/.33/.44/.54, 070.6, 070.9, 456.0-456.2, 570.x, 571.x,
    --          572.2-572.8, 573.3/.4/.8/.9, V42.7
    --          ICD-10 B18.x, I85.0/.9, I86.4, I98.2, K70.x, K71.1/.3-.5/.7, K72.1/.9,
    --          K73.x, K74.x, K76.0, K76.2-K76.9, Z94.4
    --   출처 : Quan 2005, Charlson "Mild liver disease" + "Moderate or severe liver
    --          disease" 의 합집합 (mimic-code charlson.sql 구현과 코드 동일)
    --   비고 : mimic-code 의 두 범주를 합치면 본 정의와 정확히 일치한다. 원 논문들이
    --          간질환 중증도를 구분하지 않으므로 합집합을 사용한다.
    --          ※ Elixhauser 판 "Liver disease" 와는 K72.0(급성·아급성 간부전) 하나가
    --            다르다. Charlson 판은 K72.1(만성)·K72.9(상세불명)만 포함한다.
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('570', '571') OR di.icd_code IN ('07022', '07023', '07032', '07033', '07044', '07054', '0706', '0709', '4560', '4561', '4562', '5722', '5723', '5724', '5725', '5726', '5727', '5728', '5733', '5734', '5738', '5739', 'V427'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('B18', 'K70', 'K73', 'K74') OR di.icd_code IN ('I850', 'I859', 'I864', 'I982', 'K711', 'K713', 'K714', 'K715', 'K717', 'K721', 'K729', 'K760', 'K762', 'K763', 'K764', 'K765', 'K766', 'K767', 'K768', 'K769', 'Z944'))) THEN 1 ELSE 0 END) AS liver_disease,

    -- [peripheral_vascular_disease]
    --   정의 : ICD-9 440.x, 441.x, 443.1-443.9, 447.1, 557.1, 557.9, 093.0, 437.3, V43.4
    --          ICD-10 I70.x, I71.x, I73.1/.8/.9, I77.1, I79.0, I79.2, K55.1/.8/.9, Z95.8, Z95.9
    --   출처 : Quan 2005, Elixhauser "Peripheral vascular disorders"
    --   비고 : Quan 원표와 완전 일치. cardiovascular_disease(I70 포함)와 포함관계 있음
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('440', '441') OR di.icd_code IN ('0930', '4373', '4431', '4432', '4433', '4434', '4435', '4436', '4437', '4438', '4439', '4471', '5571', '5579', 'V434'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('I70', 'I71') OR di.icd_code IN ('I731', 'I738', 'I739', 'I771', 'I790', 'I792', 'K551', 'K558', 'K559', 'Z958', 'Z959'))) THEN 1 ELSE 0 END) AS peripheral_vascular_disease,

    -- [renal_disease]
    --   정의 : ICD-9 403.01/.11/.91, 404.02/.03/.12/.13/.92/.93, 582.x, 583.0-583.7, 585.x, 586.x,
    --          588.0, V42.0, V45.1, V56.x
    --          ICD-10 I12.0, I13.1, N03.2-N03.7, N05.2-N05.7, N18.x, N19.x, N25.0,
    --          Z49.0-Z49.2, Z94.0, Z99.2
    --   출처 : Quan 2005, Charlson "Renal disease" (mimic-code charlson.sql 구현과 동일)
    --   비고 : Elixhauser 판(N18/N19 중심)보다 넓은 Charlson 판을 사용. 사구체신염(N03/N05)이 포함됨
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('582', '585', '586') OR di.icd_code IN ('40301', '40311', '40391', '40402', '40403', '40412', '40413', '40492', '40493', '5830', '5831', '5832', '5833', '5834', '5835', '5836', '5837', '5880', 'V420', 'V451') OR SUBSTR(di.icd_code, 1, 3) = 'V56')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('N18', 'N19') OR di.icd_code IN ('I120', 'I131', 'N032', 'N033', 'N034', 'N035', 'N036', 'N037', 'N052', 'N053', 'N054', 'N055', 'N056', 'N057', 'N250', 'Z490', 'Z491', 'Z492', 'Z940', 'Z992'))) THEN 1 ELSE 0 END) AS renal_disease,

    -- [acute_myocardial_infarction]
    --   정의 : ICD-9 410.x | ICD-10 I21.x, I22.x
    --   출처 : Quan 2005, Charlson "Myocardial infarction" 에서 급성 병변만 선택
    --   비고 : [의도적 축소] Quan 원표는 진구성 심근경색(ICD-9 412, ICD-10 I25.2)을 포함하나,
    --          본 변수는 feature pool 정의상 "Acute" MI 이므로 급성 병변만 남겼다.
    --          진구성 병변은 cardiovascular_disease(I25.x 포함)에서 포착된다.
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) = '410') OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('I21', 'I22')) THEN 1 ELSE 0 END) AS acute_myocardial_infarction,

    -- [stroke]
    --   정의 : ICD-9 430-434, 436 | ICD-10 I60.x-I63.x
    --   출처 : 본 연구 정의 (Quan 2005 에 독립 범주 없음)
    --   비고 : [중복 주의] cerebrovascular_disease(G45,G46,H34.0,I60-I69) 의 진부분집합이다.
    --          feature pool 에 두 항목이 별개로 존재하여 둘 다 유지하되, 전자는
    --          Charlson 정의의 광의 뇌혈관질환, 후자는 급성 뇌졸중 사건으로 구분한다.
    --          일과성 허혈발작(G45)·후유증(I69)은 stroke 에서 제외된다.
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) IN ('430', '431', '432', '433', '434', '436')) OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('I60', 'I61', 'I62', 'I63')) THEN 1 ELSE 0 END) AS stroke,

    -- [cardiovascular_disease]
    --   정의 : ICD-9 396, 397, 410-414, 425, 427.5, 428, 440
    --          ICD-10 I08, I20-I25, I42-I43, I46, I50, I70
    --   출처 : Zipser CM et al., Front Cardiovasc Med 2021;8:686665, Suppl. Table 1
    --   비고 : 동 논문의 심혈관 6개 클러스터(판막질환/허혈성 심질환/심근병증/심정지/심부전/
    --          죽상경화증)를 OR 합산. ICD-9 대응은 본 연구에서 부여. 상세 근거는 파일 상단 (B).
    --          [중복 주의] heart_failure, peripheral_vascular_disease,
    --          acute_myocardial_infarction 과 포함관계가 있다.
    MAX(CASE
      WHEN (di.icd_version = 9 AND (
              SUBSTR(di.icd_code, 1, 3) IN ('396', '397',                      -- I08  판막질환
                                            '410', '411', '412', '413', '414', -- I20-I25 허혈성 심질환
                                            '425',                             -- I42-I43 심근병증
                                            '428',                             -- I50  심부전
                                            '440')                             -- I70  죽상경화증
           OR SUBSTR(di.icd_code, 1, 4) = '4275'))                             -- I46  심정지
        OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN (
              'I08',
              'I20', 'I21', 'I22', 'I23', 'I24', 'I25',
              'I42', 'I43',
              'I46',
              'I50',
              'I70'))
      THEN 1 ELSE 0 END) AS cardiovascular_disease

  FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd` di
  JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm ON di.hadm_id = adm.hadm_id
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` icu ON adm.hadm_id = icu.hadm_id
  -- 해당 입원의 ICU 입실 이전 시점 진단만 대상으로 한다
  WHERE adm.admittime <= icu.intime
  GROUP BY di.hadm_id
),

-- hadm_id, cabg
cte_surgeries AS (
  SELECT
    pi.hadm_id,
    -- [수정] Guo P et al., BMC Anesthesiol 2024;24:347, Supplementary Table 1 (원문 코드 그대로)
    --   ICD-9 15개 / ICD-10 38개. 3분류는 코드 체계에 따른 분해로, 논문 Table 3 의
    --   "Surgery type" (CABG / Heart valve / Aortic) 3범주와 대응한다.
    MAX(CASE WHEN (pi.icd_version=9  AND pi.icd_code IN ('3611','3612','3613','3614','3615','3616'))
              OR (pi.icd_version=10 AND pi.icd_code IN (
                    '0210093','0210099','0211093','0211099','0212093','0212099','0213093','0213099',
                    '021009W','02100A3','02100A8','02100A9','02100AW','02100Z8','02100Z9',
                    '021109W','02110A9','02110AW','02110Z3','02110Z8','02110Z9',
                    '021209W','02120AW','02120Z3','02120Z9','021309W'))
      THEN 1 ELSE 0 END) AS cabg,
    MAX(CASE WHEN (pi.icd_version=9  AND pi.icd_code IN ('3511','3512','3514','3521','3522','3523','3524','3527'))
              OR (pi.icd_version=10 AND pi.icd_code IN (
                    '02QF0ZZ','02QG0ZZ','02RF08Z','02RF0JZ','02RF0KZ',
                    '02RG08Z','02RG0JZ','02RG0KZ','02RJ08Z'))
      THEN 1 ELSE 0 END) AS heart_valve_surgery,
    -- 흉부대동맥만 포함 (원논문은 복부대동맥 코드를 포함하지 않음)
    MAX(CASE WHEN (pi.icd_version=9  AND pi.icd_code = '3845')
              OR (pi.icd_version=10 AND pi.icd_code IN ('02RW0JZ','02RX08Z','02RX0JZ'))
      THEN 1 ELSE 0 END) AS aortic_surgery
  -- [수정] 기존에는 입원 전체 기간의 시술을 집계하여, ICU 입실 '이후' 시행된
  --   심장수술도 예측변수로 들어갔다(정보 누출). 해당 입원의 첫 ICU 입실일
  --   이전(당일 포함)에 기록된 시술만 인정한다.
  --   ※ procedures_icd.chartdate 는 날짜 단위이므로 입실 당일 수술의 선후는
  --     판정할 수 없다. 심장수술 후 ICU 입실이 통상적이므로 당일은 포함한다.
  --     민감도 분석은 아래 [3-5] 참조.
  FROM `physionet-data.mimiciv_3_1_hosp.procedures_icd` pi
  JOIN (
    SELECT hadm_id, MIN(intime) AS first_intime
    FROM `physionet-data.mimiciv_3_1_icu.icustays`
    GROUP BY hadm_id
  ) icu
    ON pi.hadm_id = icu.hadm_id
   AND pi.chartdate <= DATE(icu.first_intime)
  GROUP BY pi.hadm_id
),

-- stay_id, neutrophils_min, neutrophils_max
cte_neutrophils AS (
  SELECT 
    i.stay_id, 
    MIN(bd.neutrophils_abs) as neutrophils_min, 
    MAX(bd.neutrophils_abs) as neutrophils_max
  FROM `physionet-data.mimiciv_3_1_derived.blood_differential` bd
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON bd.hadm_id = i.hadm_id
  WHERE bd.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- stay_id, mech_vent_24h
cte_ventilation AS (
  SELECT v.stay_id, MAX(1) AS mech_vent_24h
  FROM `physionet-data.mimiciv_3_1_derived.ventilation` v
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON v.stay_id = i.stay_id
  WHERE v.ventilation_status IN ('InvasiveVent', 'NonInvasiveVent')
    AND v.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
    AND COALESCE(v.endtime, v.starttime) >= i.intime
  GROUP BY v.stay_id
),

-- stay_id, antibiotic_24h
cte_antibiotic AS (
  SELECT a.stay_id, MAX(1) AS antibiotic_24h
  FROM `physionet-data.mimiciv_3_1_derived.antibiotic` a
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON a.stay_id = i.stay_id
  -- [수정] derived.antibiotic.stoptime 은 prescriptions.stoptime 에서 오며 NULL 이
  --   될 수 있다. NULL >= intime 은 FALSE 라 해당 처방이 통째로 누락된다.
  --   cte_antimicrobial / cte_statin 과 동일하게 COALESCE 로 방어한다.
  WHERE a.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
    AND COALESCE(a.stoptime, a.starttime) >= i.intime
  GROUP BY a.stay_id
),

-- stay_id, aki_stage_24h
cte_aki AS (
  SELECT k.stay_id, MAX(k.aki_stage) AS aki_stage_24h
  FROM `physionet-data.mimiciv_3_1_derived.kdigo_stages` k
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON k.stay_id = i.stay_id
  WHERE k.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY k.stay_id
),

-- stay_id, sedation_use, use_of_midazolam
cte_sedation AS (
  SELECT 
    ie.stay_id,
    MAX(CASE WHEN ie.itemid IN (225150, 229420, 221668, 222168) THEN 1 ELSE 0 END) AS sedation_use, 
    MAX(CASE WHEN ie.itemid = 221668 THEN 1 ELSE 0 END) AS use_of_midazolam
  FROM `physionet-data.mimiciv_3_1_icu.inputevents` ie
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON ie.stay_id = i.stay_id
  WHERE ie.starttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY ie.stay_id
),

-- stay_id, vasopressor_use
cte_vasopressor AS (
  SELECT i.stay_id, MAX(1) AS vasopressor_use
  FROM `physionet-data.mimiciv_3_1_derived.norepinephrine_equivalent_dose` ne
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON ne.stay_id = i.stay_id
  WHERE ne.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
    AND COALESCE(ne.endtime, ne.starttime) >= i.intime
  GROUP BY i.stay_id
),

-- stay_id, charttime, glucose, prev_glucose, diff_hours
cte_raw_glucose AS (
  SELECT
    i.stay_id,
    ce.charttime,
    ce.valuenum AS glucose,
    LAG(ce.valuenum) OVER (PARTITION BY i.stay_id ORDER BY ce.charttime) AS prev_glucose,
    TIMESTAMP_DIFF(ce.charttime, LAG(ce.charttime) OVER (PARTITION BY i.stay_id ORDER BY ce.charttime), MINUTE) / 60.0 AS diff_hours
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_icu.chartevents` ce ON i.stay_id = ce.stay_id
  WHERE ce.itemid IN (220621, 225664, 226537, 228388)
    AND ce.valuenum IS NOT NULL
    -- [수정] 상한 미설정 버그. chartevents 혈당에 999938 같은 sentinel/오입력 값이
    --   섞여 있어 lage/mage/gli 가 오염된다 (103 데이터셋 실측: lage max=999,938,
    --   gli max=1.7e11, mage~lage 상관 0.999999 — 극단값이 만든 인공적 상관).
    --   mimic-code first_day_lab 은 자체 sanity filter 가 있어 glucose_min/max 는
    --   정상이지만 chartevents 직접 조회 경로에는 필터가 없었다.
    --   생리학적 범위 20~2000 mg/dL 로 제한한다 (MBG/MAG 도 동일 CTE 를 쓰므로 함께 교정됨).
    AND ce.valuenum BETWEEN 20 AND 2000
    AND ce.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
),

-- stay_id, mean_gluc, sd_gluc, max_gluc, min_gluc, total_hours
cte_glucose_stats AS (
  -- [수정] total_hours 에서 측정 간격 30분 미만인 인접 쌍을 제외한다.
  --   mean/max/min 은 간격과 무관하므로 전체 측정치를 그대로 사용한다.
  SELECT stay_id,
    AVG(glucose)    AS mean_gluc,
    STDDEV(glucose) AS sd_gluc,
    MAX(glucose)    AS max_gluc,
    MIN(glucose)    AS min_gluc,
    SUM(CASE WHEN diff_hours >= 0.5 THEN diff_hours END) AS total_hours
  FROM cte_raw_glucose GROUP BY stay_id
),

-- stay_id, lage, mage, gli, mbg, mag
--   [ADDED] MBG / MAG — Wang & Mei, Front Endocrinol 2024;15:1400207
--     MBG = 24h 내 혈당 측정치의 산술평균
--     MAG = Σ|Δglucose| / Σ Δtime  (인접 측정치 간 절대변화량 합 / 총 경과시간)
--   ※ 원논문은 mmol/L 기준이나 MIMIC 혈당은 mg/dL 이므로 본 파일은 mg/dL(및 mg/dL/h)로
--     산출한다. 기존 lage/mage/gli 와 단위계가 일관된다. 논문 Methods 에 단위 명시할 것.
--     (mmol/L 환산이 필요하면 mg/dL 값을 18.0 으로 나눌 것)
cte_gluc_met AS (
  -- [수정] 측정 간격 30분(0.5h) 미만인 인접 쌍을 MAGE / GLI / MAG 계산에서 제외한다.
  --   사유 : GLI 는 인접 쌍마다 dTime 으로 나누므로 간격이 0 에 가까우면 값이 폭발한다.
  --          본 코호트 실측 — 간격 5분 미만 쌍은 전체의 1.5% 인데 GLI 총량의 47.2% 를
  --          만들었고, 30분 미만까지 넓히면 데이터 8.4% 가 GLI 의 68% 를 결정했다.
  --          반대로 원논문이 상정한 1시간 이상 구간(데이터의 81%)은 21% 만 기여했다.
  --          이는 혈당 변동성이 아니라 손끝채혈-검사실혈당 간 측정오차, 인슐린 적정 중
  --          반복측정, 저혈당 재확인 등 '측정 행위'의 산물이다.
  --          MAG 도 분모(total_hours)가 함께 작아져 같은 방향으로 왜곡된다.
  --   근거 : 원논문(Wang & Mei 2024)은 4시간 간격 6회 측정(T1-T6)을 전제하므로
  --          30분 미만 간격은 애초에 정의 범위 밖이다. Methods 에 제외 기준 명시할 것.
  --   ※ LAGE(최대-최소)와 MBG(평균)는 간격을 쓰지 않으므로 필터 대상이 아니다.
  SELECT
    r.stay_id,
    MAX(s.max_gluc - s.min_gluc) AS lage,
    MAX(s.mean_gluc)             AS mbg,
    AVG(CASE WHEN r.diff_hours >= 0.5
              AND ABS(r.glucose - r.prev_glucose) > s.sd_gluc
             THEN ABS(r.glucose - r.prev_glucose) END) AS mage,
    SAFE_DIVIDE(
      SUM(CASE WHEN r.diff_hours >= 0.5 AND r.prev_glucose IS NOT NULL
               THEN ABS(r.glucose - r.prev_glucose) END),
      NULLIF(MAX(s.total_hours), 0)
    ) AS mag,
    SAFE_DIVIDE(
      SUM(CASE WHEN r.diff_hours >= 0.5
               THEN POWER(r.glucose - r.prev_glucose, 2) / r.diff_hours ELSE 0 END),
      NULLIF(MAX(s.total_hours), 0)
    ) AS gli
  FROM cte_raw_glucose r
  JOIN cte_glucose_stats s ON r.stay_id = s.stay_id
  GROUP BY r.stay_id
),

-- [height]
--   정의 : chartevents itemid 226730(cm) / 226707(inch) + omr 'Height (Inches)'
--          의 환자 단위 평균. 생리적 범위 100-250cm.
--   출처 : 본 연구 정의
--   비고 : [의도적 유지] subject_id 단위 집계이므로 해당 입원 외(외래·타 입원)
--          측정치가 포함된다. 엄밀히는 24시간 시점 관찰 자료가 아니나, 성인의
--          신장은 시간에 따라 실질적으로 변하지 않는 상수로 간주하여 유지한다.
--          입원 전 기록만 사용하도록 제한할 경우 height 결측률(현행 73%)과
--          이를 물려받는 gnri(90%)·body_mass_index 의 결측이 크게 악화된다.
--          논문 Methods 에 "환자 단위 평균값 사용"으로 명시할 것.
cte_patient_height AS (
  SELECT subject_id, AVG(height_cm) AS height
  FROM (
    SELECT subject_id, valuenum AS height_cm FROM `physionet-data.mimiciv_3_1_icu.chartevents` WHERE itemid = 226730 AND valuenum > 0
    UNION ALL
    SELECT subject_id, valuenum * 2.54 AS height_cm FROM `physionet-data.mimiciv_3_1_icu.chartevents` WHERE itemid = 226707 AND valuenum > 0
    UNION ALL
    SELECT subject_id, SAFE_CAST(result_value AS FLOAT64) * 2.54 AS height_cm FROM `physionet-data.mimiciv_3_1_hosp.omr` WHERE result_name = 'Height (Inches)' AND SAFE_CAST(result_value AS FLOAT64) IS NOT NULL
  )
  WHERE height_cm BETWEEN 100 AND 250 GROUP BY subject_id
),

-- stay_id, weight
cte_stay_weight AS (
  SELECT ce.stay_id, AVG(ce.valuenum) AS weight
  FROM `physionet-data.mimiciv_3_1_icu.chartevents` ce
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON ce.stay_id = i.stay_id
  WHERE ce.itemid IN (226512, 224639) AND ce.valuenum BETWEEN 25 AND 300
    AND ce.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY ce.stay_id
),

-- stay_id, height, weight, gnri
cte_gnri AS (
  SELECT 
    sw.stay_id,
    ph.height,
    sw.weight,
    CASE 
      WHEN fdl.albumin_min IS NULL OR ph.height IS NULL OR sw.weight IS NULL THEN NULL
      ELSE 14.89 * fdl.albumin_min + 41.7 * (
        CASE 
          WHEN (sw.weight / NULLIF(CASE WHEN p.gender = 'F' THEN ph.height - 100.0 - ((ph.height - 150.0) / 2.5) ELSE ph.height - 100.0 - ((ph.height - 150.0) / 4.0) END, 0)) > 1 THEN 1
          ELSE (sw.weight / NULLIF(CASE WHEN p.gender = 'F' THEN ph.height - 100.0 - ((ph.height - 150.0) / 2.5) ELSE ph.height - 100.0 - ((ph.height - 150.0) / 4.0) END, 0))
        END
      )
    END AS gnri
  FROM cte_stay_weight sw
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON sw.stay_id = i.stay_id
  JOIN `physionet-data.mimiciv_3_1_hosp.patients` p ON i.subject_id = p.subject_id
  LEFT JOIN cte_patient_height ph ON p.subject_id = ph.subject_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_lab` fdl ON sw.stay_id = fdl.stay_id
),

-- stay_id, egfr
cte_egfr AS (
  SELECT
    i.stay_id,
    CASE
      WHEN fdl.creatinine_max IS NULL OR p.anchor_age IS NULL THEN NULL
      ELSE 
        142.0 
        * POWER(LEAST(fdl.creatinine_max / CASE WHEN p.gender = 'F' THEN 0.7 ELSE 0.9 END, 1.0), CASE WHEN p.gender = 'F' THEN -0.241 ELSE -0.302 END) 
        * POWER(GREATEST(fdl.creatinine_max / CASE WHEN p.gender = 'F' THEN 0.7 ELSE 0.9 END, 1.0), -1.200) 
        * POWER(0.9938, p.anchor_age) 
        * CASE WHEN p.gender = 'F' THEN 1.012 ELSE 1.0 END
    END AS egfr
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.patients` p ON i.subject_id = p.subject_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_lab` fdl ON i.stay_id = fdl.stay_id
),

-- stay_id, avg_lymph, avg_mono, avg_neut
cte_bd_agg AS (
  SELECT i.stay_id, AVG(bd.lymphocytes_abs) AS avg_lymph, AVG(bd.monocytes_abs) AS avg_mono, AVG(bd.neutrophils_abs) AS avg_neut
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_derived.blood_differential` bd ON i.hadm_id = bd.hadm_id AND bd.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- stay_id, avg_platelet
cte_cbc_agg AS (
  SELECT i.stay_id, AVG(cbc.platelet) AS avg_platelet
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_derived.complete_blood_count` cbc ON i.hadm_id = cbc.hadm_id AND cbc.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- stay_id, lmr, nlr, plr
cte_cell_ratios AS (
  SELECT 
    b.stay_id,
    SAFE_DIVIDE(b.avg_lymph, b.avg_mono) AS lmr,
    SAFE_DIVIDE(b.avg_neut, b.avg_lymph) AS nlr,
    SAFE_DIVIDE(c.avg_platelet, b.avg_lymph) AS plr
  FROM cte_bd_agg b
  LEFT JOIN cte_cbc_agg c ON b.stay_id = c.stay_id
),

-- stay_id, pni
cte_pni AS (
  SELECT 
    b.stay_id,
    CASE
      WHEN fdl.albumin_min IS NULL OR b.avg_lymph IS NULL THEN NULL
      ELSE 10.0 * fdl.albumin_min + 0.005 * (b.avg_lymph * 1000.0)
    END AS pni
  FROM cte_bd_agg b
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_lab` fdl ON b.stay_id = fdl.stay_id
),

-- ==============================================================================
-- [ADDED] 아래 3개 CTE는 103개 pool 완성을 위해 추가됨
-- ==============================================================================

-- stay_id, 적혈구 지수 (first_day_lab에 없고 complete_blood_count에만 존재)
cte_rbc_indices AS (
  SELECT
    i.stay_id,
    MIN(cbc.mcv)  AS mcv_min,   MAX(cbc.mcv)  AS mcv_max,
    MIN(cbc.mch)  AS mch_min,   MAX(cbc.mch)  AS mch_max,
    MIN(cbc.mchc) AS mchc_min,  MAX(cbc.mchc) AS mchc_max,
    MIN(cbc.rdw)  AS rdw_min,   MAX(cbc.rdw)  AS rdw_max,
    MIN(cbc.rbc)  AS rbc_min,   MAX(cbc.rbc)  AS rbc_max
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_derived.complete_blood_count` cbc
    ON i.hadm_id = cbc.hadm_id
   AND cbc.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- stay_id, magnesium / phosphate (파생 테이블 미제공 -> labevents 직접, itemid 50960/50970)
cte_mg_phos AS (
  SELECT
    i.stay_id,
    MIN(CASE WHEN le.itemid = 50960 THEN le.valuenum END) AS magnesium_min,
    MAX(CASE WHEN le.itemid = 50960 THEN le.valuenum END) AS magnesium_max,
    MIN(CASE WHEN le.itemid = 50970 THEN le.valuenum END) AS phosphate_min,
    MAX(CASE WHEN le.itemid = 50970 THEN le.valuenum END) AS phosphate_max
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.labevents` le
    ON i.hadm_id = le.hadm_id
   AND le.itemid IN (50960, 50970)
   AND le.valuenum IS NOT NULL
   AND le.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- 미생물 배양 (24h) — org_name 전수 분류
--   코호트 24시간 창에 등장하는 285개 고유 org_name 값을 남김없이 8범주로 분류.
--   미분류 0건. 전체 매핑표는 org_name_classification.csv (부록용) 참조.
--   규칙 순서가 중요: 검사실이 그람 결과를 직접 기재한 값을 균속명보다 우선 적용.
--   ※ 항산균·바이러스·기생충·세포내기생균은 그람염색 분류 대상이 아니므로 별도 범주.
--   ※ Jin et al. 2024 는 조작적 정의를 제시하지 않아 본 연구에서 정의함 (전수 분류).
cte_micro_cls AS (
  SELECT i.stay_id,
    CASE
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'^CANCELLED$|^POSITIVE$|^NEGATIVE$|^ORGANISM$|MIXED BACTERIAL FLORA') THEN 'Nonspecific'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'STRONGYLOIDES|ENDOLIMAX|BLASTOCYSTIS') THEN 'Parasite'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'VIRUS|VIRAL|RSV|INFLUENZA|ADENO|CYTOMEGALO|HERPES|VARICELLA|RHINOVIRUS|PARAINFLUENZA|HSV') THEN 'Viral'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'CHLAMYDIA') THEN 'Atypical'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'MYCOBACTER|ACIDFAST|^AFB|M\. TUBERCULOSIS') THEN 'Mycobacteria'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'CANDIDA|ASPERGILL|YEAST|^MOLD|FUNGUS|CRYPTOCOCC|PENICILLIUM|MUCOR|RHIZOPUS|FUSARIUM|CURVULARIA|TRICHODERMA|PHOMA|CLADOSPORIUM|ACREMONIUM|PAECILOMYCES|EXOPHIALA|MYCELIA|DEMATIACEOUS|ALTERNARIA|VERTICILLIUM|CUNNINGHAMELLA|MALASSEZIA|TRICHOSPORON|PNEUMOCYSTIS') THEN 'Fungal'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'GRAM POSITIVE') THEN 'Gram positive'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'GRAM NEGATIVE') THEN 'Gram negative'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'STAPH|S\. AUREUS|STREPTOC|STREPTOCC|ENTEROCOCC|LISTERIA|CLOSTRIDI|CORYNEBACT|CUTIBACTERIUM|BACILLUS|PEPTOSTREP|LACTOBACIL|PROPIONIBACT|MICROCOCC|STOMATOCOCC|KOCURIA|AEROCOCC|ABIOTROPHIA|GRANULICATELLA|GEMELLA|DOLOSIGRANULUM|LACTOCOCC|ACTINOMYCES|EUBACTERIUM|FLAVONIFRACTOR|STREPTOMYCES|GORDONIA|NOCARDIA|GARDNERELLA') THEN 'Gram positive'
      WHEN REGEXP_CONTAINS(UPPER(TRIM(m.org_name)), r'ESCHERICHIA|KLEBSIELLA|RAOULTELLA|PSEUDOMONAS|ACINETOBACT|ENTEROBACT|ENTEROBACTERIACEAE|PROTEUS|SERRATIA|HAEMOPHILUS|NEISSERIA|BACTEROIDES|CITROBACT|MORGANELLA|STENOTROPHOMONAS|LEGIONELLA|SALMONELLA|SHIGELLA|VIBRIO|CAMPYLOBACT|BURKHOLDERIA|ALCALIGENES|ACHROMOBACT|CHRYSEOBACT|ELIZABETHKINGIA|PREVOTELLA|PANTOEA|HAFNIA|PROVIDENCIA|MORAXELLA|AEROMONAS|FUSOBACTERIUM|VEILLONELLA|DESULFOVIBRIO|PORPHYROMONAS|CAPNOCYTOPHAGA|EIKENELLA|PASTEURELLA|BORDETELLA|CUPRIAVIDUS|MYROIDES|SHEWANELLA|OLIGELLA|ROSEOMONAS|CRONOBACTER|NON-FERMENTER') THEN 'Gram negative'
      ELSE 'Unclassified' END AS c
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.microbiologyevents` m
    ON i.hadm_id = m.hadm_id
  -- [수정] charttime(검체 채취) -> storetime(결과 등록). 파일 상단 (D) 참조.
  --   org_name 은 배양 결과이므로 채취 시각 기준으로 자르면 24시간 시점에
  --   알 수 없는 정보가 예측변수로 들어간다 (information leakage).
   AND m.storetime IS NOT NULL
   AND m.storetime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
),
cte_micro AS (
  SELECT stay_id,
    MAX(CASE WHEN c='Gram positive' THEN 1 ELSE 0 END) AS micro_gram_positive,
    MAX(CASE WHEN c='Gram negative' THEN 1 ELSE 0 END) AS micro_gram_negative,
    MAX(CASE WHEN c='Fungal'        THEN 1 ELSE 0 END) AS micro_fungal,
    MAX(CASE WHEN c IN ('Mycobacteria','Viral','Parasite','Atypical') THEN 1 ELSE 0 END) AS micro_other
  FROM cte_micro_cls GROUP BY stay_id
),
-- 배양 시행 여부 (균 동정과 별개) — '배양 미시행' vs '배양 음성' 구분용
--   [유지] 이 변수는 '검사를 시행했는가'만 보므로 채취 시각(charttime) 기준이 맞고
--          24시간 시점에 관찰 가능하다. 누출 없음.
cte_culture AS (
  SELECT DISTINCT i.stay_id
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.microbiologyevents` m
    ON i.hadm_id = m.hadm_id
   AND m.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
),

-- [statin_drugs]
--   정의 : WHO ATC C10AA (HMG-CoA reductase inhibitors) 성분명 정규식 매칭
--   출처 : 본 연구 정의 (Guo et al. 2024 는 약물 목록 미제시)
--   비고 : [수정] 기존에는 prescriptions 를 입원 전체 기간으로 집계하여 ICU 입실
--          10일차에 시작한 스타틴도 1 이 되었다(정보 누출). 다른 약물 변수와
--          동일하게 ICU 입실 후 24시간 창으로 제한하고 stay_id 단위로 바꾼다.
cte_statin AS (
  SELECT i.stay_id,
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
      -- WHO ATC C10AA 전체 성분: atorvastatin, simvastatin, rosuvastatin, pravastatin,
      -- lovastatin, fluvastatin, pitavastatin, cerivastatin
      r'STATIN|ATORVA|SIMVA|ROSUVA|PRAVA|LOVA|FLUVA|PITAVA|CERIVA')
      THEN 1 ELSE 0 END) AS statin_drugs
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.prescriptions` pr
    ON i.hadm_id = pr.hadm_id
   AND pr.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
   AND COALESCE(pr.stoptime, pr.starttime) >= i.intime
  GROUP BY i.stay_id
),

-- ==============================================================================
-- [ADDED] Infection — 24시간 내 관찰 가능한 "치료 의도" 기반 정의
-- ==============================================================================
--   설계 원칙
--     (1) 배양 '결과'를 요구하지 않는다. 혈액배양 양성 신호 12~36h, 균 동정까지
--         추가 24~48h 이므로 24시간 시점에는 알 수 없다.
--     (2) 세균에 한정하지 않는다. mimic-code 의 derived.antibiotic 은 항세균제 위주로
--         항바이러스제가 0종이라 바이러스 감염이 구조적으로 누락된다.
--         -> 항세균제 + 항진균제 + 항바이러스제로 확장한다.
--     (3) 판정 시점을 ICU 입실 후 24시간 창 안으로 자른다.
--
--   정의 : (24h 내 항미생물제 투여 시작) AND (24h 내 미생물 검사 검체 채취)
--          = suspicion of infection 논리를 24시간 창으로 절단한 형태
--          Seymour CW et al., JAMA 2016;315:762 (Sepsis-3) 의
--          suspected infection 조작화를 따르되 약제 범위를 확장함.

-- 24h 내 투여된 항미생물제 (항세균 + 항진균 + 항바이러스)
cte_antimicrobial AS (
  SELECT
    i.stay_id,
    MAX(1) AS antimicrobial_any,
    -- 계열별 플래그 (민감도 분석 및 논문 부록용)
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
      r'ACYCLOVIR|VALACYCLOVIR|FAMCICLOVIR|GANCICLOVIR|VALGANCICLOVIR|FOSCARNET|CIDOFOVIR|OSELTAMIVIR|ZANAMIVIR|PERAMIVIR|RIMANTADINE|AMANTADINE|RIBAVIRIN|REMDESIVIR|LETERMOVIR|MARIBAVIR')
      THEN 1 ELSE 0 END) AS antiviral_use,
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
      r'FLUCONAZOLE|ITRACONAZOLE|VORICONAZOLE|POSACONAZOLE|ISAVUCONAZ|KETOCONAZOLE|CASPOFUNGIN|MICAFUNGIN|ANIDULAFUNGIN|AMPHOTERICIN|FLUCYTOSINE|NYSTATIN|TERBINAFINE|GRISEOFULVIN')
      THEN 1 ELSE 0 END) AS antifungal_use
  FROM `physionet-data.mimiciv_3_1_icu.icustays` i
  JOIN `physionet-data.mimiciv_3_1_hosp.prescriptions` pr
    ON i.hadm_id = pr.hadm_id
   AND pr.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
   AND COALESCE(pr.stoptime, pr.starttime) >= i.intime
  WHERE COALESCE(pr.drug_type, '') != 'BASE'
    -- 국소 제형 / 안이과 투여경로 제외 (mimic-code antibiotic.sql 과 동일 기준)
    AND COALESCE(pr.route, '') NOT IN ('OU','OS','OD','AU','AS','AD','TP')
    AND LOWER(COALESCE(pr.route, '')) NOT LIKE '%ear%'
    AND LOWER(COALESCE(pr.route, '')) NOT LIKE '%eye%'
    AND LOWER(pr.drug) NOT LIKE '%cream%'
    AND LOWER(pr.drug) NOT LIKE '%ointment%'
    AND LOWER(pr.drug) NOT LIKE '%gel%'
    AND LOWER(pr.drug) NOT LIKE '%desensitization%'
    -- (a) 항세균제 — mimic-code antibiotic.sql 성분 목록 기준
    -- (b) 항진균제 — mimic-code 는 amphotericin/anidulafungin 2종뿐이라 확장
    -- (c) 항바이러스제 — mimic-code 에 0종. 본 연구에서 추가
    AND REGEXP_CONTAINS(UPPER(pr.drug), r'AMIKACIN|AMOXICILL|AMPICILLIN|AZITHROMYCIN|AZTREONAM|BACITRACIN|CEFAZOLIN|CEFEPIME|CEFOTAXIME|CEFOTETAN|CEFOXITIN|CEFPODOXIME|CEFTAROLINE|CEFTAZIDIME|CEFTRIAXONE|CEFUROXIME|CEFACLOR|CEFADROXIL|CEFDINIR|CEFDITOREN|CEFPROZIL|CEFTIBUTEN|CEPHALEXIN|CEPHALOTHIN|CHLORAMPHENICOL|CIPROFLOXACIN|CLARITHROMYCIN|CLINDAMYCIN|CLAVULANATE|COLISTIN|DALBAVANCIN|DAPTOMYCIN|DICLOXACILLIN|DORIPENEM|DOXYCY|ERTAPENEM|ERYTHROMYCIN|FIDAXOMICIN|FOSFOMYCIN|GENTAMICIN|IMIPENEM|KANAMYCIN|LEVOFLOXACIN|LINEZOLID|MEROPENEM|METHICILLIN|METRONIDAZOLE|MINOCYCLINE|MOXIFLOXACIN|MUPIROCIN|NAFCILLIN|NEOMYCIN|NITROFURANTOIN|NORFLOXACIN|OFLOXACIN|ORITAVANCIN|OXACILLIN|PENICILLIN|PIPERACILLIN|POLYMYXIN|QUINUPRISTIN|RIFAMPIN|RIFAXIMIN|STREPTOMYCIN|SULFADIAZINE|SULFAMETHOXAZOLE|SULFISOXAZOLE|TAZOBACTAM|TEDIZOLID|TELAVANCIN|TETRACYCLINE|TIGECYCLINE|TOBRAMYCIN|TRIMETHOPRIM|VANCOMYCIN|BACTRIM|SEPTRA|ZOSYN|UNASYN|AUGMENTIN|ZYVOX|CUBICIN|ROCEPHIN|MAXIPIME|FORTAZ|TAZICEF|INVANZ|PRIMAXIN|SYNERCID|FLUCONAZOLE|ITRACONAZOLE|VORICONAZOLE|POSACONAZOLE|ISAVUCONAZ|KETOCONAZOLE|CASPOFUNGIN|MICAFUNGIN|ANIDULAFUNGIN|AMPHOTERICIN|FLUCYTOSINE|NYSTATIN|TERBINAFINE|GRISEOFULVIN|ACYCLOVIR|VALACYCLOVIR|FAMCICLOVIR|GANCICLOVIR|VALGANCICLOVIR|FOSCARNET|CIDOFOVIR|OSELTAMIVIR|ZANAMIVIR|PERAMIVIR|RIMANTADINE|AMANTADINE|RIBAVIRIN|REMDESIVIR|LETERMOVIR|MARIBAVIR')
  GROUP BY i.stay_id
),

-- 최종 infection 플래그 : 항미생물제 투여 AND 미생물 검사 시행 (둘 다 24h 내)
cte_infection AS (
  SELECT
    am.stay_id,
    CASE WHEN cu.stay_id IS NOT NULL THEN 1 ELSE 0 END AS infection,
    am.antiviral_use,
    am.antifungal_use
  FROM cte_antimicrobial am
  LEFT JOIN cte_culture cu ON am.stay_id = cu.stay_id
)

-- ==============================================================================
-- [2] Main Query
-- ==============================================================================
SELECT *
FROM (
  SELECT
    -- Demographics & Timestamps
    d.subject_id,
    d.hadm_id,
    d.stay_id,
    -- delirium_patients_v2 (CAM-ICU HAVING 수정본) 컬럼명
    d.first_delirium_time AS delirium_charttime,
    d.has_delirium_ever   AS delirium,
    adm.deathtime,
    i.intime,
    i.outtime,
    p.anchor_age,
    ROW_NUMBER() OVER (PARTITION BY d.subject_id ORDER BY i.intime) AS rn,
    TIMESTAMP_DIFF(i.outtime, i.intime, HOUR) AS icu_hours,
    i.first_careunit AS type_of_initial_icu_admission,

    -- Comorbidities
    COALESCE(c.has_anemia, 0)                  AS has_anemia,
    COALESCE(c.alcohol_abuse, 0)               AS alcohol_abuse,
    COALESCE(c.heart_failure, 0)               AS heart_failure,
    COALESCE(c.cerebrovascular_disease, 0)     AS cerebrovascular_disease,
    COALESCE(c.copd, 0)                        AS copd,
    COALESCE(c.dementia, 0)                    AS dementia,
    COALESCE(c.depression, 0)                  AS depression,
    COALESCE(c.diabetes, 0)                    AS diabetes,
    COALESCE(c.hypertension, 0)                AS hypertension,
    COALESCE(c.liver_disease, 0)               AS liver_disease,
    COALESCE(c.peripheral_vascular_disease, 0) AS peripheral_vascular_disease,
    COALESCE(c.renal_disease, 0)               AS renal_disease,
    COALESCE(c.acute_myocardial_infarction, 0) AS acute_myocardial_infarction, 
    COALESCE(c.stroke, 0)                      AS stroke,
    -- [ADDED 107] 협의(죽상경화성) CVD — ICD-9 410-414/4292/440, ICD-10 I20-I25/I70
    COALESCE(c.cardiovascular_disease, 0)      AS cardiovascular_disease,
    COALESCE(surg.cabg, 0)                     AS cabg,

    -- Severity Scores
    fdsofa.sofa AS sofa_score,
    fdgcs.gcs_min       AS gcs_min,
    apsiii.apsiii   AS apache_score,
    lods.lods       AS logistic_organ_dysfunction_score,
    oasis.oasis     AS oxford_acute_severity_of_illness_score,
    sapsii.sapsii   AS simplified_acute_physiology_score_ii,
    sirs.sirs       AS systemic_inflammatory_response_syndrome,
    CASE WHEN sepsis.sepsis3 IS TRUE THEN 1 ELSE 0 END AS sepsis,
    -- [ADDED 107] Charlson Comorbidity Index — derived.charlson 은 이미 JOIN 되어 있었음
    ch.charlson_comorbidity_index AS charlson_comorbidity_index,
    -- [ADDED 107] Infection — 24h 내 항미생물제 투여 + 미생물 검사 시행
    --   결측(=항미생물제 미투여)은 0 으로 처리
    COALESCE(inf.infection, 0) AS infection,

    -- Vitals
    fdv.dbp_min         AS diastolic_blood_pressure_min, 
    fdv.dbp_max         AS diastolic_blood_pressure_max,
    fdv.heart_rate_min  AS heart_rate_min, 
    fdv.heart_rate_max  AS heart_rate_max,
    fdv.mbp_min         AS mean_blood_pressure_min,
    fdv.mbp_max         AS mean_blood_pressure_max,
    fdv.spo2_min        AS oxygen_saturation_min, 
    fdv.spo2_max        AS oxygen_saturation_max,
    fdv.resp_rate_min   AS respiratory_rate_min, 
    fdv.resp_rate_max   AS respiratory_rate_max,
    fdv.sbp_min         AS systolic_blood_pressure_min, 
    fdv.sbp_max         AS systolic_blood_pressure_max,
    fdv.temperature_min AS temperature_min, 
    fdv.temperature_max AS temperature_max,

    -- Labs
    -- ===== [ADDED] 인구학 / 행정 =====
    p.gender                     AS sex,
    idt.race                     AS ethnicity,
    adm.insurance                AS insurance,
    adm.marital_status           AS marital_status,
    CASE WHEN adm.admission_type IN ('ELECTIVE', 'SURGICAL SAME DAY ADMISSION') THEN 1 ELSE 0 END AS elective_surgery,

    -- ===== [ADDED] 동반질환 / 수술 =====
    COALESCE(ch.malignant_cancer, 0)     AS cancer,
    COALESCE(c.nicotine_dependence, 0)   AS nicotine_dependence,
    COALESCE(surg.heart_valve_surgery, 0) AS heart_valve_surgery,
    COALESCE(surg.aortic_surgery, 0)      AS aortic_surgery,
    CASE
      WHEN COALESCE(surg.cabg,0)+COALESCE(surg.heart_valve_surgery,0)+COALESCE(surg.aortic_surgery,0) = 0 THEN 'None'
      WHEN COALESCE(surg.cabg,0)+COALESCE(surg.heart_valve_surgery,0)+COALESCE(surg.aortic_surgery,0) > 1 THEN 'Combined'
      WHEN surg.aortic_surgery = 1 THEN 'Aortic'
      WHEN surg.heart_valve_surgery = 1 THEN 'Valve'
      ELSE 'CABG' END                     AS cardiac_surgery_type,
    COALESCE(st.statin_drugs, 0)          AS statin_drugs,

    -- ===== [수정] 미생물 (285개 org_name 전수 분류, 결측 0) =====
    --   [!! 해석 주의] culture_performed 는 검체 '채취'(charttime) 기준이고
    --   micro_* 는 결과 '확정'(storetime) 기준이라 시점이 다르다. 그 결과
    --   micro_category 의 'Culture negative' 는 두 가지가 섞인 범주가 되었다:
    --     (a) 배양했으나 균이 자라지 않음 (진짜 음성)
    --     (b) 배양했으나 24시간 시점에 결과가 아직 안 나옴 (미확정)
    --   배양 소요시간(혈액배양 12~36h)을 감안하면 (b)가 다수일 수 있다.
    --   verify 쿼리 [3-1] 로 비율을 확인한 뒤, 필요하면 범주를 분리하거나
    --   micro_* 결과 변수를 pool 에서 제외할 것.
    CASE WHEN cu.stay_id IS NULL THEN 0 ELSE 1 END AS culture_performed,
    COALESCE(mic.micro_gram_positive, 0) AS micro_gram_positive,
    COALESCE(mic.micro_gram_negative, 0) AS micro_gram_negative,
    COALESCE(mic.micro_fungal, 0)        AS micro_fungal,
    COALESCE(mic.micro_other, 0)         AS micro_other,
    CASE
      WHEN cu.stay_id IS NULL THEN 'No culture'
      WHEN COALESCE(mic.micro_gram_positive,0)+COALESCE(mic.micro_gram_negative,0)
          +COALESCE(mic.micro_fungal,0)+COALESCE(mic.micro_other,0) = 0 THEN 'Culture negative'
      WHEN COALESCE(mic.micro_gram_positive,0)+COALESCE(mic.micro_gram_negative,0)
          +COALESCE(mic.micro_fungal,0)+COALESCE(mic.micro_other,0) > 1 THEN 'Polymicrobial'
      WHEN mic.micro_gram_negative = 1 THEN 'Gram negative'
      WHEN mic.micro_gram_positive = 1 THEN 'Gram positive'
      WHEN mic.micro_fungal = 1 THEN 'Fungal'
      ELSE 'Other' END                   AS micro_category,

    -- ===== [ADDED] CBC 계열 =====
    fdl.hematocrit_min, fdl.hematocrit_max,
    fdl.hemoglobin_min, fdl.hemoglobin_max,
    fdl.platelets_min          AS platelet_count_min,
    fdl.platelets_max          AS platelet_count_max,
    fdl.abs_lymphocytes_min    AS lymphocyte_count_min,
    fdl.abs_lymphocytes_max    AS lymphocyte_count_max,
    fdl.abs_monocytes_min      AS monocyte_count_min,
    fdl.abs_monocytes_max      AS monocyte_count_max,
    rbci.mcv_min,  rbci.mcv_max,
    rbci.mch_min,  rbci.mch_max,
    rbci.mchc_min, rbci.mchc_max,
    rbci.rdw_min,  rbci.rdw_max,
    rbci.rbc_min,  rbci.rbc_max,

    -- ===== [ADDED] 전해질 / 화학 =====
    fdl.potassium_min,   fdl.potassium_max,
    fdl.calcium_min,     fdl.calcium_max,
    fdl.chloride_min,    fdl.chloride_max,
    fdl.bicarbonate_min, fdl.bicarbonate_max,
    mgp.magnesium_min,   mgp.magnesium_max,
    mgp.phosphate_min,   mgp.phosphate_max,

    -- ===== [ADDED] 간효소 / 응고 =====
    fdl.ast_min AS aspartate_aminotransferase_min,
    fdl.ast_max AS aspartate_aminotransferase_max,
    fdl.alt_min AS alanine_aminotransferase_min,
    fdl.alt_max AS alanine_aminotransferase_max,
    fdl.alp_min AS alkaline_phosphatase_min,
    fdl.alp_max AS alkaline_phosphatase_max,
    fdl.pt_min  AS prothrombin_time_min,
    fdl.pt_max  AS prothrombin_time_max,
    fdl.ptt_min AS partial_thromboplastin_time_min,
    fdl.ptt_max AS partial_thromboplastin_time_max,

    -- ===== [ADDED] 혈액가스 =====
    fdbg.baseexcess_min AS base_excess_min,
    fdbg.baseexcess_max AS base_excess_max,
    fdbg.totalco2_min   AS total_carbon_dioxide_min,
    fdbg.totalco2_max   AS total_carbon_dioxide_max,

    fdl.albumin_min           AS albumin_min, 
    fdl.albumin_max           AS albumin_max,
    fdl.aniongap_min          AS anion_gap_min, 
    fdl.aniongap_max          AS anion_gap_max,
    fdl.bun_min               AS blood_urea_nitrogen_min, 
    fdl.bun_max               AS blood_urea_nitrogen_max,
    fdl.creatinine_min        AS creatinine_min, 
    fdl.creatinine_max        AS creatinine_max,
    fdl.glucose_min           AS glucose_min, 
    fdl.glucose_max           AS glucose_max,
    fdl.sodium_min            AS blood_sodium_min,
    fdl.sodium_max            AS blood_sodium_max,
    fdl.wbc_min               AS white_blood_cell_count_min, 
    fdl.wbc_max               AS white_blood_cell_count_max,
    fdl.inr_min               AS international_normalized_ratio_min, 
    fdl.inr_max               AS international_normalized_ratio_max,
    fdl.bilirubin_total_min   AS bilirubin_min, 
    fdl.bilirubin_total_max   AS bilirubin_max,
    neut.neutrophils_min      AS neutrophil_count_min, 
    neut.neutrophils_max      AS neutrophil_count_max,
    fdbg.po2_min              AS arterial_partial_pressure_of_oxygen_min, 
    fdbg.po2_max              AS arterial_partial_pressure_of_oxygen_max,
    fdbg.pco2_min             AS arterial_partial_pressure_of_carbon_dioxide_min, 
    fdbg.pco2_max             AS arterial_partial_pressure_of_carbon_dioxide_max,
    fdbg.ph_min               AS blood_ph_min, 
    fdbg.ph_max               AS blood_ph_max,
    fdbg.lactate_min          AS lactate_min, 
    fdbg.lactate_max          AS lactate_max,
    fduo.urineoutput          AS urine_output,

    -- Treatments
    COALESCE(fdrrt.dialysis_present, 0) AS renal_replacement_therapy,
    COALESCE(vent.mech_vent_24h, 0)     AS mechanical_ventilation,
    COALESCE(abx.antibiotic_24h, 0)     AS antibiotic_drug_use,
    COALESCE(aki.aki_stage_24h, 0)      AS acute_kidney_injury,
    COALESCE(sed.sedation_use, 0)       AS sedation_use,
    COALESCE(sed.use_of_midazolam, 0)   AS use_of_midazolam,
    COALESCE(vaso.vasopressor_use, 0)   AS vasopressor_use,

    -- Custom Metrics (Glucose, Nutrition, Renal, Cell Ratios)
    gluc_met.mage,
    gluc_met.lage,
    gluc_met.gli,
    -- [ADDED 107] MBG / MAG (mg/dL, mg/dL/h)
    gluc_met.mbg AS mean_blood_glucose,
    gluc_met.mag AS mean_absolute_glucose,
    gnri_table.gnri,
    gnri_table.height, 
    gnri_table.weight,
    -- [ADDED 107] BMI = weight(kg) / height(m)^2. 생리학적 범위(10~80) 밖은 NULL 처리
    CASE
      WHEN gnri_table.height IS NULL OR gnri_table.weight IS NULL THEN NULL
      WHEN SAFE_DIVIDE(gnri_table.weight, POWER(gnri_table.height / 100.0, 2))
           BETWEEN 10 AND 80
        THEN SAFE_DIVIDE(gnri_table.weight, POWER(gnri_table.height / 100.0, 2))
      ELSE NULL
    END AS body_mass_index,
    egfr_table.egfr,
    cell_ratios.lmr AS lymphocyte_to_monocyte_ratio,
    cell_ratios.nlr AS neutrophil_to_lymphocyte_ratio,
    cell_ratios.plr AS platelet_to_lymphocyte_ratio,
    pni_table.pni   AS prognostic_nutritional_index

  FROM `yonsei1.delirium.delirium_patients_v2` d

  -- [2.1] MIMIC IV
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.patients` p      ON d.subject_id = p.subject_id
  LEFT JOIN `physionet-data.mimiciv_3_1_icu.icustays` i       ON d.stay_id = i.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.admissions` adm  ON d.hadm_id = adm.hadm_id

  -- [2.2] MIMIC IV Derived 
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_vitalsign` fdv   ON d.stay_id = fdv.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_lab` fdl         ON d.stay_id = fdl.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_bg_art` fdbg     ON d.stay_id = fdbg.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_urine_output` fduo ON d.stay_id = fduo.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_rrt` fdrrt       ON d.stay_id = fdrrt.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.apsiii` apsiii             ON d.stay_id = apsiii.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.lods` lods                 ON d.stay_id = lods.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.oasis` oasis               ON d.stay_id = oasis.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.sapsii` sapsii             ON d.stay_id = sapsii.stay_id
  -- [수정] sepsis3 는 ICU 재실 '전체 기간' 중 가장 이른 패혈증 발생 시점을 담는다
  --   (mimic-code sepsis3.sql: "the earliest time at which a patient had SOFA >= 2
  --    and suspicion of infection"). 시간 제한 없이 조인하면 ICU 6일차 패혈증도
  --   sepsis=1 이 되어 24시간 예측 설계를 위반한다. 발생 시점을 24h 창으로 자른다.
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.sepsis3` sepsis
    ON d.stay_id = sepsis.stay_id
   AND sepsis.suspected_infection_time <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.sirs` sirs                 ON d.stay_id = sirs.stay_id

  -- [2.3] CTE Joins
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_sofa` fdsofa ON d.stay_id = fdsofa.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.first_day_gcs`  fdgcs  ON d.stay_id = fdgcs.stay_id
  LEFT JOIN cte_comorbidities c           ON d.hadm_id = c.hadm_id
  LEFT JOIN cte_surgeries surg            ON d.hadm_id = surg.hadm_id
  LEFT JOIN cte_neutrophils neut          ON d.stay_id = neut.stay_id
  LEFT JOIN cte_ventilation vent          ON d.stay_id = vent.stay_id
  LEFT JOIN cte_antibiotic abx            ON d.stay_id = abx.stay_id
  LEFT JOIN cte_aki aki                   ON d.stay_id = aki.stay_id
  LEFT JOIN cte_sedation sed              ON d.stay_id = sed.stay_id
  LEFT JOIN cte_vasopressor vaso          ON d.stay_id = vaso.stay_id
  LEFT JOIN cte_gluc_met gluc_met         ON d.stay_id = gluc_met.stay_id
  LEFT JOIN cte_gnri gnri_table           ON d.stay_id = gnri_table.stay_id
  LEFT JOIN cte_egfr egfr_table           ON d.stay_id = egfr_table.stay_id
  LEFT JOIN cte_cell_ratios cell_ratios   ON d.stay_id = cell_ratios.stay_id
  LEFT JOIN cte_pni pni_table             ON d.stay_id = pni_table.stay_id
  -- ===== [ADDED] =====
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.charlson` ch        ON d.hadm_id = ch.hadm_id
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.icustay_detail` idt ON d.stay_id = idt.stay_id
  LEFT JOIN cte_rbc_indices rbci          ON d.stay_id = rbci.stay_id
  LEFT JOIN cte_mg_phos     mgp           ON d.stay_id = mgp.stay_id
  LEFT JOIN cte_micro       mic           ON d.stay_id = mic.stay_id
  LEFT JOIN cte_culture     cu            ON d.stay_id = cu.stay_id
  LEFT JOIN cte_statin      st            ON d.stay_id = st.stay_id
  -- ===== [ADDED 107] =====
  LEFT JOIN cte_infection   inf           ON d.stay_id = inf.stay_id

)
-- ==============================================================================
-- [3] 실행 후 검증 쿼리 (본 파일 실행과 별개로 따로 돌릴 것)
-- ==============================================================================

-- [3-1] 미생물 배양 결과가 24시간 안에 나오는가
--   micro_gram_positive / micro_gram_negative / micro_fungal / micro_other 4개는
--   '배양 결과'라서, 24시간 시점에 결과가 확정된 환자에게만 값이 존재한다.
--   그 비율이 낮으면 이 4개는 사실상 쓸 수 없는 변수이므로 pool 에서 뺀다.
--
--   [3-1a] 한 줄 요약 — 이것만 봐도 판단 가능
--     n_cohort         : 코호트 전체 환자 수
--     n_specimen_24h   : 24h 내 검체를 '채취'한 환자 수      (= culture_performed)
--     n_result_24h     : 24h 내 균 동정 '결과'까지 나온 환자 수 (= micro_* 가 유효)
--     result_rate_pct  : n_result_24h / n_specimen_24h
--       -> 이 값이 낮을수록 'Culture negative' 안에 '아직 결과 없음'이 많이 섞인다.
/*
WITH ev AS (
  SELECT
    d.stay_id,
    m.storetime,
    m.org_name,
    i.intime,
    m.charttime
  FROM `yonsei1.delirium.delirium_patients_v2` d
  JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON d.stay_id = i.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.microbiologyevents` m
    ON i.hadm_id = m.hadm_id
   AND m.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
)
SELECT
  COUNT(DISTINCT stay_id) AS n_cohort,
  COUNT(DISTINCT IF(charttime IS NOT NULL, stay_id, NULL)) AS n_specimen_24h,
  COUNT(DISTINCT IF(storetime <= TIMESTAMP_ADD(intime, INTERVAL 24 HOUR)
                    AND org_name IS NOT NULL, stay_id, NULL)) AS n_result_24h,
  ROUND(100 * COUNT(DISTINCT IF(storetime <= TIMESTAMP_ADD(intime, INTERVAL 24 HOUR)
                    AND org_name IS NOT NULL, stay_id, NULL))
            / NULLIF(COUNT(DISTINCT IF(charttime IS NOT NULL, stay_id, NULL)), 0), 1)
    AS result_rate_pct
FROM ev;
*/

--   [3-1b] 소요시간 분포 — 왜 그런 비율이 나왔는지 확인용
--     검체 채취(charttime)부터 결과 등록(storetime)까지 몇 시간 걸리는지.
--     24h 이하 구간에 얼마나 몰려 있는지 보면 된다.
/*
SELECT
  CASE
    WHEN TIMESTAMP_DIFF(m.storetime, m.charttime, HOUR) < 12  THEN '00-12h'
    WHEN TIMESTAMP_DIFF(m.storetime, m.charttime, HOUR) < 24  THEN '12-24h'
    WHEN TIMESTAMP_DIFF(m.storetime, m.charttime, HOUR) < 48  THEN '24-48h'
    WHEN TIMESTAMP_DIFF(m.storetime, m.charttime, HOUR) < 72  THEN '48-72h'
    ELSE '72h+'
  END AS turnaround,
  COUNT(*) AS n_tests,
  COUNTIF(m.org_name IS NOT NULL) AS n_with_organism,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_all
FROM `yonsei1.delirium.delirium_patients_v2` d
JOIN `physionet-data.mimiciv_3_1_icu.icustays` i ON d.stay_id = i.stay_id
JOIN `physionet-data.mimiciv_3_1_hosp.microbiologyevents` m
  ON i.hadm_id = m.hadm_id
 AND m.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
WHERE m.storetime IS NOT NULL
GROUP BY turnaround
ORDER BY turnaround;
*/

-- [3-2] 신규 6개 변수 분포 및 결측률
/*
SELECT
  COUNT(*)                                                   AS n,
  ROUND(AVG(cardiovascular_disease) * 100, 2)                AS cvd_pct,
  ROUND(AVG(infection) * 100, 2)                             AS infection_pct,
  ROUND(AVG(charlson_comorbidity_index), 2)                  AS cci_mean,
  ROUND(AVG(body_mass_index), 2)                             AS bmi_mean,
  ROUND(AVG(mean_blood_glucose), 2)                          AS mbg_mean,
  ROUND(AVG(mean_absolute_glucose), 3)                       AS mag_mean,
  ROUND(100 * COUNTIF(body_mass_index    IS NULL) / COUNT(*), 2) AS bmi_missing_pct,
  ROUND(100 * COUNTIF(mean_blood_glucose IS NULL) / COUNT(*), 2) AS mbg_missing_pct,
  ROUND(100 * COUNTIF(mean_absolute_glucose IS NULL) / COUNT(*), 2) AS mag_missing_pct,
  ROUND(100 * COUNTIF(charlson_comorbidity_index IS NULL) / COUNT(*), 2) AS cci_missing_pct
FROM `yonsei1.delirium.mimic_iv_dataset_107`;
*/

-- [3-3] CVD 구성요소별 기여도 및 기존 변수와의 중복 진단
--   Zipser 6개 클러스터를 OR 합산했으므로, 어느 클러스터가 유병률을 끌어올리는지와
--   기존 개별 변수(heart_failure / PVD / AMI)로 얼마나 설명되는지를 확인한다.
--   중복률이 95% 를 넘으면 CVD 를 pool 에서 빼거나 개별 클러스터로 되돌리는 것을 검토할 것.
/*
WITH cvd_parts AS (
  SELECT di.hadm_id,
    MAX(CASE WHEN (di.icd_version=9  AND SUBSTR(di.icd_code,1,3) IN ('396','397'))
              OR (di.icd_version=10 AND SUBSTR(di.icd_code,1,3) = 'I08')
         THEN 1 ELSE 0 END) AS valvular,
    MAX(CASE WHEN (di.icd_version=9  AND SUBSTR(di.icd_code,1,3) IN ('410','411','412','413','414'))
              OR (di.icd_version=10 AND SUBSTR(di.icd_code,1,3) IN ('I20','I21','I22','I23','I24','I25'))
         THEN 1 ELSE 0 END) AS ischemic,
    MAX(CASE WHEN (di.icd_version=9  AND SUBSTR(di.icd_code,1,3) = '425')
              OR (di.icd_version=10 AND SUBSTR(di.icd_code,1,3) IN ('I42','I43'))
         THEN 1 ELSE 0 END) AS cardiomyopathy,
    MAX(CASE WHEN (di.icd_version=9  AND SUBSTR(di.icd_code,1,4) = '4275')
              OR (di.icd_version=10 AND SUBSTR(di.icd_code,1,3) = 'I46')
         THEN 1 ELSE 0 END) AS cardiac_arrest,
    MAX(CASE WHEN (di.icd_version=9  AND SUBSTR(di.icd_code,1,3) = '428')
              OR (di.icd_version=10 AND SUBSTR(di.icd_code,1,3) = 'I50')
         THEN 1 ELSE 0 END) AS cardiac_insufficiency,
    MAX(CASE WHEN (di.icd_version=9  AND SUBSTR(di.icd_code,1,3) = '440')
              OR (di.icd_version=10 AND SUBSTR(di.icd_code,1,3) = 'I70')
         THEN 1 ELSE 0 END) AS atherosclerosis
  FROM `physionet-data.mimiciv_3_1_hosp.diagnoses_icd` di
  GROUP BY di.hadm_id
)
SELECT
  ROUND(100*AVG(t.cardiovascular_disease), 2) AS cvd_total_pct,
  ROUND(100*AVG(pt.valvular), 2)              AS valvular_pct,
  ROUND(100*AVG(pt.ischemic), 2)              AS ischemic_pct,
  ROUND(100*AVG(pt.cardiomyopathy), 2)        AS cardiomyopathy_pct,
  ROUND(100*AVG(pt.cardiac_arrest), 2)        AS cardiac_arrest_pct,
  ROUND(100*AVG(pt.cardiac_insufficiency), 2) AS cardiac_insuff_pct,
  ROUND(100*AVG(pt.atherosclerosis), 2)       AS atherosclerosis_pct,
  -- 기존 3개 변수만으로 CVD 를 설명할 수 있는 비율 (중복도)
  ROUND(100*AVG(CAST(t.cardiovascular_disease = GREATEST(
        t.heart_failure, t.peripheral_vascular_disease,
        t.acute_myocardial_infarction) AS INT64)), 2) AS redundancy_pct
FROM `yonsei1.delirium.mimic_iv_dataset_107` t
JOIN cvd_parts pt ON t.hadm_id = pt.hadm_id;
*/

-- [3-4] Infection 정의의 항바이러스/항진균 기여도
--   mimic-code 기본 정의(항세균 only) 대비 몇 건이 추가로 포착되는지.
/*
SELECT
  COUNTIF(infection = 1)                        AS n_infection,
  COUNTIF(infection = 1 AND sepsis = 0)         AS n_infection_not_sepsis,
  COUNTIF(infection = 1 AND antibiotic_drug_use = 0) AS n_infection_wo_abx
FROM `yonsei1.delirium.mimic_iv_dataset_107`;
*/

-- [3-5] 정보 누출 수정의 영향 — 수정 전/후 유병률 비교
--   sepsis / statin_drugs / 심장수술 3개 변수에 24h(또는 입실일) 제한을 걸면서
--   유병률이 얼마나 줄었는지 확인한다. 감소폭이 크면 그만큼 기존 데이터셋에
--   누출이 있었다는 뜻이므로, 논문 Methods 또는 Limitation 에 기술할 것.
/*
WITH unrestricted AS (
  SELECT
    d.stay_id,
    -- 수정 전: 시간 제한 없음
    MAX(CASE WHEN sp.sepsis3 IS TRUE THEN 1 ELSE 0 END) AS sepsis_old,
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
          r'STATIN|ATORVA|SIMVA|ROSUVA|PRAVA|LOVA|FLUVA|PITAVA|CERIVA')
         THEN 1 ELSE 0 END) AS statin_old
  FROM `yonsei1.delirium.delirium_patients_v2` d
  LEFT JOIN `physionet-data.mimiciv_3_1_derived.sepsis3` sp ON d.stay_id = sp.stay_id
  LEFT JOIN `physionet-data.mimiciv_3_1_hosp.prescriptions` pr ON d.hadm_id = pr.hadm_id
  GROUP BY d.stay_id
)
SELECT
  ROUND(100*AVG(u.sepsis_old), 2)  AS sepsis_pct_before,
  ROUND(100*AVG(t.sepsis), 2)      AS sepsis_pct_after,
  ROUND(100*AVG(u.statin_old), 2)  AS statin_pct_before,
  ROUND(100*AVG(t.statin_drugs), 2) AS statin_pct_after,
  ROUND(100*AVG(CASE WHEN t.cardiac_surgery_type != 'None' THEN 1 ELSE 0 END), 2)
                                   AS cardiac_surgery_pct_after
FROM `yonsei1.delirium.mimic_i