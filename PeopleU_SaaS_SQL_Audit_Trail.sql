-- ============================================================
-- PEOPLEU B2B SAAS
-- MARKETING ACQUISITION STRATEGY
-- SQL AUDIT TRAIL
-- ============================================================

-- 01. DATA FOUNDATION
Query 1 — Schema Discovery
#DATA CLEANSING
#1.Contract table
#ensure column contain with string no over space in text
#ensure there is no data null
#delete duplicate data based on contract_id

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract_clean` AS
WITH ranked_contracts AS (
  SELECT *,
         ROW_NUMBER() OVER(PARTITION BY contract_id ORDER BY date DESC) as rn
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract`
)
SELECT 
  contract_id,
  leads_id,
  date,
  TRIM(subscription_type) AS subscription_type,
  number_of_employee,
  reten_flag,
  user_price,
  GMV
FROM ranked_contracts
WHERE rn = 1 AND contract_id IS NOT NULL;

#2. discount_type table
#ensure column contain with string no over space in text
#ensure there is no data null

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.discount_type_clean` AS
SELECT 
  TRIM(discount_type_code) AS discount_type_code,
  INITCAP(REPLACE(discount_type, '_', ' ')) AS discount_type, -- Mengubah menjadi '2021 Quarter Discount'
  LOWER(TRIM(month_discount)) AS month_discount
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.discount_type`
WHERE discount_type_code IS NOT NULL;

#3. discount table
#ensure column contain with string no over space in text
#ensure there is no data null
#delete duplicate data based on contract_id and discount_type_code

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.discounts_clean` AS
WITH deduplicated AS (
  SELECT *,
         ROW_NUMBER() OVER(PARTITION BY contract_id, discount_type_code ORDER BY deal_won DESC) as rn
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.discounts`
)
SELECT 
  contract_id,
  TRIM(discount_type_code) AS discount_type_code,
  deal_won,
  user_price_after,
  reten_flag
FROM deduplicated
WHERE rn = 1 AND contract_id IS NOT NULL;

#4. Funnel table
#ensure column contain with string no over space in text
#ensure there is no data null
#delete duplicate data based on funnel_id

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.funnel_clean` AS
SELECT 
  funnel_id,
  leads_id,
  stage_id,
  TimeStamp,
  CASE 
    WHEN TRIM(LOWER(reason)) = 'null' OR TRIM(reason) = '' THEN NULL 
    ELSE TRIM(reason) 
  END AS reason
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.funnel`
WHERE funnel_id IS NOT NULL;

#4. google analytic table
#ensure column contain with string no over space and typo in text
#ensure there is no data null
#delete duplicate data based on ga_id

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.google_analytics_clean` AS
WITH ga_dedup AS (
  SELECT *,
         ROW_NUMBER() OVER(PARTITION BY ga_id ORDER BY Page_timestamp DESC) as rn
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.google_analytics`
)
SELECT 
  leads_id,
  ga_id,
  LOWER(TRIM(Page_Name)) AS Page_Name,
  Page_timestamp
FROM ga_dedup
WHERE rn = 1 AND ga_id IS NOT NULL;

#5. industries table
#ensure column contain with string no over space and typo in text

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source_clean` AS
SELECT 
  session_source_code,
  CASE 
    WHEN TRIM(session_source) = 'Refferal' THEN 'Referral'
    ELSE TRIM(session_source)
  END AS session_source
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source`
WHERE session_source_code IS NOT NULL;

#6. stage table
#ensure column contain with string no over space and typo in text

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.stage_clean` AS
SELECT 
  stage_id,
  CASE 
    WHEN TRIM(stage) = 'quotation_recieved' THEN 'quotation_received'
    ELSE TRIM(stage)
  END AS stage
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.stage`
WHERE stage_id IS NOT NULL;

#7. industries & leads table
#ensure column contain with string no over space
CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries_clean` AS
SELECT industry_code, TRIM(industry) AS industry 
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` WHERE industry_code IS NOT NULL;

CREATE OR REPLACE TABLE `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads_clean` AS
SELECT DISTINCT leads_id, session_source_code, industry_code, leads_registered, number_of_employee 
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` WHERE leads_id IS NOT NULL;

-- 02. EXECUTIVE KPI BASELINE
#EXECUTIVE BASELINE KPI landscape display
SELECT
  -- Customer Base
  COUNT(*) AS total_customers,

  -- Renewal & Churn
  COUNTIF(renewed = 1) AS renewed_customers,
  COUNTIF(renewed = 0) AS churned_customers,
  ROUND(
    SAFE_DIVIDE(COUNTIF(renewed = 1), COUNT(*)) * 100,
    2
  ) AS renewal_rate_pct,
  ROUND(
    SAFE_DIVIDE(COUNTIF(renewed = 0), COUNT(*)) * 100,
    2
  ) AS churn_rate_pct,

  -- Lifecycle Movement
  COUNTIF(lifecycle_movement = 'Retained') AS retained_customers,
  COUNTIF(lifecycle_movement = 'Upgrade') AS upgraded_customers,
  ROUND(
    SAFE_DIVIDE(
      COUNTIF(lifecycle_movement = 'Retained'),
      COUNT(*)
    ) * 100,
    2
  ) AS retention_rate_pct,
  ROUND(
    SAFE_DIVIDE(
      COUNTIF(lifecycle_movement = 'Upgrade'),
      COUNT(*)
    ) * 100,
    2
  ) AS upgrade_rate_pct,

  -- GMV
  ROUND(SUM(first_gmv), 2) AS total_initial_gmv,
  ROUND(SUM(renewal_gmv), 2) AS total_renewal_gmv,

  -- GMV Retention
  ROUND(
    SAFE_DIVIDE(
      SUM(renewal_gmv),
      SUM(first_gmv)
    ) * 100,
    2
  ) AS gmv_retention_rate_pct,

  -- GMV Change
  ROUND(SUM(gmv_change), 2) AS total_gmv_change,

  -- Customer Value
  ROUND(AVG(first_gmv), 2) AS avg_initial_gmv,
  ROUND(AVG(renewal_gmv), 2) AS avg_renewal_gmv

FROM
  `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`;

-- 03. LEAD-CONTRACT INTEGRITY


-- 04. COHORT / RETENTION
-- ============================================================
-- SQL #20B
-- MONTHLY CONTRACT-BASED COHORT RETENTION
--
-- Purpose:
-- Measure customer contract activity/renewal by months
-- since the customer's first contract month
-- ============================================================

WITH customer_cohort AS (

  -- Determine each customer's first contract month
  SELECT
    leads_id,
    DATE_TRUNC(MIN(date), MONTH) AS cohort_month
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract`
  GROUP BY leads_id

),

customer_activity AS (

  -- One customer counted once per activity month
  SELECT DISTINCT
    leads_id,
    DATE_TRUNC(date, MONTH) AS activity_month
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract`

),

cohort_activity AS (

  SELECT
    cc.cohort_month,
    ca.activity_month,

    DATE_DIFF(
      ca.activity_month,
      cc.cohort_month,
      MONTH
    ) AS months_since_cohort,

    ca.leads_id

  FROM customer_cohort cc
  INNER JOIN customer_activity ca
    ON cc.leads_id = ca.leads_id

),

cohort_size AS (

  SELECT
    cohort_month,
    COUNT(DISTINCT leads_id) AS cohort_customers
  FROM customer_cohort
  GROUP BY cohort_month

)

SELECT
  ca.cohort_month,
  ca.months_since_cohort,

  cs.cohort_customers,

  COUNT(DISTINCT ca.leads_id) AS active_customers,

  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT ca.leads_id),
      cs.cohort_customers
    ) * 100,
    2
  ) AS retention_rate_pct

FROM cohort_activity ca

INNER JOIN cohort_size cs
  ON ca.cohort_month = cs.cohort_month

GROUP BY
  ca.cohort_month,
  ca.months_since_cohort,
  cs.cohort_customers

ORDER BY
  ca.cohort_month,
  ca.months_since_cohort;

-- =========================================================
-- SQL #20C — Cohort Quality × Customer Retention × GMV Quality
-- =========================================================

WITH cohort_base AS (
  SELECT
    DATE_TRUNC(first_contract_date, MONTH) AS cohort_month,
    renewed,
    first_gmv,
    renewal_gmv
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
)

SELECT
  cohort_month,

  -- =======================================================
  -- 1. COHORT SIZE
  -- =======================================================
  COUNT(*) AS cohort_customers,

  -- =======================================================
  -- 2. CUSTOMER RETENTION QUALITY
  -- =======================================================
  COUNTIF(renewed = 1) AS renewed_customers,
  COUNTIF(renewed = 0) AS churned_customers,

  ROUND(
    SAFE_DIVIDE(
      COUNTIF(renewed = 1),
      COUNT(*)
    ) * 100,
    2
  ) AS customer_retention_pct,

  -- =======================================================
  -- 3. GMV / REVENUE QUALITY
  -- =======================================================
  SUM(first_gmv) AS total_initial_gmv,

  SUM(
    CASE
      WHEN renewed = 1 THEN renewal_gmv
      ELSE 0
    END
  ) AS total_renewal_gmv,

  -- =======================================================
  -- GMV RETENTION
  -- =======================================================
  ROUND(
    SAFE_DIVIDE(
      SUM(
        CASE
          WHEN renewed = 1 THEN renewal_gmv
          ELSE 0
        END
      ),
      SUM(first_gmv)
    ) * 100,
    2
  ) AS gmv_retention_pct,

  -- =======================================================
  -- GMV CHANGE
  -- =======================================================
  SUM(
    CASE
      WHEN renewed = 1 THEN renewal_gmv
      ELSE 0
    END
  ) - SUM(first_gmv) AS total_gmv_change,

  ROUND(
    SAFE_DIVIDE(
      SUM(
        CASE
          WHEN renewed = 1 THEN renewal_gmv
          ELSE 0
        END
      ) - SUM(first_gmv),
      SUM(first_gmv)
    ) * 100,
    2
  ) AS gmv_change_pct

FROM cohort_base

GROUP BY cohort_month

ORDER BY cohort_month;

-- ============================================================
-- SQL #20D — Cohort Seasonality Analysis by First Contract Month
-- Objective:
-- Identify whether the MONTH of first customer acquisition
-- shows recurring patterns in:
-- 1. Customer acquisition volume
-- 2. Customer retention
-- 3. GMV retention / revenue quality
-- ============================================================

WITH cohort_base AS (
  SELECT 
    -- PERBAIKAN 1: Mengubah cohort_month menjadi potongan bulan dari first_contract_date
    DATE_TRUNC(first_contract_date, MONTH) AS cohort_month,
    
    -- Extract month number and month name
    EXTRACT(MONTH FROM first_contract_date) AS cohort_month_number,
    FORMAT_DATE('%B', first_contract_date) AS cohort_month_name,
    
    -- Customer Metrics
    COUNT(*) AS cohort_customers,
    COUNTIF(renewed = 1) AS renewed_customers,
    COUNTIF(renewed = 0) AS churned_customers,
    
    -- Customer Retention
    ROUND(
      SAFE_DIVIDE(COUNTIF(renewed = 1), COUNT(*)) * 100, 
      2
    ) AS customer_retention_pct,
    
    -- GMV Metrics (PERBAIKAN 2: Mengubah nama kolom initial_gmv menjadi first_gmv)
    SUM(first_gmv) AS total_initial_gmv,
    SUM(renewal_gmv) AS total_renewal_gmv,
    
    -- GMV Retention
    ROUND(
      SAFE_DIVIDE(SUM(renewal_gmv), SUM(first_gmv)) * 100, 
      2
    ) AS gmv_retention_pct,
    
    -- GMV Change
    SUM(renewal_gmv) - SUM(first_gmv) AS total_gmv_change,
    ROUND(
      SAFE_DIVIDE(SUM(renewal_gmv) - SUM(first_gmv), SUM(first_gmv)) * 100, 
      2
    ) AS gmv_change_pct
    
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
  
  -- PERBAIKAN 3: Menyesuaikan komponen GROUP BY berdasarkan kolom hasil kalkulasi di atas
  GROUP BY 
    cohort_month,
    cohort_month_number,
    cohort_month_name
), 
seasonality_summary AS (
  SELECT 
    cohort_month_number, 
    cohort_month_name, 
    -- Number of yearly cohorts represented
    COUNT(*) AS number_of_cohorts, 
    -- ========================================================
    -- Acquisition Seasonality
    -- ========================================================
    SUM(cohort_customers) AS total_acquired_customers, 
    ROUND(AVG(cohort_customers), 2) AS avg_customers_per_cohort, 
    -- ========================================================
    -- Customer Retention Seasonality (Weighted calculation)
    -- ========================================================
    SUM(renewed_customers) AS total_renewed_customers, 
    SUM(churned_customers) AS total_churned_customers, 
    ROUND(
      SAFE_DIVIDE(SUM(renewed_customers), SUM(cohort_customers)) * 100, 
      2
    ) AS weighted_customer_retention_pct, 
    -- ========================================================
    -- GMV Seasonality (Ditambahkan ROUND desimal agar konsisten rapi)
    -- ========================================================
    ROUND(SUM(total_initial_gmv), 2) AS total_initial_gmv, 
    ROUND(SUM(total_renewal_gmv), 2) AS total_renewal_gmv, 
    ROUND(
      SAFE_DIVIDE(SUM(total_renewal_gmv), SUM(total_initial_gmv)) * 100, 
      2
    ) AS weighted_gmv_retention_pct, 
    ROUND(SUM(total_gmv_change), 2) AS total_gmv_change, 
    ROUND(
      SAFE_DIVIDE(SUM(total_gmv_change), SUM(total_initial_gmv)) * 100, 
      2
    ) AS weighted_gmv_change_pct 
  FROM cohort_base 
  GROUP BY 
    cohort_month_number, 
    cohort_month_name
) 
SELECT 
  cohort_month_number, 
  cohort_month_name, 
  number_of_cohorts, 
  -- Acquisition
  total_acquired_customers, 
  avg_customers_per_cohort, 
  -- Customer Quality
  total_renewed_customers, 
  total_churned_customers, 
  weighted_customer_retention_pct, 
  -- GMV Quality
  total_initial_gmv, 
  total_renewal_gmv, 
  weighted_gmv_retention_pct, 
  total_gmv_change, 
  weighted_gmv_change_pct 
FROM seasonality_summary 
ORDER BY cohort_month_number;

-- 05. QUALIFIED LEAD FOUNDATION
-- =========================================================
-- SQL A0 — QUALIFIED LEAD FOUNDATION AUDIT
-- Purpose:
-- Validate the Lead → Contract funnel before lead segmentation
-- =========================================================

WITH lead_base AS (
    SELECT
        leads_id
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads`
),

