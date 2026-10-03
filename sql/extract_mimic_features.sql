-- MIMIC-IV cohort and feature extraction template
--
-- Render this file with scripts/render_sql.py before running it in Google
-- BigQuery. The template contains no institution-specific project identifier.
-- It expects a credentialed cohort table with subject_id, hadm_id, stay_id,
-- first_delirium_time, and has_delirium_ever, and creates a 107-feature table.
-- No patient-level result is distributed with this repository.

-- [1] Sub Query (CTEs)
-- ==============================================================================
CREATE OR REPLACE TABLE `{{WORK_PROJECT}}.{{WORK_DATASET}}.{{OUTPUT_TABLE}}` AS
WITH 

-- hadm_id, has_anemia, alcohol_abuse, heart_failure, cerebrovascular_disease, copd, dementia, depression, diabetes, hypertension, liver_disease, peripheral_vascular_disease, renal_disease, acute_myocardial_infarction, stroke
cte_comorbidities AS (
  -- ===========================================================================
  -- ===========================================================================
  SELECT
    di.hadm_id,
    -- [nicotine_dependence]
    MAX(CASE WHEN (di.icd_version = 9 AND di.icd_code IN ('3051', 'V1582')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) = 'F17' OR di.icd_code = 'Z87891')) THEN 1 ELSE 0 END) AS nicotine_dependence,

    -- [has_anemia]
    --          (Establishment and validation of a nomogram of postoperative delirium
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) IN ('280', '281', '282', '283', '284', '285')) OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('D50', 'D51', 'D52', 'D53', 'D55', 'D56', 'D57', 'D58', 'D59', 'D60', 'D61', 'D62', 'D63', 'D64')) THEN 1 ELSE 0 END) AS has_anemia,

    -- [alcohol_abuse]
    --          ICD-10 F10, E52, G62.1, I42.6, K29.2, K70.0/.3/.9, T51.x, Z50.2, Z71.4, Z72.1
    MAX(CASE WHEN (di.icd_version = 9 AND (di.icd_code IN ('2915', '2916', '2917', '2918', '2919', '3030', '3039', '3050', '3575', '4255', '5353', '980', 'V113') OR SUBSTR(di.icd_code, 1, 4) IN ('5710', '5711', '5712', '5713'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('F10', 'T51') OR di.icd_code IN ('E52', 'G621', 'I426', 'K292', 'K700', 'K703', 'K709', 'Z502', 'Z714', 'Z721'))) THEN 1 ELSE 0 END) AS alcohol_abuse,

    -- [heart_failure]
    --          ICD-10 I09.9, I11.0, I13.0, I13.2, I25.5, I42.0, I42.5-I42.9, I43.x, I50.x, P29.0
    MAX(CASE WHEN (di.icd_version = 9 AND (di.icd_code IN ('39891', '40201', '40211', '40291', '40401', '40403', '40411', '40413', '40491', '40493') OR SUBSTR(di.icd_code, 1, 3) = '428' OR SUBSTR(di.icd_code, 1, 4) IN ('4254', '4255', '4256', '4257', '4258', '4259'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('I43', 'I50') OR di.icd_code IN ('I099', 'I110', 'I130', 'I132', 'I255', 'I420', 'I425', 'I426', 'I427', 'I428', 'I429', 'P290'))) THEN 1 ELSE 0 END) AS heart_failure,

    -- [cerebrovascular_disease]
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('430', '431', '432', '433', '434', '435', '436', '437', '438') OR di.icd_code = '36234')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('G45', 'G46', 'I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67', 'I68', 'I69') OR di.icd_code = 'H340')) THEN 1 ELSE 0 END) AS cerebrovascular_disease,

    -- [copd]
    --          ICD-10 I27.8, I27.9, J40.x-J47.x, J60.x-J67.x, J68.4, J70.1, J70.3
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('490', '491', '492', '493', '494', '495', '496', '497', '498', '499', '500', '501', '502', '503', '504', '505') OR di.icd_code IN ('4168', '4169', '5064', '5081', '5088'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('J40', 'J41', 'J42', 'J43', 'J44', 'J45', 'J46', 'J47', 'J60', 'J61', 'J62', 'J63', 'J64', 'J65', 'J66', 'J67') OR di.icd_code IN ('I278', 'I279', 'J684', 'J701', 'J703'))) THEN 1 ELSE 0 END) AS copd,

    -- [dementia]
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) = '290' OR di.icd_code IN ('2941', '3312'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('F00', 'F01', 'F02', 'F03', 'G30') OR di.icd_code IN ('F051', 'G311'))) THEN 1 ELSE 0 END) AS dementia,

    -- [depression]
    --          ICD-10 F20.4, F31.3-F31.5, F32.x, F33.x, F34.1, F41.2, F43.2
    MAX(CASE WHEN (di.icd_version = 9 AND (di.icd_code IN ('2962', '2963', '2965', '3004', '311') OR SUBSTR(di.icd_code, 1, 3) = '309')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('F32', 'F33') OR di.icd_code IN ('F204', 'F313', 'F314', 'F315', 'F341', 'F412', 'F432'))) THEN 1 ELSE 0 END) AS depression,

    -- [diabetes]
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) = '250') OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')) THEN 1 ELSE 0 END) AS diabetes,

    -- [hypertension]
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) IN ('401', '402', '403', '404', '405')) OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('I10', 'I11', 'I12', 'I13', 'I15')) THEN 1 ELSE 0 END) AS hypertension,

    -- [liver_disease]
    --          572.2-572.8, 573.3/.4/.8/.9, V42.7
    --          ICD-10 B18.x, I85.0/.9, I86.4, I98.2, K70.x, K71.1/.3-.5/.7, K72.1/.9,
    --          K73.x, K74.x, K76.0, K76.2-K76.9, Z94.4
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('570', '571') OR di.icd_code IN ('07022', '07023', '07032', '07033', '07044', '07054', '0706', '0709', '4560', '4561', '4562', '5722', '5723', '5724', '5725', '5726', '5727', '5728', '5733', '5734', '5738', '5739', 'V427'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('B18', 'K70', 'K73', 'K74') OR di.icd_code IN ('I850', 'I859', 'I864', 'I982', 'K711', 'K713', 'K714', 'K715', 'K717', 'K721', 'K729', 'K760', 'K762', 'K763', 'K764', 'K765', 'K766', 'K767', 'K768', 'K769', 'Z944'))) THEN 1 ELSE 0 END) AS liver_disease,

    -- [peripheral_vascular_disease]
    --          ICD-10 I70.x, I71.x, I73.1/.8/.9, I77.1, I79.0, I79.2, K55.1/.8/.9, Z95.8, Z95.9
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('440', '441') OR di.icd_code IN ('0930', '4373', '4431', '4432', '4433', '4434', '4435', '4436', '4437', '4438', '4439', '4471', '5571', '5579', 'V434'))) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('I70', 'I71') OR di.icd_code IN ('I731', 'I738', 'I739', 'I771', 'I790', 'I792', 'K551', 'K558', 'K559', 'Z958', 'Z959'))) THEN 1 ELSE 0 END) AS peripheral_vascular_disease,

    -- [renal_disease]
    --          588.0, V42.0, V45.1, V56.x
    --          ICD-10 I12.0, I13.1, N03.2-N03.7, N05.2-N05.7, N18.x, N19.x, N25.0,
    --          Z49.0-Z49.2, Z94.0, Z99.2
    MAX(CASE WHEN (di.icd_version = 9 AND (SUBSTR(di.icd_code, 1, 3) IN ('582', '585', '586') OR di.icd_code IN ('40301', '40311', '40391', '40402', '40403', '40412', '40413', '40492', '40493', '5830', '5831', '5832', '5833', '5834', '5835', '5836', '5837', '5880', 'V420', 'V451') OR SUBSTR(di.icd_code, 1, 3) = 'V56')) OR (di.icd_version = 10 AND (SUBSTR(di.icd_code, 1, 3) IN ('N18', 'N19') OR di.icd_code IN ('I120', 'I131', 'N032', 'N033', 'N034', 'N035', 'N036', 'N037', 'N052', 'N053', 'N054', 'N055', 'N056', 'N057', 'N250', 'Z490', 'Z491', 'Z492', 'Z940', 'Z992'))) THEN 1 ELSE 0 END) AS renal_disease,

    -- [acute_myocardial_infarction]
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) = '410') OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('I21', 'I22')) THEN 1 ELSE 0 END) AS acute_myocardial_infarction,

    -- [stroke]
    MAX(CASE WHEN (di.icd_version = 9 AND SUBSTR(di.icd_code, 1, 3) IN ('430', '431', '432', '433', '434', '436')) OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN ('I60', 'I61', 'I62', 'I63')) THEN 1 ELSE 0 END) AS stroke,

    -- [cardiovascular_disease]
    --          ICD-10 I08, I20-I25, I42-I43, I46, I50, I70
    MAX(CASE
      WHEN (di.icd_version = 9 AND (
              SUBSTR(di.icd_code, 1, 3) IN ('396', '397',
                                            '410', '411', '412', '413', '414',
                                            '425',
                                            '428',
                                            '440')
           OR SUBSTR(di.icd_code, 1, 4) = '4275'))
        OR (di.icd_version = 10 AND SUBSTR(di.icd_code, 1, 3) IN (
              'I08',
              'I20', 'I21', 'I22', 'I23', 'I24', 'I25',
              'I42', 'I43',
              'I46',
              'I50',
              'I70'))
      THEN 1 ELSE 0 END) AS cardiovascular_disease

  FROM `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.diagnoses_icd` di
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.admissions` adm ON di.hadm_id = adm.hadm_id
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` icu ON adm.hadm_id = icu.hadm_id
  WHERE adm.admittime <= icu.intime
  GROUP BY di.hadm_id
),

