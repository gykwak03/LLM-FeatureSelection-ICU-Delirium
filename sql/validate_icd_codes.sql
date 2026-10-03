-- ICD-code validation template
--
-- Render this file with scripts/render_sql.py before running it in Google
-- BigQuery. It verifies that the declared ICD prefixes resolve in the selected
-- MIMIC-IV diagnosis dictionary. No patient-level result is distributed.

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
LEFT JOIN `{{MIMIC_PROJECT}}.{{MIMIC_HOSP_DATASET}}.d_icd_diagnoses` di
  ON di.icd_version = d.icd_version
 AND STARTS_WITH(di.icd_code, d.prefix)
GROUP BY d.variable, d.icd_version, d.prefix
ORDER BY n_codes ASC, d.variable, d.icd_version, d.prefix;