contract_base AS (
    SELECT
        leads_id,
        COUNT(*) AS contract_count
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract`
    GROUP BY leads_id
),

lead_contract_status AS (
    SELECT
        l.leads_id,

        CASE
            WHEN c.leads_id IS NOT NULL THEN 1
            ELSE 0
        END AS has_contract,

        COALESCE(c.contract_count, 0) AS contract_count

    FROM lead_base l
    LEFT JOIN contract_base c
        ON l.leads_id = c.leads_id
),

contract_matching_audit AS (
    SELECT
        COUNT(*) AS total_contract_rows,

        COUNT(DISTINCT c.leads_id) AS unique_contracted_leads,

        COUNTIF(l.leads_id IS NULL) AS contracts_without_matching_lead

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract` c
    LEFT JOIN lead_base l
        ON c.leads_id = l.leads_id
)

SELECT

    -- Lead Population
    COUNT(DISTINCT leads_id) AS total_unique_leads,

    -- Conversion
    COUNTIF(has_contract = 1) AS contracted_leads,

    COUNTIF(has_contract = 0) AS leads_without_contract,

    ROUND(
        SAFE_DIVIDE(
            COUNTIF(has_contract = 1),
            COUNT(DISTINCT leads_id)
        ) * 100,
        2
    ) AS lead_to_contract_rate_pct,

    -- Contract Relationship
    COUNTIF(contract_count > 1) AS leads_with_multiple_contracts,

    MAX(contract_count) AS max_contracts_per_lead,

    -- Contract Matching Validation
    (
        SELECT total_contract_rows
        FROM contract_matching_audit
    ) AS total_contract_rows,

    (
        SELECT unique_contracted_leads
        FROM contract_matching_audit
    ) AS unique_contracted_leads,

    (
        SELECT contracts_without_matching_lead
        FROM contract_matching_audit
    ) AS contracts_without_matching_lead

FROM lead_contract_status;


-- 06. LEAD-LEVEL MASTER
-- ============================================================
-- SQL B — BUILD LEAD-LEVEL QUALIFIED LEAD MASTER
-- Objective:
-- Create 1 row = 1 leads_id as the Single Source of Truth
-- for Qualified Lead and Marketing Strategy Analysis
-- ============================================================

WITH lead_base AS (
  -- --------------------------------------------------------
  -- 1. Lead Universe
  -- Grain: 1 row = 1 leads_id
  -- PERBAIKAN: Menambahkan JOIN ke tabel master untuk mengambil teks session, industry, & segmen
  -- --------------------------------------------------------
  SELECT DISTINCT 
    l.leads_id, 
    s.session_source, 
    CASE 
      WHEN l.number_of_employee <= 10 THEN '01. 1-10' 
      WHEN l.number_of_employee <= 50 THEN '02. 11-50' 
      WHEN l.number_of_employee <= 100 THEN '03. 51-100' 
      WHEN l.number_of_employee <= 250 THEN '04. 101-250' 
      ELSE '05. 251+' 
    END AS employee_segment, 
    i.industry
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` l
  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` s 
    ON l.session_source_code = s.session_source_code
  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` i 
    ON l.industry_code = i.industry_code
), 

contract_base AS (
  -- --------------------------------------------------------
  -- 2. Aggregate Contract BEFORE joining to Leads
  -- Grain: 1 row = 1 leads_id
  -- --------------------------------------------------------
  SELECT 
    leads_id, 
    COUNT(*) AS contract_row_count, 
    COUNT(DISTINCT contract_id) AS unique_contract_count, 
    MIN(date) AS first_contract_date, -- Catatan: Jika kolom aslinya 'date', gunakan date
    MAX(date) AS latest_contract_date
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.contract`
  GROUP BY leads_id
), 

customer_360 AS (
  -- --------------------------------------------------------
  -- 3. Customer 360
  -- Already validated as: 1 row = 1 leads_id
  -- --------------------------------------------------------
  SELECT 
    leads_id, 
    first_contract_date, 
    first_subscription, 
    first_gmv, 
    first_user_price, 
    renewed, 
    renewal_date, 
    renewal_subscription, 
    renewal_gmv, 
    renewal_user_price, 
    price_change, 
    lifecycle_movement, 
    gmv_change, 
    gmv_change_pct, 
    days_to_renewal, -- PERBAIKAN: Mengubah days_to_renew menjadi days_to_renewal sesuai isi tabel 360 Anda
    total_observed_gmv 
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
)

-- ============================================================
-- 4. FINAL LEAD-LEVEL MASTER
-- Final Grain: EXACTLY 1 ROW = 1 leads_id
-- ============================================================
SELECT
  -- --------------------------------------------------------
  -- A. Lead Identity
  -- --------------------------------------------------------
  l.leads_id, 
  -- --------------------------------------------------------
  -- B. Acquisition & Lead Characteristics
  -- --------------------------------------------------------
  l.session_source, 
  l.employee_segment, 
  l.industry, 
  -- --------------------------------------------------------
  -- C. Conversion / Funnel Status
  -- --------------------------------------------------------
  CASE WHEN c.leads_id IS NOT NULL THEN 1 ELSE 0 END AS has_contract, 
  CASE WHEN c.leads_id IS NOT NULL THEN 'Converted' ELSE 'Not Converted' END AS lead_status, 
  COALESCE(c.contract_row_count, 0) AS contract_row_count, 
  COALESCE(c.unique_contract_count, 0) AS unique_contract_count, 
  -- --------------------------------------------------------
  -- D. Contract Timing
  -- --------------------------------------------------------
  COALESCE(c.first_contract_date, cs.first_contract_date) AS first_contract_date, 
  c.latest_contract_date, 
  -- --------------------------------------------------------
  -- E. Initial Customer / Economic Profile
  -- --------------------------------------------------------
  cs.first_subscription, 
  cs.first_gmv, 
  cs.first_user_price, 
  -- --------------------------------------------------------
  -- F. Renewal & Retention Quality
  -- --------------------------------------------------------
  cs.renewed, 
  cs.renewal_date, 
  cs.renewal_subscription, 
  cs.renewal_gmv, 
  cs.renewal_user_price, 
  cs.days_to_renewal AS days_to_renew, -- Disesuaikan aliasnya agar aman ke seleksi akhir
  -- --------------------------------------------------------
  -- G. Economic Development
  -- --------------------------------------------------------
  cs.price_change, 
  cs.lifecycle_movement, 
  cs.gmv_change, 
  cs.gmv_change_pct, 
  cs.total_observed_gmv, 
  -- --------------------------------------------------------
  -- H. Future Qualified Lead Flags
  -- --------------------------------------------------------
  CASE WHEN c.leads_id IS NOT NULL THEN 1 ELSE 0 END AS converted_lead_flag, 
  CASE WHEN cs.renewed = 1 THEN 1 ELSE 0 END AS renewed_customer_flag, 
  -- --------------------------------------------------------
  -- I. Data Completeness
  -- --------------------------------------------------------
  CASE WHEN l.session_source IS NULL THEN 1 ELSE 0 END AS missing_session_source_flag, 
  CASE WHEN l.employee_segment IS NULL THEN 1 ELSE 0 END AS missing_employee_segment_flag, 
  CASE WHEN l.industry IS NULL THEN 1 ELSE 0 END AS missing_industry_flag 
FROM lead_base l 
LEFT JOIN contract_base c ON l.leads_id = c.leads_id 
LEFT JOIN customer_360 cs ON l.leads_id = cs.leads_id 
ORDER BY l.leads_id;

-- 07. QUALIFIED LEAD SCORING
-- ============================================================
-- SQL E — QUALIFIED LEAD SCORING & SEGMENTATION
--
-- Objective:
-- Create an objective definition of Qualified Leads based on:
-- 1. Conversion Quality
-- 2. Initial Economic Quality
-- 3. Lifecycle Economic Quality
-- 4. Retention Quality
--
-- Unit of analysis:
-- Employee Segment × Industry
--
-- Grain before aggregation = 1 row per leads_id
-- ============================================================