-- hadm_id, cabg
cte_surgeries AS (
  SELECT
    pi.hadm_id,
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
    MAX(CASE WHEN (pi.icd_version=9  AND pi.icd_code = '3845')
              OR (pi.icd_version=10 AND pi.icd_code IN ('02RW0JZ','02RX08Z','02RX0JZ'))
      THEN 1 ELSE 0 END) AS aortic_surgery
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.procedures_icd` pi
  JOIN (
    SELECT hadm_id, MIN(intime) AS first_intime
    FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays`
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
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.blood_differential` bd
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON bd.hadm_id = i.hadm_id
  WHERE bd.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- stay_id, mech_vent_24h
cte_ventilation AS (
  SELECT v.stay_id, MAX(1) AS mech_vent_24h
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.ventilation` v
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON v.stay_id = i.stay_id
  WHERE v.ventilation_status IN ('InvasiveVent', 'NonInvasiveVent')
    AND v.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
    AND COALESCE(v.endtime, v.starttime) >= i.intime
  GROUP BY v.stay_id
),

-- stay_id, antibiotic_24h
cte_antibiotic AS (
  SELECT a.stay_id, MAX(1) AS antibiotic_24h
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.antibiotic` a
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON a.stay_id = i.stay_id
  WHERE a.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
    AND COALESCE(a.stoptime, a.starttime) >= i.intime
  GROUP BY a.stay_id
),

-- stay_id, aki_stage_24h
cte_aki AS (
  SELECT k.stay_id, MAX(k.aki_stage) AS aki_stage_24h
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.kdigo_stages` k
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON k.stay_id = i.stay_id
  WHERE k.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY k.stay_id
),

-- stay_id, sedation_use, use_of_midazolam
cte_sedation AS (
  SELECT 
    ie.stay_id,
    MAX(CASE WHEN ie.itemid IN (225150, 229420, 221668, 222168) THEN 1 ELSE 0 END) AS sedation_use, 
    MAX(CASE WHEN ie.itemid = 221668 THEN 1 ELSE 0 END) AS use_of_midazolam
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.inputevents` ie
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON ie.stay_id = i.stay_id
  WHERE ie.starttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY ie.stay_id
),

-- stay_id, vasopressor_use
cte_vasopressor AS (
  SELECT i.stay_id, MAX(1) AS vasopressor_use
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.norepinephrine_equivalent_dose` ne
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON ne.stay_id = i.stay_id
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
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.chartevents` ce ON i.stay_id = ce.stay_id
  WHERE ce.itemid IN (220621, 225664, 226537, 228388)
    AND ce.valuenum IS NOT NULL
    AND ce.valuenum BETWEEN 20 AND 2000
    AND ce.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
),

-- stay_id, mean_gluc, sd_gluc, max_gluc, min_gluc, total_hours
cte_glucose_stats AS (
  SELECT stay_id,
    AVG(glucose)    AS mean_gluc,
    STDDEV(glucose) AS sd_gluc,
    MAX(glucose)    AS max_gluc,
    MIN(glucose)    AS min_gluc,
    SUM(CASE WHEN diff_hours >= 0.5 THEN diff_hours END) AS total_hours
  FROM cte_raw_glucose GROUP BY stay_id
),

-- stay_id, lage, mage, gli, mbg, mag
--   Additional covariates MBG / MAG — Wang & Mei, Front Endocrinol 2024;15:1400207
cte_gluc_met AS (
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
cte_patient_height AS (
  SELECT subject_id, AVG(height_cm) AS height
  FROM (
    SELECT subject_id, valuenum AS height_cm FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.chartevents` WHERE itemid = 226730 AND valuenum > 0
    UNION ALL
    SELECT subject_id, valuenum * 2.54 AS height_cm FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.chartevents` WHERE itemid = 226707 AND valuenum > 0
    UNION ALL
    SELECT subject_id, SAFE_CAST(result_value AS FLOAT64) * 2.54 AS height_cm FROM `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.omr` WHERE result_name = 'Height (Inches)' AND SAFE_CAST(result_value AS FLOAT64) IS NOT NULL
  )
  WHERE height_cm BETWEEN 100 AND 250 GROUP BY subject_id
),

-- stay_id, weight
cte_stay_weight AS (
  SELECT ce.stay_id, AVG(ce.valuenum) AS weight
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.chartevents` ce
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON ce.stay_id = i.stay_id
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
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i ON sw.stay_id = i.stay_id
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.patients` p ON i.subject_id = p.subject_id
  LEFT JOIN cte_patient_height ph ON p.subject_id = ph.subject_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_lab` fdl ON sw.stay_id = fdl.stay_id
),