WITH lead_base AS (
  SELECT DISTINCT 
    l.leads_id, 
    CASE 
      WHEN l.number_of_employee <= 10 THEN '01. 1-10' 
      WHEN l.number_of_employee <= 50 THEN '02. 11-50' 
      WHEN l.number_of_employee <= 100 THEN '03. 51-100' 
      WHEN l.number_of_employee <= 250 THEN '04. 101-250' 
      ELSE '05. 251+' 
    END AS employee_segment, 
    i.industry
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l
  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` i 
    ON l.industry_code = i.industry_code
), 

customer_summary AS (
  SELECT 
    leads_id, 
    first_gmv, 
    total_observed_gmv AS lifecycle_gmv, 
    renewed AS renewed_flag 
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
), 

lead_level AS (
  SELECT 
    l.leads_id, 
    l.employee_segment, 
    l.industry, 
    CASE WHEN c.leads_id IS NOT NULL THEN 1 ELSE 0 END AS converted_flag, 
    COALESCE(c.first_gmv, 0) AS initial_gmv, 
    COALESCE(c.lifecycle_gmv, 0) AS lifecycle_gmv, 
    COALESCE(c.renewed_flag, 0) AS renewed_flag 
  FROM lead_base AS l 
  LEFT JOIN customer_summary AS c ON l.leads_id = c.leads_id
), 

segment_metrics AS (
  SELECT 
    employee_segment, 
    industry, 
    COUNT(*) AS total_leads, 
    SUM(converted_flag) AS converted_leads, 
    ROUND( 100 * SAFE_DIVIDE( SUM(converted_flag), COUNT(*) ), 2 ) AS conversion_rate_pct, 
    ROUND( SAFE_DIVIDE( SUM(initial_gmv), COUNT(*) ), 2 ) AS initial_gmv_per_lead, 
    ROUND( SAFE_DIVIDE( SUM(lifecycle_gmv), COUNT(*) ), 2 ) AS lifecycle_gmv_per_lead, 
    ROUND( 100 * SAFE_DIVIDE( SUM(renewed_flag), SUM(converted_flag) ), 2 ) AS renewal_rate_pct 
  FROM lead_level 
  GROUP BY employee_segment, industry
), 

scored_segments AS (
  SELECT *, 
    ROUND( 100 * PERCENT_RANK() OVER ( ORDER BY conversion_rate_pct ), 2 ) AS conversion_score, 
    ROUND( 100 * PERCENT_RANK() OVER ( ORDER BY initial_gmv_per_lead ), 2 ) AS initial_value_score, 
    ROUND( 100 * PERCENT_RANK() OVER ( ORDER BY lifecycle_gmv_per_lead ), 2 ) AS lifecycle_value_score, 
    ROUND( 100 * PERCENT_RANK() OVER ( ORDER BY renewal_rate_pct ), 2 ) AS retention_score 
  FROM segment_metrics
), 

-- PERBAIKAN UTAMA: Mengubah nama CTE dari qualified_lead_score menjadi final_scored_data
final_scored_data AS (
  SELECT *, 
    ROUND( conversion_score * 0.25 + initial_value_score * 0.25 + lifecycle_value_score * 0.30 + retention_score * 0.20, 2 ) AS qualified_lead_score 
  FROM scored_segments
) 

-- ============================================================
-- FINAL OUTPUT
-- ============================================================
SELECT 
  employee_segment, 
  industry, 
  total_leads, 
  converted_leads, 
  conversion_rate_pct, 
  initial_gmv_per_lead, 
  lifecycle_gmv_per_lead, 
  renewal_rate_pct, 
  conversion_score, 
  initial_value_score, 
  lifecycle_value_score, 
  retention_score, 
  qualified_lead_score, 
  
  -- Sekarang fungsi perbandingan di bawah ini dijamin aman dan terbaca sebagai kolom angka biasa
  CASE 
    WHEN total_leads >= 30 AND qualified_lead_score >= 75 THEN 'Tier 1 - High Priority' 
    WHEN total_leads >= 20 AND qualified_lead_score >= 55 THEN 'Tier 2 - Growth Opportunity' 
    WHEN qualified_lead_score >= 40 THEN 'Tier 3 - Monitor' 
    ELSE 'Tier 4 - Low Priority' 
  END AS qualified_lead_tier, 
  
  CASE 
    WHEN total_leads < 20 THEN 'Small Sample - Validate Before Scaling' 
    WHEN conversion_score >= 60 AND lifecycle_value_score >= 60 AND retention_score >= 60 THEN 'High-Quality Scalable Segment' 
    WHEN conversion_score < 40 AND lifecycle_value_score >= 60 THEN 'High Value but Conversion Challenge' 
    WHEN conversion_score >= 60 AND lifecycle_value_score < 40 THEN 'Easy Conversion but Lower Economic Value' 
    WHEN conversion_score < 40 AND lifecycle_value_score < 40 THEN 'Low Conversion and Low Value' 
    ELSE 'Mixed Performance - Optimize Selectively' 
  END AS strategic_interpretation 
FROM final_scored_data 
ORDER BY 
  CASE WHEN total_leads >= 30 THEN 1 ELSE 2 END, 
  qualified_lead_score DESC;


-- ============================================================
-- SQL F-3 — CONFIDENCE-ADJUSTED / EVIDENCE-STRENGTH VALIDATION
-- ============================================================
-- Business Objective:
-- Validate whether high-quality lead segments are supported
-- by sufficient evidence before making marketing decisions.
--
-- Grain:
-- 1 row = 1 leads_id
-- ============================================================

WITH lead_base AS (
  SELECT DISTINCT
    l.leads_id,
    
    CASE
      WHEN l.number_of_employee <= 10 THEN '01. 1-10'
      WHEN l.number_of_employee <= 50 THEN '02. 11-50'
      WHEN l.number_of_employee <= 100 THEN '03. 51-100'
      WHEN l.number_of_employee <= 250 THEN '04. 101-250'
      ELSE '05. 251+'
    END AS employee_segment,
    
    i.industry
    
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l
  
  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` AS i
    ON l.industry_code = i.industry_code
),

customer_summary AS (
  SELECT
    leads_id,
    contract_count,
    first_gmv,
    renewal_gmv,
    total_observed_gmv AS lifecycle_gmv,
    renewed
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),

lead_level AS (
  SELECT
    l.leads_id,
    l.employee_segment,
    l.industry,
    
    CASE
      WHEN c.leads_id IS NOT NULL THEN 1
      ELSE 0
    END AS converted_flag,
    
    COALESCE(c.first_gmv, 0) AS first_gmv,
    COALESCE(c.lifecycle_gmv, 0) AS lifecycle_gmv,
    COALESCE(c.renewed, 0) AS renewed_flag
    
  FROM lead_base AS l
  
  LEFT JOIN customer_summary AS c
    ON l.leads_id = c.leads_id
),

-- ============================================================
-- 1. SEGMENT RAW PERFORMANCE
-- ============================================================

segment_performance AS (
  SELECT
    employee_segment,
    industry,
    
    COUNT(*) AS total_leads,
    SUM(converted_flag) AS contracted_leads,
    
    SAFE_DIVIDE(
      SUM(converted_flag),
      COUNT(*)
    ) AS raw_conversion_rate,
    
    SAFE_DIVIDE(
      SUM(first_gmv),
      COUNT(*)
    ) AS raw_initial_gmv_per_lead,
    
    SAFE_DIVIDE(
      SUM(lifecycle_gmv),
      COUNT(*)
    ) AS raw_lifecycle_gmv_per_lead,
    
    SAFE_DIVIDE(
      SUM(renewed_flag),
      SUM(converted_flag)
    ) AS raw_renewal_rate
    
  FROM lead_level
  
  GROUP BY
    employee_segment,
    industry
),

-- ============================================================
-- 2. OVERALL BASELINE
-- Used as the population benchmark for shrinkage
-- ============================================================

overall_baseline AS (
  SELECT
    COUNT(*) AS overall_leads,
    
    SAFE_DIVIDE(
      SUM(converted_flag),
      COUNT(*)
    ) AS overall_conversion_rate,
    
    SAFE_DIVIDE(
      SUM(first_gmv),
      COUNT(*)
    ) AS overall_initial_gmv_per_lead,
    
    SAFE_DIVIDE(
      SUM(lifecycle_gmv),
      COUNT(*)
    ) AS overall_lifecycle_gmv_per_lead,
    
    SAFE_DIVIDE(
      SUM(renewed_flag),
      SUM(converted_flag)
    ) AS overall_renewal_rate
    
  FROM lead_level
),

-- ============================================================
-- 3. CONFIDENCE-ADJUSTED PERFORMANCE
--
-- k = 30
-- Segments with small sample sizes are partially shrunk
-- toward the overall baseline.
--
-- Weight = total_leads / (total_leads + 30)
-- ============================================================

confidence_adjusted AS (
  SELECT
    s.*,
    
    b.overall_conversion_rate,
    b.overall_initial_gmv_per_lead,
    b.overall_lifecycle_gmv_per_lead,
    b.overall_renewal_rate,
    
    ROUND(
      SAFE_DIVIDE(
        s.total_leads,
        s.total_leads + 30
      ),
      4
    ) AS evidence_weight,
    
    -- Conversion adjusted by evidence strength
    (
      SAFE_DIVIDE(
        s.total_leads,
        s.total_leads + 30
      ) * s.raw_conversion_rate
    )
    +
    (
      SAFE_DIVIDE(
        30,
        s.total_leads + 30
      ) * b.overall_conversion_rate
    ) AS adjusted_conversion_rate,
    
    -- Initial GMV per Lead adjusted by evidence strength
    (
      SAFE_DIVIDE(
        s.total_leads,
        s.total_leads + 30
      ) * s.raw_initial_gmv_per_lead
    )
    +
    (
      SAFE_DIVIDE(
        30,
        s.total_leads + 30
      ) * b.overall_initial_gmv_per_lead
    ) AS adjusted_initial_gmv_per_lead,
    
    -- Lifecycle GMV per Lead adjusted by evidence strength
    (
      SAFE_DIVIDE(
        s.total_leads,
        s.total_leads + 30
      ) * s.raw_lifecycle_gmv_per_lead
    )
    +
    (
      SAFE_DIVIDE(
        30,
        s.total_leads + 30
      ) * b.overall_lifecycle_gmv_per_lead
    ) AS adjusted_lifecycle_gmv_per_lead,
    
    -- Renewal adjusted separately
    -- still treated as a secondary quality indicator
    (
      SAFE_DIVIDE(
        s.total_leads,
        s.total_leads + 30
      ) * s.raw_renewal_rate
    )
    +
    (
      SAFE_DIVIDE(
        30,
        s.total_leads + 30
      ) * b.overall_renewal_rate
    ) AS adjusted_renewal_rate
    
  FROM segment_performance AS s
  CROSS JOIN overall_baseline AS b
),

-- ============================================================
-- 4. NORMALIZE ADJUSTED METRICS
-- ============================================================

score_range AS (
  SELECT
    *,
    
    MIN(adjusted_conversion_rate) OVER () AS min_conversion,
    MAX(adjusted_conversion_rate) OVER () AS max_conversion,
    
    MIN(adjusted_initial_gmv_per_lead) OVER () AS min_initial_value,
    MAX(adjusted_initial_gmv_per_lead) OVER () AS max_initial_value,
    
    MIN(adjusted_lifecycle_gmv_per_lead) OVER () AS min_lifecycle_value,
    MAX(adjusted_lifecycle_gmv_per_lead) OVER () AS max_lifecycle_value,
    
    MIN(adjusted_renewal_rate) OVER () AS min_renewal,
    MAX(adjusted_renewal_rate) OVER () AS max_renewal
    
  FROM confidence_adjusted
),

-- ============================================================
-- 5. CONFIDENCE-ADJUSTED QUALIFIED LEAD SCORE
-- ============================================================

final_scoring AS (
  SELECT
    *,
    
    ROUND(
      100 * SAFE_DIVIDE(
        adjusted_conversion_rate - min_conversion,
        max_conversion - min_conversion
      ),
      2
    ) AS adjusted_conversion_score,
    
    ROUND(
      100 * SAFE_DIVIDE(
        adjusted_initial_gmv_per_lead - min_initial_value,
        max_initial_value - min_initial_value
      ),
      2
    ) AS adjusted_initial_value_score,
    
    ROUND(
      100 * SAFE_DIVIDE(
        adjusted_lifecycle_gmv_per_lead - min_lifecycle_value,
        max_lifecycle_value - min_lifecycle_value
      ),
      2
    ) AS adjusted_lifecycle_score,
    
    ROUND(
      100 * SAFE_DIVIDE(
        adjusted_renewal_rate - min_renewal,
        max_renewal - min_renewal
      ),
      2
    ) AS adjusted_renewal_score
    
  FROM score_range
),

-- ============================================================
-- 6. FINAL PRIORITY CLASSIFICATION
-- ============================================================

priority_validation AS (
  SELECT
    *,
    
    ROUND(
        adjusted_conversion_score * 0.30
      + adjusted_initial_value_score * 0.25
      + adjusted_lifecycle_score * 0.30
      + adjusted_renewal_score * 0.15,
      2
    ) AS confidence_adjusted_score
    
  FROM final_scoring
)

SELECT
  employee_segment,
  industry,
  
  total_leads,
  contracted_leads,
  
  -- Evidence
  evidence_weight,
  
  CASE
    WHEN total_leads >= 50 THEN 'High Evidence'
    WHEN total_leads >= 30 THEN 'Moderate Evidence'
    WHEN total_leads >= 15 THEN 'Limited Evidence'
    ELSE 'Low Evidence'
  END AS evidence_strength,
  
  -- Raw performance
  ROUND(100 * raw_conversion_rate, 2) AS raw_conversion_rate_pct,
  ROUND(raw_initial_gmv_per_lead, 0) AS raw_initial_gmv_per_lead,
  ROUND(raw_lifecycle_gmv_per_lead, 0) AS raw_lifecycle_gmv_per_lead,
  ROUND(100 * raw_renewal_rate, 2) AS raw_renewal_rate_pct,
  
  -- Confidence-adjusted performance
  ROUND(100 * adjusted_conversion_rate, 2)
    AS adjusted_conversion_rate_pct,
    
  ROUND(adjusted_initial_gmv_per_lead, 0)
    AS adjusted_initial_gmv_per_lead,
    
  ROUND(adjusted_lifecycle_gmv_per_lead, 0)
    AS adjusted_lifecycle_gmv_per_lead,
    
  ROUND(100 * adjusted_renewal_rate, 2)
    AS adjusted_renewal_rate_pct,
  
  -- Final score
  confidence_adjusted_score,
  
  -- Decision-oriented classification
  CASE
    WHEN confidence_adjusted_score >= 70
         AND total_leads >= 30
      THEN 'Priority 1 - Scale'
      
    WHEN confidence_adjusted_score >= 55
         AND total_leads >= 15
      THEN 'Priority 2 - Optimize'
      
    WHEN confidence_adjusted_score >= 45
         OR total_leads >= 15
      THEN 'Priority 3 - Selective Test'
      
    ELSE 'Priority 4 - Deprioritize'
  END AS recommended_priority

FROM priority_validation

ORDER BY
  confidence_adjusted_score DESC,
  total_leads DESC;

-- 08. CHANNEL × SEGMENT
-- ============================================================
-- SQL G — QUALIFIED LEAD × ACQUISITION CHANNEL EFFECTIVENESS
-- ============================================================
-- Business Question:
-- For each Employee Segment × Industry,
-- which acquisition channel generates the best combination of:
-- 1. Lead conversion
-- 2. Initial economic value
-- 3. Lifecycle economic value
-- 4. Renewal quality
-- 5. Sufficient evidence
--
-- Grain before aggregation = 1 row per leads_id
-- Final grain = employee_segment × industry × session_source
-- ============================================================


WITH lead_base AS (
  -- ==========================================================
  -- STEP 1: Lead universe
  -- ==========================================================
  SELECT DISTINCT
    l.leads_id,

    s.session_source,

    CASE
      WHEN l.number_of_employee <= 10 THEN '01. 1-10'
      WHEN l.number_of_employee <= 50 THEN '02. 11-50'
      WHEN l.number_of_employee <= 100 THEN '03. 51-100'
      WHEN l.number_of_employee <= 250 THEN '04. 101-250'
      ELSE '05. 251+'
    END AS employee_segment,

    i.industry

  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l

  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` AS s
    ON l.session_source_code = s.session_source_code

  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` AS i
    ON l.industry_code = i.industry_code
),


-- ============================================================
-- STEP 2: Customer summary
-- IMPORTANT:
-- customer_360_table is already validated at leads_id grain
-- ============================================================
customer_summary AS (
  SELECT
    leads_id,
    contract_count,
    first_gmv,
    renewal_gmv,
    total_observed_gmv AS lifecycle_gmv,
    renewed

  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),


-- ============================================================
-- STEP 3: Lead-level acquisition master
-- Exactly 1 row per leads_id
-- ============================================================
lead_level AS (
  SELECT
    l.leads_id,
    l.session_source,
    l.employee_segment,
    l.industry,

    CASE
      WHEN c.leads_id IS NOT NULL THEN 1
      ELSE 0
    END AS converted_flag,

    COALESCE(c.contract_count, 0) AS contract_count,
    COALESCE(c.first_gmv, 0) AS first_gmv,
    COALESCE(c.renewal_gmv, 0) AS renewal_gmv,
    COALESCE(c.lifecycle_gmv, 0) AS lifecycle_gmv,
    COALESCE(c.renewed, 0) AS renewed_flag

  FROM lead_base AS l

  LEFT JOIN customer_summary AS c
    ON l.leads_id = c.leads_id
),


-- ============================================================
-- STEP 4: Overall performance by Qualified Lead Segment
-- This reconstructs the segment-level metrics used for priority
-- ============================================================
segment_performance AS (
  SELECT
    employee_segment,
    industry,

    COUNT(*) AS segment_total_leads,
    SUM(converted_flag) AS segment_contracted_leads,

    SAFE_DIVIDE(
      SUM(converted_flag),
      COUNT(*)
    ) AS segment_conversion_rate,

    SAFE_DIVIDE(
      SUM(first_gmv),
      COUNT(*)
    ) AS segment_initial_gmv_per_lead,

    SAFE_DIVIDE(
      SUM(lifecycle_gmv),
      COUNT(*)
    ) AS segment_lifecycle_gmv_per_lead,

    SAFE_DIVIDE(
      SUM(renewed_flag),
      SUM(converted_flag)
    ) AS segment_renewal_rate

  FROM lead_level

  GROUP BY
    employee_segment,
    industry
),


-- ============================================================
-- STEP 5: Channel performance within each Lead Segment
-- Final grain:
-- employee_segment × industry × session_source
-- ============================================================
channel_segment_performance AS (
  SELECT
    employee_segment,
    industry,
    session_source,

    COUNT(*) AS channel_leads,
    SUM(converted_flag) AS channel_contracted_leads,
    SUM(contract_count) AS channel_total_contracts,

    SAFE_DIVIDE(
      SUM(converted_flag),
      COUNT(*)
    ) AS conversion_rate,

    SAFE_DIVIDE(
      SUM(first_gmv),
      COUNT(*)
    ) AS initial_gmv_per_lead,

    SAFE_DIVIDE(
      SUM(lifecycle_gmv),
      COUNT(*)
    ) AS lifecycle_gmv_per_lead,

    SAFE_DIVIDE(
      SUM(lifecycle_gmv),
      SUM(converted_flag)
    ) AS lifecycle_gmv_per_converted_lead,

    SAFE_DIVIDE(
      SUM(renewed_flag),
      SUM(converted_flag)
    ) AS renewal_rate

  FROM lead_level

  GROUP BY
    employee_segment,
    industry,
    session_source
),


-- ============================================================
-- STEP 6: Add channel contribution within segment
-- ============================================================
channel_analysis AS (
  SELECT
    c.*,

    s.segment_total_leads,
    s.segment_contracted_leads,
    s.segment_conversion_rate,
    s.segment_initial_gmv_per_lead,
    s.segment_lifecycle_gmv_per_lead,
    s.segment_renewal_rate,

    SAFE_DIVIDE(
      c.channel_leads,
      s.segment_total_leads
    ) AS lead_share_within_segment,

    SAFE_DIVIDE(
      c.channel_contracted_leads,
      s.segment_contracted_leads
    ) AS contracted_lead_share_within_segment,

    -- Relative conversion performance
    SAFE_DIVIDE(
      c.conversion_rate,
      s.segment_conversion_rate
    ) AS conversion_index,

    -- Relative lifecycle value performance
    SAFE_DIVIDE(
      c.lifecycle_gmv_per_lead,
      s.segment_lifecycle_gmv_per_lead
    ) AS lifecycle_value_index

  FROM channel_segment_performance AS c

  LEFT JOIN segment_performance AS s
    ON c.employee_segment = s.employee_segment
    AND c.industry = s.industry
),


-- ============================================================
-- STEP 7: Evidence Strength
-- ============================================================
evidence_classification AS (
  SELECT
    *,

    CASE
      WHEN channel_leads >= 50 THEN 'High Evidence'
      WHEN channel_leads >= 30 THEN 'Moderate Evidence'
      WHEN channel_leads >= 15 THEN 'Limited Evidence'
      ELSE 'Low Evidence'
    END AS channel_evidence_strength,

    CASE
      WHEN channel_leads >= 15 THEN 1
      ELSE 0
    END AS sufficient_evidence_flag

  FROM channel_analysis
),


-- ============================================================
-- STEP 8: Rank channels within each Lead Segment
-- Ranking prioritizes:
-- 1. Lifecycle GMV per Lead
-- 2. Conversion Rate
-- 3. Evidence / Volume
--
-- This ranking is for candidate identification,
-- not an automatic "scale" decision.
-- ============================================================
channel_ranking AS (
  SELECT
    *,

    ROW_NUMBER() OVER (
      PARTITION BY employee_segment, industry
      ORDER BY
        CASE WHEN channel_leads >= 15 THEN 1 ELSE 0 END DESC,
        lifecycle_gmv_per_lead DESC,
        conversion_rate DESC,
        channel_leads DESC
    ) AS channel_rank_within_segment

  FROM evidence_classification
)


-- ============================================================
-- FINAL OUTPUT
-- ============================================================
SELECT
  employee_segment,
  industry,
  session_source,

  -- Segment context
  segment_total_leads,
  segment_contracted_leads,
  ROUND(100 * segment_conversion_rate, 2)
    AS segment_conversion_rate_pct,

  -- Channel acquisition volume
  channel_leads,

  ROUND(
    100 * lead_share_within_segment,
    2
  ) AS lead_share_within_segment_pct,

  channel_contracted_leads,
  channel_total_contracts,

  ROUND(
    100 * contracted_lead_share_within_segment,
    2
  ) AS contracted_lead_share_within_segment_pct,

  -- Channel quality
  ROUND(
    100 * conversion_rate,
    2
  ) AS conversion_rate_pct,

  ROUND(
    initial_gmv_per_lead,
    0
  ) AS initial_gmv_per_lead,

  ROUND(
    lifecycle_gmv_per_lead,
    0
  ) AS lifecycle_gmv_per_lead,

  ROUND(
    lifecycle_gmv_per_converted_lead,
    0
  ) AS lifecycle_gmv_per_converted_lead,

  ROUND(
    100 * renewal_rate,
    2
  ) AS renewal_rate_pct,

  -- Relative performance
  ROUND(
    conversion_index,
    2
  ) AS conversion_index_vs_segment,

  ROUND(
    lifecycle_value_index,
    2
  ) AS lifecycle_value_index_vs_segment,

  -- Evidence
  channel_evidence_strength,
  sufficient_evidence_flag,

  -- Ranking
  channel_rank_within_segment

FROM channel_ranking

ORDER BY
  employee_segment,
  industry,
  channel_rank_within_segment,
  channel_leads DESC;

-- 09. INTENT VALIDATION
-- ============================================================
-- H0-1 — AUDIT ACTUAL GOOGLE ANALYTICS PAGE_NAME
-- ============================================================
-- Objective:
-- Identify the real Page_Name values used by PeopleU
-- and determine which ones represent lead intent.
-- ============================================================

SELECT
    Page_Name,

    COUNT(*) AS page_views,

    COUNT(DISTINCT leads_id) AS unique_leads

FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.google_analytics_clean`

GROUP BY
    Page_Name

ORDER BY
    unique_leads DESC,
    page_views DESC;

-- ============================================================
-- SQL H1-A — LEAD INTENT SIGNAL VALIDATION
-- ============================================================
-- Objective:
-- Validate whether pre-registration page intent is associated
-- with conversion and customer economic quality.
--
-- Intent hierarchy:
-- 3 = Set a Meeting
-- 2 = Demo
-- 1 = Brochure
-- 0 = Unknown / Other
--
-- IMPORTANT:
-- Only Google Analytics page visits BEFORE leads_registered
-- are used to avoid post-registration leakage.
--
-- Grain:
-- 1 row = 1 leads_id
-- ============================================================

WITH lead_base AS (

    SELECT DISTINCT
        l.leads_id,
        l.leads_registered,

        s.session_source,

        CASE
            WHEN l.number_of_employee <= 10 THEN '01. 1-10'
            WHEN l.number_of_employee <= 50 THEN '02. 11-50'
            WHEN l.number_of_employee <= 100 THEN '03. 51-100'
            WHEN l.number_of_employee <= 250 THEN '04. 101-250'
            ELSE '05. 251+'
        END AS employee_segment,

        i.industry

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l

    LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` AS s
        ON l.session_source_code = s.session_source_code

    LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` AS i
        ON l.industry_code = i.industry_code
),


-- ============================================================
-- STEP 1 — CLASSIFY GOOGLE ANALYTICS PAGES
-- ============================================================

page_intent AS (

    SELECT
        g.leads_id,
        g.Page_Name,
        g.Page_timestamp,

        CASE

            WHEN g.Page_Name = '/form/set-a-meeting'
                THEN 3

            WHEN g.Page_Name = '/form/demo'
                THEN 2

            WHEN g.Page_Name = '/form/brochure'
                THEN 1

            ELSE 0

        END AS intent_score

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.google_analytics_clean` AS g

),


-- ============================================================
-- STEP 2 — ONLY PRE-REGISTRATION BEHAVIOR
-- ============================================================

pre_registration_intent AS (

    SELECT
        p.leads_id,
        p.Page_Name,
        p.Page_timestamp,
        p.intent_score

    FROM page_intent AS p

    INNER JOIN lead_base AS l
        ON p.leads_id = l.leads_id

    WHERE
        p.Page_timestamp <= l.leads_registered
),


-- ============================================================
-- STEP 3 — ASSIGN ONE FINAL INTENT PER LEAD
--
-- Highest observed intent:
-- Set a Meeting > Demo > Brochure > Other
-- ============================================================

lead_intent AS (

    SELECT
        l.leads_id,

        COALESCE(
            MAX(p.intent_score),
            0
        ) AS max_intent_score

    FROM lead_base AS l

    LEFT JOIN pre_registration_intent AS p
        ON l.leads_id = p.leads_id

    GROUP BY
        l.leads_id
),


-- ============================================================
-- STEP 4 — LABEL INTENT
-- ============================================================

lead_intent_labeled AS (

    SELECT
        leads_id,

        CASE
            WHEN max_intent_score = 3
                THEN 'High Intent - Set a Meeting'

            WHEN max_intent_score = 2
                THEN 'Medium Intent - Demo'

            WHEN max_intent_score = 1
                THEN 'Low Intent - Brochure'

            ELSE 'Unknown / No Tracked Intent'

        END AS lead_intent

    FROM lead_intent
),


-- ============================================================
-- STEP 5 — CUSTOMER 360
-- ============================================================

customer_summary AS (

    SELECT
        leads_id,
        first_gmv,
        total_observed_gmv AS lifecycle_gmv,
        renewed

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),


-- ============================================================
-- STEP 6 — ONE ROW PER LEAD
-- ============================================================

lead_master AS (

    SELECT
        l.leads_id,
        l.session_source,
        l.employee_segment,
        l.industry,

        COALESCE(
            i.lead_intent,
            'Unknown / No Tracked Intent'
        ) AS lead_intent,

        CASE
            WHEN c.leads_id IS NOT NULL
                THEN 1
            ELSE 0
        END AS converted_flag,

        COALESCE(c.first_gmv, 0) AS first_gmv,

        COALESCE(c.lifecycle_gmv, 0) AS lifecycle_gmv,

        COALESCE(c.renewed, 0) AS renewed_flag

    FROM lead_base AS l

    LEFT JOIN lead_intent_labeled AS i
        ON l.leads_id = i.leads_id

    LEFT JOIN customer_summary AS c
        ON l.leads_id = c.leads_id
)


-- ============================================================
-- FINAL — INTENT PERFORMANCE
-- ============================================================

SELECT

    lead_intent,

    COUNT(*) AS total_leads,

    ROUND(
        100 * SAFE_DIVIDE(
            COUNT(*),
            SUM(COUNT(*)) OVER ()
        ),
        2
    ) AS lead_share_pct,

    SUM(converted_flag) AS contracted_leads,

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(converted_flag),
            COUNT(*)
        ),
        2
    ) AS conversion_rate_pct,

    ROUND(
        SAFE_DIVIDE(
            SUM(first_gmv),
            COUNT(*)
        ),
        0
    ) AS first_gmv_per_lead,

    ROUND(
        SAFE_DIVIDE(
            SUM(lifecycle_gmv),
            COUNT(*)
        ),
        0
    ) AS lifecycle_gmv_per_lead,

    ROUND(
        SAFE_DIVIDE(
            SUM(lifecycle_gmv),
            SUM(converted_flag)
        ),
        0
    ) AS lifecycle_gmv_per_converted_lead,

    SUM(renewed_flag) AS renewed_leads,

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(renewed_flag),
            SUM(converted_flag)
        ),
        2
    ) AS renewal_rate_pct

FROM lead_master

GROUP BY
    lead_intent

ORDER BY
    CASE lead_intent
        WHEN 'High Intent - Set a Meeting' THEN 1
        WHEN 'Medium Intent - Demo' THEN 2
        WHEN 'Low Intent - Brochure' THEN 3
        ELSE 4
    END;

-- 10. CORE ACQUISITION MOTION
-- ============================================================
-- SQL H1-B
-- PRIORITY SEGMENT × ACQUISITION CHANNEL × LEAD INTENT
-- ============================================================
--
-- Business Objective:
-- Identify the strongest acquisition "motions":
--
-- WHO  = Employee Segment × Industry
-- WHERE = Acquisition Channel
-- HOW READY = Pre-Registration Intent
--
-- Final grain:
-- 1 row = Employee Segment × Industry × Channel × Intent
--
-- IMPORTANT:
-- Intent is inferred from Google Analytics pages observed
-- BEFORE the lead registration timestamp.
-- ============================================================


-- ============================================================
-- 1. LEAD BASE
-- ============================================================

WITH lead_base AS (

    SELECT DISTINCT
        l.leads_id,
        l.leads_registered,

        s.session_source,

        CASE
            WHEN l.number_of_employee <= 10 THEN '01. 1-10'
            WHEN l.number_of_employee <= 50 THEN '02. 11-50'
            WHEN l.number_of_employee <= 100 THEN '03. 51-100'
            WHEN l.number_of_employee <= 250 THEN '04. 101-250'
            ELSE '05. 251+'
        END AS employee_segment,

        i.industry

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l

    LEFT JOIN
        `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` AS s
        ON l.session_source_code = s.session_source_code

    LEFT JOIN
        `new-portfolio-1.PeopleU_B2B_Software_SaaS.industries` AS i
        ON l.industry_code = i.industry_code
),


-- ============================================================
-- 2. GOOGLE ANALYTICS → PRE-REGISTRATION INTENT
--
-- Priority:
-- Set a Meeting > Demo > Brochure
-- ============================================================

page_intent AS (

    SELECT
        g.leads_id,
        g.Page_Name,
        g.Page_timestamp,

        CASE

            WHEN g.Page_Name = '/form/set-a-meeting'
                THEN 3

            WHEN g.Page_Name = '/form/demo'
                THEN 2

            WHEN g.Page_Name = '/form/brochure'
                THEN 1

            ELSE 0

        END AS intent_score

    FROM
        `new-portfolio-1.PeopleU_B2B_Software_SaaS.google_analytics_clean` AS g
),


-- ============================================================
-- 3. KEEP ONLY PAGE VISITS BEFORE LEAD REGISTRATION
-- ============================================================

pre_registration_intent AS (

    SELECT
        p.leads_id,
        p.intent_score

    FROM page_intent AS p

    INNER JOIN lead_base AS l
        ON p.leads_id = l.leads_id

    WHERE
        p.Page_timestamp <= l.leads_registered
),


-- ============================================================
-- 4. ONE FINAL INTENT PER LEAD
-- Highest observed intent before registration
-- ============================================================

lead_intent AS (

    SELECT
        l.leads_id,

        COALESCE(
            MAX(p.intent_score),
            0
        ) AS max_intent_score

    FROM lead_base AS l

    LEFT JOIN pre_registration_intent AS p
        ON l.leads_id = p.leads_id

    GROUP BY
        l.leads_id
),


lead_intent_labeled AS (

    SELECT
        leads_id,

        CASE
            WHEN max_intent_score = 3
                THEN 'High Intent - Set a Meeting'

            WHEN max_intent_score = 2
                THEN 'Medium Intent - Demo'

            WHEN max_intent_score = 1
                THEN 'Low Intent - Brochure'

            ELSE 'Unknown / No Tracked Intent'

        END AS lead_intent

    FROM lead_intent
),


-- ============================================================
-- 5. CUSTOMER 360
-- 1 row = 1 leads_id
-- ============================================================