cte_age AS (
  SELECT hadm_id, LEAST(age, 90) AS age
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.age`
),

-- stay_id, egfr
cte_egfr AS (
  SELECT
    i.stay_id,
    CASE
      WHEN fdl.creatinine_max IS NULL OR ag.age IS NULL THEN NULL
      ELSE 
        142.0 
        * POWER(LEAST(fdl.creatinine_max / CASE WHEN p.gender = 'F' THEN 0.7 ELSE 0.9 END, 1.0), CASE WHEN p.gender = 'F' THEN -0.241 ELSE -0.302 END) 
        * POWER(GREATEST(fdl.creatinine_max / CASE WHEN p.gender = 'F' THEN 0.7 ELSE 0.9 END, 1.0), -1.200) 
        * POWER(0.9938, ag.age) 
        * CASE WHEN p.gender = 'F' THEN 1.012 ELSE 1.0 END
    END AS egfr
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.patients` p ON i.subject_id = p.subject_id
  LEFT JOIN cte_age ag ON i.hadm_id = ag.hadm_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_lab` fdl ON i.stay_id = fdl.stay_id
),

-- stay_id, avg_lymph, avg_mono, avg_neut
cte_bd_agg AS (
  SELECT i.stay_id, AVG(bd.lymphocytes_abs) AS avg_lymph, AVG(bd.monocytes_abs) AS avg_mono, AVG(bd.neutrophils_abs) AS avg_neut
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.blood_differential` bd ON i.hadm_id = bd.hadm_id AND bd.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

-- stay_id, avg_platelet
cte_cbc_agg AS (
  SELECT i.stay_id, AVG(cbc.platelet) AS avg_platelet
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.complete_blood_count` cbc ON i.hadm_id = cbc.hadm_id AND cbc.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
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
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_lab` fdl ON b.stay_id = fdl.stay_id
),

-- ==============================================================================
-- ==============================================================================

cte_rbc_indices AS (
  SELECT
    i.stay_id,
    MIN(cbc.mcv)  AS mcv_min,   MAX(cbc.mcv)  AS mcv_max,
    MIN(cbc.mch)  AS mch_min,   MAX(cbc.mch)  AS mch_max,
    MIN(cbc.mchc) AS mchc_min,  MAX(cbc.mchc) AS mchc_max,
    MIN(cbc.rdw)  AS rdw_min,   MAX(cbc.rdw)  AS rdw_max,
    MIN(cbc.rbc)  AS rbc_min,   MAX(cbc.rbc)  AS rbc_max
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.complete_blood_count` cbc
    ON i.hadm_id = cbc.hadm_id
   AND cbc.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

cte_mg_phos AS (
  SELECT
    i.stay_id,
    MIN(CASE WHEN le.itemid = 50960 THEN le.valuenum END) AS magnesium_min,
    MAX(CASE WHEN le.itemid = 50960 THEN le.valuenum END) AS magnesium_max,
    MIN(CASE WHEN le.itemid = 50970 THEN le.valuenum END) AS phosphate_min,
    MAX(CASE WHEN le.itemid = 50970 THEN le.valuenum END) AS phosphate_max
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.labevents` le
    ON i.hadm_id = le.hadm_id
   AND le.itemid IN (50960, 50970)
   AND le.valuenum IS NOT NULL
   AND le.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  GROUP BY i.stay_id
),

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
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.microbiologyevents` m
    ON i.hadm_id = m.hadm_id
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
cte_culture AS (
  SELECT DISTINCT i.stay_id
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.microbiologyevents` m
    ON i.hadm_id = m.hadm_id
   AND m.charttime BETWEEN i.intime AND TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
),