customer_summary AS (

    SELECT
        leads_id,
        first_gmv,
        total_observed_gmv AS lifecycle_gmv,
        renewed

    FROM
        `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),


-- ============================================================
-- 6. LEAD-LEVEL MASTER
-- Exactly 1 row per leads_id
-- ============================================================

lead_level AS (

    SELECT

        l.leads_id,
        l.session_source,
        l.employee_segment,
        l.industry,

        COALESCE(
            i.lead_intent,
            'Unknown / No Tracked Intent'
        ) AS lead_intent,

        CASE
            WHEN c.leads_id IS NOT NULL
                THEN 1
            ELSE 0
        END AS converted_flag,

        COALESCE(c.first_gmv, 0) AS first_gmv,

        COALESCE(c.lifecycle_gmv, 0) AS lifecycle_gmv,

        COALESCE(c.renewed, 0) AS renewed_flag

    FROM lead_base AS l

    LEFT JOIN lead_intent_labeled AS i
        ON l.leads_id = i.leads_id

    LEFT JOIN customer_summary AS c
        ON l.leads_id = c.leads_id
),


-- ============================================================
-- 7. SEGMENT RAW PERFORMANCE
-- Used as benchmark for WHO
-- ============================================================

segment_performance AS (

    SELECT

        employee_segment,
        industry,

        COUNT(*) AS segment_total_leads,

        SUM(converted_flag) AS segment_contracted_leads,

        SAFE_DIVIDE(
            SUM(converted_flag),
            COUNT(*)
        ) AS segment_conversion_rate,

        SAFE_DIVIDE(
            SUM(first_gmv),
            COUNT(*)
        ) AS segment_initial_gmv_per_lead,

        SAFE_DIVIDE(
            SUM(lifecycle_gmv),
            COUNT(*)
        ) AS segment_lifecycle_gmv_per_lead,

        SAFE_DIVIDE(
            SUM(renewed_flag),
            SUM(converted_flag)
        ) AS segment_renewal_rate

    FROM lead_level

    GROUP BY
        employee_segment,
        industry
),


-- ============================================================
-- 8. CHANNEL × SEGMENT × INTENT PERFORMANCE
-- ============================================================

motion_performance AS (

    SELECT

        employee_segment,
        industry,
        session_source,
        lead_intent,

        COUNT(*) AS motion_leads,

        SUM(converted_flag) AS motion_contracted_leads,

        SAFE_DIVIDE(
            SUM(converted_flag),
            COUNT(*)
        ) AS motion_conversion_rate,

        SAFE_DIVIDE(
            SUM(first_gmv),
            COUNT(*)
        ) AS motion_initial_gmv_per_lead,

        SAFE_DIVIDE(
            SUM(lifecycle_gmv),
            COUNT(*)
        ) AS motion_lifecycle_gmv_per_lead,

        SAFE_DIVIDE(
            SUM(lifecycle_gmv),
            SUM(converted_flag)
        ) AS motion_lifecycle_gmv_per_converted_lead,

        SAFE_DIVIDE(
            SUM(renewed_flag),
            SUM(converted_flag)
        ) AS motion_renewal_rate

    FROM lead_level

    GROUP BY

        employee_segment,
        industry,
        session_source,
        lead_intent
),


-- ============================================================
-- 9. COMPARE MOTION AGAINST SEGMENT BASELINE
-- ============================================================

motion_benchmark AS (

    SELECT

        m.*,

        s.segment_total_leads,
        s.segment_contracted_leads,

        s.segment_conversion_rate,
        s.segment_initial_gmv_per_lead,
        s.segment_lifecycle_gmv_per_lead,
        s.segment_renewal_rate,

        SAFE_DIVIDE(
            m.motion_conversion_rate,
            s.segment_conversion_rate
        ) AS conversion_index,

        SAFE_DIVIDE(
            m.motion_lifecycle_gmv_per_lead,
            s.segment_lifecycle_gmv_per_lead
        ) AS lifecycle_value_index,

        SAFE_DIVIDE(
            m.motion_leads,
            s.segment_total_leads
        ) AS motion_share_of_segment

    FROM motion_performance AS m

    LEFT JOIN segment_performance AS s

        ON m.employee_segment = s.employee_segment
        AND m.industry = s.industry
),


-- ============================================================
-- 10. EVIDENCE STRENGTH
-- ============================================================

motion_evidence AS (

    SELECT
        *,

        CASE

            WHEN motion_leads >= 50
                THEN 'High Evidence'

            WHEN motion_leads >= 30
                THEN 'Moderate Evidence'

            WHEN motion_leads >= 15
                THEN 'Limited Evidence'

            ELSE 'Low Evidence'

        END AS evidence_strength

    FROM motion_benchmark
),


-- ============================================================
-- 11. PRIORITY SEGMENT
--
-- We use the SAME BUSINESS THRESHOLD FRAMEWORK as F-3.
-- This is NOT a new scoring system.
--
-- The priority here is based on the evidence-adjusted
-- segment quality logic already established earlier.
-- ============================================================

segment_priority AS (

    SELECT
        employee_segment,
        industry,

        CASE

            -- Core Scale
            WHEN segment_total_leads >= 30
                 AND segment_conversion_rate >= 0.30
                 AND segment_lifecycle_gmv_per_lead >= 2000000
            THEN 'Priority 1 - Core Target'

            -- Growth Opportunity
            WHEN segment_total_leads >= 30
                 AND (
                     segment_conversion_rate >= 0.25
                     OR segment_lifecycle_gmv_per_lead >= 1500000
                 )
            THEN 'Priority 2 - Growth Target'

            -- Smaller / Emerging
            WHEN segment_total_leads >= 15
            THEN 'Priority 3 - Selective Target'

            ELSE 'Priority 4 - Low Priority'

        END AS target_priority

    FROM segment_performance
),


-- ============================================================
-- 12. FINAL MOTION CLASSIFICATION
-- ============================================================

final_motion AS (

    SELECT

        m.*,

        p.target_priority,

        CASE

            -- ==================================================
            -- CORE ACQUISITION MOTION
            -- High-priority audience
            -- + sufficient channel evidence
            -- + above segment benchmark in both conversion
            --   and lifecycle value
            -- ==================================================

            WHEN p.target_priority = 'Priority 1 - Core Target'
                 AND m.motion_leads >= 30
                 AND m.conversion_index >= 1
                 AND m.lifecycle_value_index >= 1
            THEN 'CORE ACQUISITION MOTION'


            -- ==================================================
            -- EXPANSION MOTION
            -- Good target + evidence sufficient
            -- ==================================================

            WHEN p.target_priority IN (
                     'Priority 1 - Core Target',
                     'Priority 2 - Growth Target'
                 )
                 AND m.motion_leads >= 15
                 AND m.conversion_index >= 1
                 AND m.lifecycle_value_index >= 1
            THEN 'EXPANSION MOTION'


            -- ==================================================
            -- CONTROLLED TEST
            -- Strong signal but insufficient evidence
            -- ==================================================

            WHEN p.target_priority IN (
                     'Priority 1 - Core Target',
                     'Priority 2 - Growth Target',
                     'Priority 3 - Selective Target'
                 )
                 AND m.conversion_index >= 1
                 AND m.lifecycle_value_index >= 1
                 AND m.motion_leads < 15
            THEN 'CONTROLLED TEST'


            -- ==================================================
            -- OPTIMIZE
            -- One dimension strong, one weak
            -- ==================================================

            WHEN m.conversion_index >= 1
                 OR m.lifecycle_value_index >= 1
            THEN 'OPTIMIZE'


            -- ==================================================
            -- DEPRIORITIZE
            -- Sufficient evidence + weak on both dimensions
            -- ==================================================

            WHEN m.motion_leads >= 15
                 AND m.conversion_index < 1
                 AND m.lifecycle_value_index < 1
            THEN 'DEPRIORITIZE'


            ELSE 'NURTURE / MONITOR'

        END AS acquisition_motion


    FROM motion_evidence AS m

    LEFT JOIN segment_priority AS p

        ON m.employee_segment = p.employee_segment
        AND m.industry = p.industry
)


-- ============================================================
-- FINAL MANAGEMENT-READY OUTPUT
-- ============================================================

SELECT

    target_priority,

    employee_segment,
    industry,
    session_source AS acquisition_channel,

    lead_intent,

    acquisition_motion,

    -- Evidence
    motion_leads,
    motion_contracted_leads,
    evidence_strength,

    -- Conversion
    ROUND(
        100 * motion_conversion_rate,
        2
    ) AS conversion_rate_pct,

    -- Economic value
    ROUND(
        motion_initial_gmv_per_lead,
        0
    ) AS initial_gmv_per_lead,

    ROUND(
        motion_lifecycle_gmv_per_lead,
        0
    ) AS lifecycle_gmv_per_lead,

    ROUND(
        motion_lifecycle_gmv_per_converted_lead,
        0
    ) AS lifecycle_gmv_per_converted_lead,

    -- Renewal
    ROUND(
        100 * motion_renewal_rate,
        2
    ) AS renewal_rate_pct,

    -- Benchmark
    ROUND(
        conversion_index,
        2
    ) AS conversion_index_vs_segment,

    ROUND(
        lifecycle_value_index,
        2
    ) AS lifecycle_value_index_vs_segment,

    ROUND(
        100 * motion_share_of_segment,
        2
    ) AS motion_share_of_segment_pct,

    -- Segment context
    segment_total_leads,
    segment_contracted_leads,

    ROUND(
        100 * segment_conversion_rate,
        2
    ) AS segment_conversion_rate_pct,

    ROUND(
        segment_lifecycle_gmv_per_lead,
        0
    ) AS segment_lifecycle_gmv_per_lead

FROM final_motion

ORDER BY

    CASE target_priority
        WHEN 'Priority 1 - Core Target' THEN 1
        WHEN 'Priority 2 - Growth Target' THEN 2
        WHEN 'Priority 3 - Selective Target' THEN 3
        ELSE 4
    END,

    CASE acquisition_motion
        WHEN 'CORE ACQUISITION MOTION' THEN 1
        WHEN 'EXPANSION MOTION' THEN 2
        WHEN 'CONTROLLED TEST' THEN 3
        WHEN 'OPTIMIZE' THEN 4
        WHEN 'DEPRIORITIZE' THEN 5
        ELSE 6
    END,

    motion_lifecycle_gmv_per_lead DESC,
    motion_leads DESC;

-- 11. MARKETING SPEND VALIDATION
-- ============================================================
-- MSA-1 — MARKETING SPEND DATA AVAILABILITY AUDIT
-- Inventory seluruh tabel dalam PeopleU dataset
-- ============================================================

SELECT
    table_name,
    table_type
FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.INFORMATION_SCHEMA.TABLES`
ORDER BY
    table_name;

-- 12. CHANNEL ECONOMIC EFFICIENCY
-- ============================================================
-- M1-B-1 — CORRECTED MARKETING CHANNEL ECONOMIC EFFICIENCY
-- ============================================================
--
-- Objective:
-- Compare marketing spend against:
-- Leads -> Contracts -> Initial GMV -> Lifecycle GMV
--
-- Grain before aggregation:
-- 1 row per leads_id
--
-- IMPORTANT:
-- Referral spend column = referral_spend
-- Canonical acquisition channel = Referral
-- ============================================================

WITH spend_long AS (

    -- ========================================================
    -- CPC
    -- ========================================================
    SELECT
        cohort_month,
        'CPC' AS session_source,
        cpc_spend AS marketing_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    -- ========================================================
    -- DIRECT
    -- ========================================================
    SELECT
        cohort_month,
        'Direct' AS session_source,
        direct_spend AS marketing_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    -- ========================================================
    -- ORGANIC SEARCH
    -- ========================================================
    SELECT
        cohort_month,
        'Organic Search' AS session_source,
        organic_search_spend AS marketing_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    -- ========================================================
    -- ORGANIC SOCIAL
    -- ========================================================
    SELECT
        cohort_month,
        'Organic Social' AS session_source,
        organic_social_spend AS marketing_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    -- ========================================================
    -- REFERRAL
    -- IMPORTANT: referral_spend
    -- ========================================================
    SELECT
        cohort_month,
        'Referral' AS session_source,
        referral_spend AS marketing_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
),


-- ============================================================
-- 1. LEAD BASE
-- Canonicalize acquisition channel name
-- ============================================================

lead_base AS (

    SELECT DISTINCT

        l.leads_id,

        DATE_TRUNC(
            DATE(l.leads_registered),
            MONTH
        ) AS acquisition_month,

        CASE

            WHEN LOWER(TRIM(s.session_source))
                IN ('referral', 'refferal')
                THEN 'Referral'

            WHEN LOWER(TRIM(s.session_source))
                = 'cpc'
                THEN 'CPC'

            WHEN LOWER(TRIM(s.session_source))
                = 'direct'
                THEN 'Direct'

            WHEN LOWER(TRIM(s.session_source))
                IN ('organic search', 'organic_search')
                THEN 'Organic Search'

            WHEN LOWER(TRIM(s.session_source))
                IN ('organic social', 'organic_social')
                THEN 'Organic Social'

            ELSE TRIM(s.session_source)

        END AS session_source

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l

    LEFT JOIN
        `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` AS s

        ON l.session_source_code = s.session_source_code
),


-- ============================================================
-- 2. CUSTOMER 360
-- ============================================================

customer_summary AS (

    SELECT

        leads_id,

        first_gmv,

        total_observed_gmv AS lifecycle_gmv,

        renewed

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),


-- ============================================================
-- 3. LEAD-LEVEL MASTER
-- 1 row = 1 leads_id
-- ============================================================

lead_level AS (

    SELECT

        l.leads_id,

        l.acquisition_month,

        l.session_source,

        CASE
            WHEN c.leads_id IS NOT NULL
                THEN 1
            ELSE 0
        END AS converted_flag,

        COALESCE(
            c.first_gmv,
            0
        ) AS first_gmv,

        COALESCE(
            c.lifecycle_gmv,
            0
        ) AS lifecycle_gmv,

        COALESCE(
            c.renewed,
            0
        ) AS renewed_flag

    FROM lead_base AS l

    LEFT JOIN customer_summary AS c

        ON l.leads_id = c.leads_id
),


-- ============================================================
-- 4. MONTH × CHANNEL PERFORMANCE
-- ============================================================

monthly_channel AS (

    SELECT

        acquisition_month AS cohort_month,

        session_source,

        COUNT(*) AS total_leads,

        SUM(converted_flag) AS contracted_leads,

        SUM(first_gmv) AS total_initial_gmv,

        SUM(lifecycle_gmv) AS total_lifecycle_gmv,

        SUM(renewed_flag) AS renewed_customers

    FROM lead_level

    GROUP BY

        acquisition_month,
        session_source
),


-- ============================================================
-- 5. JOIN SPEND WITH ACQUISITION
-- ============================================================

channel_economics AS (

    SELECT

        s.cohort_month,

        s.session_source,

        s.marketing_spend,

        COALESCE(
            m.total_leads,
            0
        ) AS total_leads,

        COALESCE(
            m.contracted_leads,
            0
        ) AS contracted_leads,

        COALESCE(
            m.total_initial_gmv,
            0
        ) AS total_initial_gmv,

        COALESCE(
            m.total_lifecycle_gmv,
            0
        ) AS total_lifecycle_gmv,

        COALESCE(
            m.renewed_customers,
            0
        ) AS renewed_customers

    FROM spend_long AS s

    LEFT JOIN monthly_channel AS m

        ON s.cohort_month = m.cohort_month

        AND s.session_source = m.session_source
)


-- ============================================================
-- 6. FINAL CHANNEL ECONOMIC EFFICIENCY
-- ============================================================

SELECT

    session_source,

    -- --------------------------------------------------------
    -- SPEND
    -- --------------------------------------------------------

    SUM(marketing_spend)
        AS total_marketing_spend,

    -- --------------------------------------------------------
    -- ACQUISITION VOLUME
    -- --------------------------------------------------------

    SUM(total_leads)
        AS total_leads,

    SUM(contracted_leads)
        AS contracted_leads,

    -- --------------------------------------------------------
    -- ECONOMIC VALUE
    -- --------------------------------------------------------

    SUM(total_initial_gmv)
        AS total_initial_gmv,

    SUM(total_lifecycle_gmv)
        AS total_lifecycle_gmv,

    -- --------------------------------------------------------
    -- COST EFFICIENCY
    -- --------------------------------------------------------

    ROUND(
        SAFE_DIVIDE(
            SUM(marketing_spend),
            SUM(total_leads)
        ),
        0
    ) AS CPL,

    ROUND(
        SAFE_DIVIDE(
            SUM(marketing_spend),
            SUM(contracted_leads)
        ),
        0
    ) AS cost_per_contract,

    -- --------------------------------------------------------
    -- CONVERSION
    -- --------------------------------------------------------

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(contracted_leads),
            SUM(total_leads)
        ),
        2
    ) AS conversion_rate_pct,

    -- --------------------------------------------------------
    -- VALUE PER ACQUIRED LEAD
    -- --------------------------------------------------------

    ROUND(
        SAFE_DIVIDE(
            SUM(total_lifecycle_gmv),
            SUM(total_leads)
        ),
        0
    ) AS lifecycle_gmv_per_lead,

    -- --------------------------------------------------------
    -- VALUE PER CONTRACT
    -- --------------------------------------------------------

    ROUND(
        SAFE_DIVIDE(
            SUM(total_lifecycle_gmv),
            SUM(contracted_leads)
        ),
        0
    ) AS lifecycle_gmv_per_contract,

    -- --------------------------------------------------------
    -- SPEND SHARE
    -- --------------------------------------------------------

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(marketing_spend),
            SUM(
                SUM(marketing_spend)
            ) OVER ()
        ),
        2
    ) AS spend_share_pct,

    -- --------------------------------------------------------
    -- LEAD SHARE
    -- --------------------------------------------------------

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(total_leads),
            SUM(
                SUM(total_leads)
            ) OVER ()
        ),
        2
    ) AS lead_share_pct,

    -- --------------------------------------------------------
    -- CONTRACT SHARE
    -- --------------------------------------------------------

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(contracted_leads),
            SUM(
                SUM(contracted_leads)
            ) OVER ()
        ),
        2
    ) AS contract_share_pct,

    -- --------------------------------------------------------
    -- LIFECYCLE GMV SHARE
    -- --------------------------------------------------------

    ROUND(
        100 * SAFE_DIVIDE(
            SUM(total_lifecycle_gmv),
            SUM(
                SUM(total_lifecycle_gmv)
            ) OVER ()
        ),
        2
    ) AS lifecycle_gmv_share_pct,

    -- --------------------------------------------------------
    -- LIFECYCLE VALUE / SPEND
    -- --------------------------------------------------------

    ROUND(
        SAFE_DIVIDE(
            SUM(total_lifecycle_gmv),
            SUM(marketing_spend)
        ),
        2
    ) AS lifecycle_gmv_per_rp_spend

FROM channel_economics

GROUP BY
    session_source

ORDER BY
    lifecycle_gmv_per_rp_spend DESC;

-- 13. SPEND RESPONSE
-- ============================================================
-- M2-A — MONTHLY MARKETING SPEND RESPONSE DIAGNOSTIC
-- ============================================================
--
-- Objective:
-- Measure observed monthly relationship between:
-- Spend -> Leads -> Contracts -> Lifecycle GMV
--
-- Also checks 1-month lag:
-- Spend_t -> Leads_(t+1)
--
-- IMPORTANT:
-- This is observational response analysis,
-- NOT causal attribution.
-- ============================================================

WITH spend_long AS (

    SELECT
        cohort_month,
        'CPC' AS session_source,
        cpc_spend AS marketing_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    SELECT
        cohort_month,
        'Direct',
        direct_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    SELECT
        cohort_month,
        'Organic Search',
        organic_search_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    SELECT
        cohort_month,
        'Organic Social',
        organic_social_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`

    UNION ALL

    SELECT
        cohort_month,
        'Referral',
        referral_spend
    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
),

lead_base AS (

    SELECT DISTINCT
        l.leads_id,

        DATE_TRUNC(
            DATE(l.leads_registered),
            MONTH
        ) AS acquisition_month,

        CASE
            WHEN LOWER(TRIM(s.session_source))
                IN ('referral', 'refferal')
                THEN 'Referral'

            WHEN LOWER(TRIM(s.session_source)) = 'cpc'
                THEN 'CPC'

            WHEN LOWER(TRIM(s.session_source)) = 'direct'
                THEN 'Direct'

            WHEN LOWER(TRIM(s.session_source))
                IN ('organic search', 'organic_search')
                THEN 'Organic Search'

            WHEN LOWER(TRIM(s.session_source))
                IN ('organic social', 'organic_social')
                THEN 'Organic Social'

            ELSE TRIM(s.session_source)
        END AS session_source

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l

    LEFT JOIN
        `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` AS s

        ON l.session_source_code = s.session_source_code
),

customer_summary AS (

    SELECT
        leads_id,
        total_observed_gmv AS lifecycle_gmv

    FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),

monthly_leads AS (

    SELECT
        acquisition_month AS cohort_month,
        session_source,

        COUNT(*) AS total_leads,

        COUNTIF(
            c.leads_id IS NOT NULL
        ) AS contracted_leads,

        SUM(
            COALESCE(c.lifecycle_gmv, 0)
        ) AS lifecycle_gmv

    FROM lead_base AS l

    LEFT JOIN customer_summary AS c

        ON l.leads_id = c.leads_id

    GROUP BY
        acquisition_month,
        session_source
),

monthly_panel AS (

    SELECT
        s.cohort_month,
        s.session_source,

        s.marketing_spend,

        COALESCE(
            m.total_leads,
            0
        ) AS total_leads,

        COALESCE(
            m.contracted_leads,
            0
        ) AS contracted_leads,

        COALESCE(
            m.lifecycle_gmv,
            0
        ) AS lifecycle_gmv

    FROM spend_long AS s

    LEFT JOIN monthly_leads AS m

        ON s.cohort_month = m.cohort_month

        AND s.session_source = m.session_source
),

changes AS (

    SELECT
        *,

        LAG(marketing_spend) OVER (
            PARTITION BY session_source
            ORDER BY cohort_month
        ) AS prev_spend,

        LAG(total_leads) OVER (
            PARTITION BY session_source
            ORDER BY cohort_month
        ) AS prev_leads,

        LAG(contracted_leads) OVER (
            PARTITION BY session_source
            ORDER BY cohort_month
        ) AS prev_contracts,

        LAG(lifecycle_gmv) OVER (
            PARTITION BY session_source
            ORDER BY cohort_month
        ) AS prev_lifecycle_gmv

    FROM monthly_panel
)

SELECT
    cohort_month,
    session_source,

    marketing_spend,
    total_leads,
    contracted_leads,
    lifecycle_gmv,

    -- ========================================================
    -- Month-over-month percentage changes
    -- ========================================================

    ROUND(
        100 * SAFE_DIVIDE(
            marketing_spend - prev_spend,
            prev_spend
        ),
        2
    ) AS spend_change_pct,

    ROUND(
        100 * SAFE_DIVIDE(
            total_leads - prev_leads,
            prev_leads
        ),
        2
    ) AS leads_change_pct,

    ROUND(
        100 * SAFE_DIVIDE(
            contracted_leads - prev_contracts,
            prev_contracts
        ),
        2
    ) AS contracts_change_pct,

    ROUND(
        100 * SAFE_DIVIDE(
            lifecycle_gmv - prev_lifecycle_gmv,
            prev_lifecycle_gmv
        ),
        2
    ) AS lifecycle_gmv_change_pct,

    -- ========================================================
    -- Observed elasticity:
    -- % change in output / % change in spend
    -- ========================================================

    ROUND(
        SAFE_DIVIDE(
            SAFE_DIVIDE(
                total_leads - prev_leads,
                prev_leads
            ),
            SAFE_DIVIDE(
                marketing_spend - prev_spend,
                prev_spend
            )
        ),
        2
    ) AS observed_lead_elasticity,

    ROUND(
        SAFE_DIVIDE(
            SAFE_DIVIDE(
                contracted_leads - prev_contracts,
                prev_contracts
            ),
            SAFE_DIVIDE(
                marketing_spend - prev_spend,
                prev_spend
            )
        ),
        2
    ) AS observed_contract_elasticity,

    ROUND(
        SAFE_DIVIDE(
            SAFE_DIVIDE(
                lifecycle_gmv - prev_lifecycle_gmv,
                prev_lifecycle_gmv
            ),
            SAFE_DIVIDE(
                marketing_spend - prev_spend,
                prev_spend
            )
        ),
        2
    ) AS observed_gmv_elasticity

FROM changes

WHERE
    prev_spend IS NOT NULL
    AND prev_spend > 0

ORDER BY
    session_source,
    cohort_month;


-- 14. CHANNEL SCALING SCORECARD
-- ============================================================
-- M2-B — MARKETING CHANNEL SCALING SCORECARD
-- ============================================================

WITH spend_long AS (
  SELECT
    cohort_month,
    'CPC' AS session_source,
    cpc_spend AS marketing_spend
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
  UNION ALL
  SELECT
    cohort_month,
    'Direct',
    direct_spend
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
  UNION ALL
  SELECT
    cohort_month,
    'Organic Search',
    organic_search_spend
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
  UNION ALL
  SELECT
    cohort_month,
    'Organic Social',
    organic_social_spend
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
  UNION ALL
  SELECT
    cohort_month,
    'Referral',
    referral_spend
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.saas_additional_clean`
),