-- [statin_drugs]
cte_statin AS (
  SELECT i.stay_id,
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
      -- lovastatin, fluvastatin, pitavastatin, cerivastatin
      r'STATIN|ATORVA|SIMVA|ROSUVA|PRAVA|LOVA|FLUVA|PITAVA|CERIVA')
      THEN 1 ELSE 0 END) AS statin_drugs
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.prescriptions` pr
    ON i.hadm_id = pr.hadm_id
   AND pr.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
   AND COALESCE(pr.stoptime, pr.starttime) >= i.intime
  GROUP BY i.stay_id
),

-- ==============================================================================
-- ==============================================================================
--

cte_antimicrobial AS (
  SELECT
    i.stay_id,
    MAX(1) AS antimicrobial_any,
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
      r'ACYCLOVIR|VALACYCLOVIR|FAMCICLOVIR|GANCICLOVIR|VALGANCICLOVIR|FOSCARNET|CIDOFOVIR|OSELTAMIVIR|ZANAMIVIR|PERAMIVIR|RIMANTADINE|AMANTADINE|RIBAVIRIN|REMDESIVIR|LETERMOVIR|MARIBAVIR')
      THEN 1 ELSE 0 END) AS antiviral_use,
    MAX(CASE WHEN REGEXP_CONTAINS(UPPER(pr.drug),
      r'FLUCONAZOLE|ITRACONAZOLE|VORICONAZOLE|POSACONAZOLE|ISAVUCONAZ|KETOCONAZOLE|CASPOFUNGIN|MICAFUNGIN|ANIDULAFUNGIN|AMPHOTERICIN|FLUCYTOSINE|NYSTATIN|TERBINAFINE|GRISEOFULVIN')
      THEN 1 ELSE 0 END) AS antifungal_use
  FROM `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i
  JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.prescriptions` pr
    ON i.hadm_id = pr.hadm_id
   AND pr.starttime <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
   AND COALESCE(pr.stoptime, pr.starttime) >= i.intime
  WHERE COALESCE(pr.drug_type, '') != 'BASE'
    AND COALESCE(pr.route, '') NOT IN ('OU','OS','OD','AU','AS','AD','TP')
    AND LOWER(COALESCE(pr.route, '')) NOT LIKE '%ear%'
    AND LOWER(COALESCE(pr.route, '')) NOT LIKE '%eye%'
    AND LOWER(pr.drug) NOT LIKE '%cream%'
    AND LOWER(pr.drug) NOT LIKE '%ointment%'
    AND LOWER(pr.drug) NOT LIKE '%gel%'
    AND LOWER(pr.drug) NOT LIKE '%desensitization%'
    AND REGEXP_CONTAINS(UPPER(pr.drug), r'AMIKACIN|AMOXICILL|AMPICILLIN|AZITHROMYCIN|AZTREONAM|BACITRACIN|CEFAZOLIN|CEFEPIME|CEFOTAXIME|CEFOTETAN|CEFOXITIN|CEFPODOXIME|CEFTAROLINE|CEFTAZIDIME|CEFTRIAXONE|CEFUROXIME|CEFACLOR|CEFADROXIL|CEFDINIR|CEFDITOREN|CEFPROZIL|CEFTIBUTEN|CEPHALEXIN|CEPHALOTHIN|CHLORAMPHENICOL|CIPROFLOXACIN|CLARITHROMYCIN|CLINDAMYCIN|CLAVULANATE|COLISTIN|DALBAVANCIN|DAPTOMYCIN|DICLOXACILLIN|DORIPENEM|DOXYCY|ERTAPENEM|ERYTHROMYCIN|FIDAXOMICIN|FOSFOMYCIN|GENTAMICIN|IMIPENEM|KANAMYCIN|LEVOFLOXACIN|LINEZOLID|MEROPENEM|METHICILLIN|METRONIDAZOLE|MINOCYCLINE|MOXIFLOXACIN|MUPIROCIN|NAFCILLIN|NEOMYCIN|NITROFURANTOIN|NORFLOXACIN|OFLOXACIN|ORITAVANCIN|OXACILLIN|PENICILLIN|PIPERACILLIN|POLYMYXIN|QUINUPRISTIN|RIFAMPIN|RIFAXIMIN|STREPTOMYCIN|SULFADIAZINE|SULFAMETHOXAZOLE|SULFISOXAZOLE|TAZOBACTAM|TEDIZOLID|TELAVANCIN|TETRACYCLINE|TIGECYCLINE|TOBRAMYCIN|TRIMETHOPRIM|VANCOMYCIN|BACTRIM|SEPTRA|ZOSYN|UNASYN|AUGMENTIN|ZYVOX|CUBICIN|ROCEPHIN|MAXIPIME|FORTAZ|TAZICEF|INVANZ|PRIMAXIN|SYNERCID|FLUCONAZOLE|ITRACONAZOLE|VORICONAZOLE|POSACONAZOLE|ISAVUCONAZ|KETOCONAZOLE|CASPOFUNGIN|MICAFUNGIN|ANIDULAFUNGIN|AMPHOTERICIN|FLUCYTOSINE|NYSTATIN|TERBINAFINE|GRISEOFULVIN|ACYCLOVIR|VALACYCLOVIR|FAMCICLOVIR|GANCICLOVIR|VALGANCICLOVIR|FOSCARNET|CIDOFOVIR|OSELTAMIVIR|ZANAMIVIR|PERAMIVIR|RIMANTADINE|AMANTADINE|RIBAVIRIN|REMDESIVIR|LETERMOVIR|MARIBAVIR')
  GROUP BY i.stay_id
),

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
    d.first_delirium_time AS delirium_charttime,
    d.has_delirium_ever   AS delirium,
    adm.deathtime,
    i.intime,
    i.outtime,
    ag.age AS anchor_age,
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
    ch.charlson_comorbidity_index AS charlson_comorbidity_index,
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
    p.gender                     AS sex,
    idt.race                     AS ethnicity,
    adm.insurance                AS insurance,
    adm.marital_status           AS marital_status,
    CASE WHEN adm.admission_type IN ('ELECTIVE', 'SURGICAL SAME DAY ADMISSION') THEN 1 ELSE 0 END AS elective_surgery,

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

    fdl.potassium_min,   fdl.potassium_max,
    fdl.calcium_min,     fdl.calcium_max,
    fdl.chloride_min,    fdl.chloride_max,
    fdl.bicarbonate_min, fdl.bicarbonate_max,
    mgp.magnesium_min,   mgp.magnesium_max,
    mgp.phosphate_min,   mgp.phosphate_max,

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
    -- Derived metrics MBG / MAG (mg/dL, mg/dL/h)
    gluc_met.mbg AS mean_blood_glucose,
    gluc_met.mag AS mean_absolute_glucose,
    gnri_table.gnri,
    gnri_table.height, 
    gnri_table.weight,
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

  FROM `{{WORK_PROJECT}}.{{WORK_DATASET}}.{{COHORT_TABLE}}` d

  -- [2.1] MIMIC IV
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.patients` p      ON d.subject_id = p.subject_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_ICU_DATASET}}.icustays` i       ON d.stay_id = i.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.admissions` adm  ON d.hadm_id = adm.hadm_id

  -- [2.2] MIMIC IV Derived 
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_vitalsign` fdv   ON d.stay_id = fdv.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_lab` fdl         ON d.stay_id = fdl.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_bg_art` fdbg     ON d.stay_id = fdbg.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_urine_output` fduo ON d.stay_id = fduo.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_rrt` fdrrt       ON d.stay_id = fdrrt.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.apsiii` apsiii             ON d.stay_id = apsiii.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.lods` lods                 ON d.stay_id = lods.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.oasis` oasis               ON d.stay_id = oasis.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.sapsii` sapsii             ON d.stay_id = sapsii.stay_id
  --   (mimic-code sepsis3.sql: "the earliest time at which a patient had SOFA >= 2
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.sepsis3` sepsis
    ON d.stay_id = sepsis.stay_id
   AND sepsis.suspected_infection_time <= TIMESTAMP_ADD(i.intime, INTERVAL 24 HOUR)
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.sirs` sirs                 ON d.stay_id = sirs.stay_id

  -- [2.3] CTE Joins
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_sofa` fdsofa ON d.stay_id = fdsofa.stay_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.first_day_gcs`  fdgcs  ON d.stay_id = fdgcs.stay_id
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
  -- ===== Additional covariates =====
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.charlson` ch        ON d.hadm_id = ch.hadm_id
  LEFT JOIN cte_age ag                                             ON d.hadm_id = ag.hadm_id
  LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_DERIVED_DATASET}}.icustay_detail` idt ON d.stay_id = idt.stay_id
  LEFT JOIN cte_rbc_indices rbci          ON d.stay_id = rbci.stay_id
  LEFT JOIN cte_mg_phos     mgp           ON d.stay_id = mgp.stay_id
  LEFT JOIN cte_micro       mic           ON d.stay_id = mic.stay_id
  LEFT JOIN cte_culture     cu            ON d.stay_id = cu.stay_id
  LEFT JOIN cte_statin      st            ON d.stay_id = st.stay_id
  -- ===== Derived metrics =====
  LEFT JOIN cte_infection   inf           ON d.stay_id = inf.stay_id

)