lead_base AS (
  SELECT DISTINCT
    l.leads_id,
    DATE_TRUNC(DATE(l.leads_registered), MONTH) AS acquisition_month,
    CASE
      WHEN LOWER(TRIM(s.session_source)) IN ('referral', 'refferal') THEN 'Referral'
      WHEN LOWER(TRIM(s.session_source)) = 'cpc' THEN 'CPC'
      WHEN LOWER(TRIM(s.session_source)) = 'direct' THEN 'Direct'
      WHEN LOWER(TRIM(s.session_source)) IN ('organic search', 'organic_search') THEN 'Organic Search'
      WHEN LOWER(TRIM(s.session_source)) IN ('organic social', 'organic_social') THEN 'Organic Social'
      ELSE TRIM(s.session_source)
    END AS session_source
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.leads` AS l
  LEFT JOIN `new-portfolio-1.PeopleU_B2B_Software_SaaS.sessions_source` AS s
    ON l.session_source_code = s.session_source_code
),

customer_summary AS (
  SELECT
    leads_id,
    total_observed_gmv AS lifecycle_gmv
  FROM `new-portfolio-1.PeopleU_B2B_Software_SaaS.customer_360_table`
),

monthly_channel AS (
  SELECT
    l.acquisition_month AS cohort_month,
    l.session_source,
    COUNT(*) AS total_leads,
    COUNTIF(c.leads_id IS NOT NULL) AS contracted_leads,
    SUM(COALESCE(c.lifecycle_gmv, 0)) AS lifecycle_gmv
  FROM lead_base AS l
  LEFT JOIN customer_summary AS c
    ON l.leads_id = c.leads_id
  GROUP BY
    l.acquisition_month,
    l.session_source
),

monthly_panel AS (
  SELECT
    s.cohort_month,
    s.session_source,
    s.marketing_spend,
    COALESCE(m.total_leads, 0) AS total_leads,
    COALESCE(m.contracted_leads, 0) AS contracted_leads,
    COALESCE(m.lifecycle_gmv, 0) AS lifecycle_gmv
  FROM spend_long AS s
  LEFT JOIN monthly_channel AS m
    ON s.cohort_month = m.cohort_month
    AND s.session_source = m.session_source
),

monthly_changes AS (
  SELECT
    *,
    LAG(marketing_spend) OVER (PARTITION BY session_source ORDER BY cohort_month) AS prev_spend,
    LAG(total_leads) OVER (PARTITION BY session_source ORDER BY cohort_month) AS prev_leads,
    LAG(contracted_leads) OVER (PARTITION BY session_source ORDER BY cohort_month) AS prev_contracts,
    LAG(lifecycle_gmv) OVER (PARTITION BY session_source ORDER BY cohort_month) AS prev_gmv
  FROM monthly_panel
),

elasticity_monthly AS (
  SELECT
    *,
    SAFE_DIVIDE(
      SAFE_DIVIDE(total_leads - prev_leads, prev_leads),
      SAFE_DIVIDE(marketing_spend - prev_spend, prev_spend)
    ) AS lead_elasticity,
    SAFE_DIVIDE(
      SAFE_DIVIDE(contracted_leads - prev_contracts, prev_contracts),
      SAFE_DIVIDE(marketing_spend - prev_spend, prev_spend)
    ) AS contract_elasticity,
    SAFE_DIVIDE(
      SAFE_DIVIDE(lifecycle_gmv - prev_gmv, prev_gmv),
      SAFE_DIVIDE(marketing_spend - prev_spend, prev_spend)
    ) AS gmv_elasticity
  FROM monthly_changes
  WHERE prev_spend > 0
),

channel_economic AS (
  SELECT
    session_source,
    SUM(marketing_spend) AS total_spend,
    SUM(total_leads) AS total_leads,
    SUM(contracted_leads) AS total_contracts,
    SUM(lifecycle_gmv) AS total_lifecycle_gmv,
    SAFE_DIVIDE(SUM(contracted_leads), SUM(total_leads)) AS conversion_rate,
    SAFE_DIVIDE(SUM(lifecycle_gmv), SUM(total_leads)) AS lifecycle_gmv_per_lead,
    SAFE_DIVIDE(SUM(lifecycle_gmv), SUM(marketing_spend)) AS gmv_per_spend,
    SAFE_DIVIDE(SUM(marketing_spend), SUM(total_leads)) AS cpl,
    SAFE_DIVIDE(SUM(marketing_spend), SUM(contracted_leads)) AS cost_per_contract
  FROM monthly_panel
  GROUP BY session_source
),

channel_response AS (
  SELECT
    session_source,
    APPROX_QUANTILES(lead_elasticity, 100)[OFFSET(50)] AS median_lead_elasticity,
    APPROX_QUANTILES(contract_elasticity, 100)[OFFSET(50)] AS median_contract_elasticity,
    APPROX_QUANTILES(gmv_elasticity, 100)[OFFSET(50)] AS median_gmv_elasticity,
    COUNTIF(gmv_elasticity > 0) AS positive_gmv_months,
    COUNT(gmv_elasticity) AS observed_elasticity_months,
    SAFE_DIVIDE(COUNTIF(gmv_elasticity > 0), COUNT(gmv_elasticity)) AS positive_gmv_month_share
  FROM elasticity_monthly
  GROUP BY session_source
),

combined AS (
  SELECT
    e.*,
    r.median_lead_elasticity,
    r.median_contract_elasticity,
    r.median_gmv_elasticity,
    r.positive_gmv_months,
    r.observed_elasticity_months,
    r.positive_gmv_month_share
  FROM channel_economic AS e
  LEFT JOIN channel_response AS r
  USING (session_source)
),

-- PERBAIKAN UTAMA: Menghitung nilai benchmark menggunakan fungsi agregasi MURNI (tanpa klausa OVER)
macro_benchmarks AS (
  SELECT
    APPROX_QUANTILES(gmv_per_spend, 100)[OFFSET(50)] AS median_gmv_per_spend,
    APPROX_QUANTILES(conversion_rate, 100)[OFFSET(50)] AS median_conversion,
    APPROX_QUANTILES(median_lead_elasticity, 100)[OFFSET(50)] AS median_channel_lead_elasticity,
    APPROX_QUANTILES(median_gmv_elasticity, 100)[OFFSET(50)] AS median_channel_gmv_elasticity
  FROM combined
),

-- Menggabungkan tabel baris utama dengan nilai benchmark tunggal menggunakan CROSS JOIN
benchmarks AS (
  SELECT
    c.*,
    b.median_gmv_per_spend,
    b.median_conversion,
    b.median_channel_lead_elasticity,
    b.median_channel_gmv_elasticity
  FROM combined c
  CROSS JOIN macro_benchmarks b
)

SELECT
  session_source,
  -- Economic
  ROUND(total_spend, 0) AS total_spend,
  ROUND(gmv_per_spend, 2) AS lifecycle_gmv_per_rp_spend,
  ROUND(cpl, 0) AS CPL,
  ROUND(cost_per_contract, 0) AS cost_per_contract,
  -- Acquisition quality
  total_leads,
  total_contracts,
  ROUND(100 * conversion_rate, 2) AS conversion_rate_pct,
  ROUND(lifecycle_gmv_per_lead, 0) AS lifecycle_gmv_per_lead,
  -- Scalability
  ROUND(median_lead_elasticity, 2) AS median_lead_elasticity,
  ROUND(median_contract_elasticity, 2) AS median_contract_elasticity,
  ROUND(median_gmv_elasticity, 2) AS median_gmv_elasticity,
  ROUND(100 * positive_gmv_month_share, 1) AS positive_gmv_response_pct,
  observed_elasticity_months,
  -- Relative benchmark flags
  CASE
    WHEN gmv_per_spend >= median_gmv_per_spend THEN 'Above Median'
    ELSE 'Below Median'
  END AS economic_efficiency,
  CASE
    WHEN conversion_rate >= median_conversion THEN 'Above Median'
    ELSE 'Below Median'
  END AS acquisition_quality,
  CASE
    WHEN median_lead_elasticity >= median_channel_lead_elasticity THEN 'Above Median'
    ELSE 'Below Median'
  END AS scalability_signal,
  -- ========================================================
  -- FINAL STRATEGIC ROLE
  -- ========================================================
  CASE
    WHEN gmv_per_spend >= median_gmv_per_spend
         AND conversion_rate >= median_conversion
         AND median_lead_elasticity >= 1
         AND median_gmv_elasticity > 0 THEN 'SCALE / CORE'
    WHEN median_lead_elasticity >= 1
         AND median_gmv_elasticity > 1
         AND gmv_per_spend < median_gmv_per_spend THEN 'SELECTIVE SCALE'
    WHEN gmv_per_spend >= median_gmv_per_spend
         AND conversion_rate >= median_conversion
         AND median_lead_elasticity < 1 THEN 'QUALITY / PROTECT'
    WHEN gmv_per_spend >= median_gmv_per_spend
         AND median_gmv_elasticity > 0 THEN 'MAINTAIN / OPTIMIZE'
    WHEN median_gmv_elasticity <= 0
         OR positive_gmv_month_share < 0.60 THEN 'REASSESS / DEPRIORITIZE'
    ELSE 'MAINTAIN / OPTIMIZE'
  END AS strategic_role
FROM benchmarks
ORDER BY
  CASE strategic_role
    WHEN 'SCALE / CORE' THEN 1
    WHEN 'SELECTIVE SCALE' THEN 2
    WHEN 'QUALITY / PROTECT' THEN 3
    WHEN 'MAINTAIN / OPTIMIZE' THEN 4
    WHEN 'REASSESS / DEPRIORITIZE' THEN 5
    ELSE 6
  END;

-- 15. INVESTMENT SCENARIO
  -- ============================================================
-- M2-C — INCREMENTAL MARKETING INVESTMENT SCENARIO MODEL
-- ============================================================
-- Purpose:
-- Estimate expected incremental Leads / Contracts / GMV
-- under +5%, +10%, +15% incremental spend scenarios.
--
-- This is SCENARIO PLANNING, not causal forecasting.
-- ============================================================

WITH channel_baseline AS (

    SELECT 'Referral' AS channel,
        395000000 AS current_spend,
        790 AS current_leads,
        253 AS current_contracts,
        2307171 AS lifecycle_gmv_per_lead,
        32.03 AS conversion_rate_pct,
        1.00 AS observed_lead_elasticity,
        1.03 AS observed_contract_elasticity,
        0.60 AS observed_gmv_elasticity

    UNION ALL

    SELECT 'CPC',
        120000000,
        1064,
        265,
        741861,
        24.91,
        1.19,
        1.17,
        1.33

    UNION ALL

    SELECT 'Direct',
        150200000,
        598,
        168,
        1262387,
        28.09,
        1.00,
        1.35,
        1.46

    UNION ALL

    SELECT 'Organic Search',
        121100000,
        482,
        104,
        1003952,
        21.58,
        1.00,
        1.39,
        1.19

    UNION ALL

    SELECT 'Organic Social',
        116300000,
        463,
        111,
        779449,
        23.97,
        1.00,
        0.79,
        0.65
),

scenarios AS (

    SELECT 'Conservative' AS scenario, 0.50 AS elasticity_factor
    UNION ALL
    SELECT 'Base', 1.00
    UNION ALL
    SELECT 'Upside', 1.25
),

investment_levels AS (

    SELECT '5% Incremental Spend' AS investment_level, 0.05 AS spend_growth
    UNION ALL
    SELECT '10%', 0.10
    UNION ALL
    SELECT '15%', 0.15
),

scenario_model AS (

    SELECT
        b.*,
        s.scenario,
        s.elasticity_factor,
        i.investment_level,
        i.spend_growth,

        -- Incremental spend
        b.current_spend * i.spend_growth
            AS incremental_spend,

        -- Effective lead elasticity
        b.observed_lead_elasticity
        * s.elasticity_factor
            AS effective_lead_elasticity,

        -- Expected lead growth
        i.spend_growth
        * b.observed_lead_elasticity
        * s.elasticity_factor
            AS expected_lead_growth,

        -- Expected incremental leads
        b.current_leads
        * i.spend_growth
        * b.observed_lead_elasticity
        * s.elasticity_factor
            AS incremental_leads,

        -- Expected incremental contracts
        b.current_contracts
        * i.spend_growth
        * b.observed_contract_elasticity
        * s.elasticity_factor
            AS incremental_contracts

    FROM channel_baseline AS b

    CROSS JOIN scenarios AS s

    CROSS JOIN investment_levels AS i
)

SELECT

    channel,

    scenario,

    investment_level,

    ROUND(incremental_spend, 0)
        AS incremental_spend,

    ROUND(
        100 * expected_lead_growth,
        2
    ) AS expected_lead_growth_pct,

    ROUND(
        incremental_leads,
        1
    ) AS expected_incremental_leads,

    ROUND(
        incremental_contracts,
        1
    ) AS expected_incremental_contracts,

    ROUND(
        incremental_leads
        * lifecycle_gmv_per_lead,
        0
    ) AS potential_incremental_lifecycle_gmv,

    -- Quality guardrail:
    -- use historical conversion
    conversion_rate_pct
        AS historical_conversion_guardrail,

    observed_lead_elasticity,
    observed_contract_elasticity,
    observed_gmv_elasticity

FROM scenario_model

ORDER BY
    CASE channel
        WHEN 'Referral' THEN 1
        WHEN 'CPC' THEN 2
        WHEN 'Direct' THEN 3
        WHEN 'Organic Search' THEN 4
        WHEN 'Organic Social' THEN 5
    END,

    CASE scenario
        WHEN 'Conservative' THEN 1
        WHEN 'Base' THEN 2
        WHEN 'Upside' THEN 3
    END,

    spend_growth;
