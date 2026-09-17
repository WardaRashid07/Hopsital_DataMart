-- ============================================================
-- HOSPITAL DATA MART
-- LAYER    : Analytics (Reporting Layer)
-- DATABASE : HospitalDataMart
-- PURPOSE  : Business-facing views + KPI queries + data quality
--            These views sit on top of Gold and answer real
--            business questions without exposing raw joins.
-- ============================================================

USE HospitalMart;
GO

-- ============================================================
-- PART A: REPORTING VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW 1: vw_monthly_appointments
-- Business Q : How many appointments per month?
--              What is monthly revenue from consultations?
--              Which months are busiest?
-- ------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_monthly_appointments AS
SELECT
    d.year,
    d.quarter_name,
    d.month,
    d.month_name,
    COUNT(fa.appointment_key)                       AS total_appointments,
    COUNT(CASE WHEN fa.appointment_status = 'Completed'  THEN 1 END) AS completed,
    COUNT(CASE WHEN fa.appointment_status = 'Cancelled'  THEN 1 END) AS cancelled,
    COUNT(CASE WHEN fa.appointment_status = 'No-Show'    THEN 1 END) AS no_shows,
    COUNT(CASE WHEN fa.appointment_status = 'Scheduled'  THEN 1 END) AS scheduled,
    -- Completion rate
    CAST(
        COUNT(CASE WHEN fa.appointment_status = 'Completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(fa.appointment_key), 0)
    AS DECIMAL(5,2))                                AS completion_rate_pct,
    -- Cancellation rate
    CAST(
        COUNT(CASE WHEN fa.appointment_status = 'Cancelled' THEN 1 END) * 100.0
        / NULLIF(COUNT(fa.appointment_key), 0)
    AS DECIMAL(5,2))                                AS cancellation_rate_pct,
    -- Revenue measures
    SUM(fa.consultation_fee)                        AS total_consultation_revenue,
    CAST(AVG(fa.consultation_fee) AS DECIMAL(10,2)) AS avg_consultation_fee,
    CAST(AVG(fa.duration_minutes) AS DECIMAL(6,2))  AS avg_duration_minutes,
    COUNT(DISTINCT fa.patient_key)                  AS unique_patients
FROM gold.fact_appointments fa
JOIN gold.dim_date d ON fa.date_key = d.date_key
GROUP BY d.year, d.quarter_name, d.month, d.month_name;
GO

-- ------------------------------------------------------------
-- VIEW 2: vw_doctor_performance
-- Business Q : Which doctor sees the most patients?
--              Who generates the most revenue?
--              Which specialization has highest completion rate?
-- ------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_doctor_performance AS
SELECT
    doc.doctor_id,
    doc.full_name                                   AS doctor_name,
    doc.specialization,
    doc.qualification,
    doc.status,
    -- Appointment metrics
    COUNT(fa.appointment_key)                       AS total_appointments,
    COUNT(CASE WHEN fa.appointment_status = 'Completed' THEN 1 END) AS completed_appointments,
    COUNT(CASE WHEN fa.appointment_status = 'Cancelled' THEN 1 END) AS cancelled_appointments,
    CAST(
        COUNT(CASE WHEN fa.appointment_status = 'Completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(fa.appointment_key), 0)
    AS DECIMAL(5,2))                                AS completion_rate_pct,
    -- Revenue metrics
    SUM(fa.consultation_fee)                        AS total_revenue,
    CAST(AVG(fa.consultation_fee) AS DECIMAL(10,2)) AS avg_consultation_fee,
    CAST(AVG(fa.duration_minutes) AS DECIMAL(6,2))  AS avg_duration_minutes,
    -- Patient metrics
    COUNT(DISTINCT fa.patient_key)                  AS unique_patients
FROM gold.fact_appointments fa
JOIN gold.dim_doctor doc ON fa.doctor_key = doc.doctor_key
                         AND doc.is_current = 1
GROUP BY
    doc.doctor_id, doc.full_name, doc.specialization,
    doc.qualification, doc.status;
GO

-- ------------------------------------------------------------
-- VIEW 3: vw_department_summary
-- Business Q : Which department is busiest?
--              Which has highest cancellation rate?
--              Where should hospital invest more resources?
-- ------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_department_summary AS
SELECT
    dept.department_id,
    dept.department_name,
    dept.building,
    dept.floor,
    dept.head_doctor,
    -- Appointment metrics
    COUNT(fa.appointment_key)                       AS total_appointments,
    COUNT(CASE WHEN fa.appointment_status = 'Completed' THEN 1 END) AS completed,
    COUNT(CASE WHEN fa.appointment_status = 'Cancelled' THEN 1 END) AS cancelled,
    COUNT(CASE WHEN fa.appointment_status = 'No-Show'   THEN 1 END) AS no_shows,
    CAST(
        COUNT(CASE WHEN fa.appointment_status = 'Completed' THEN 1 END) * 100.0
        / NULLIF(COUNT(fa.appointment_key), 0)
    AS DECIMAL(5,2))                                AS completion_rate_pct,
    -- Revenue metrics
    SUM(fa.consultation_fee)                        AS total_revenue,
    CAST(AVG(fa.consultation_fee) AS DECIMAL(10,2)) AS avg_consultation_fee,
    CAST(AVG(fa.duration_minutes) AS DECIMAL(6,2))  AS avg_duration_minutes,
    -- Patient metrics
    COUNT(DISTINCT fa.patient_key)                  AS unique_patients,
    COUNT(DISTINCT fa.doctor_key)                   AS active_doctors
FROM gold.fact_appointments fa
JOIN gold.dim_department dept ON fa.department_key = dept.department_key
GROUP BY
    dept.department_id, dept.department_name,
    dept.building, dept.floor, dept.head_doctor;
GO

-- ------------------------------------------------------------
-- VIEW 4: vw_billing_recovery
-- Business Q : What is total revenue billed vs collected?
--              Which insurance provider pays the most?
--              What is the outstanding debt by provider?
--              Which payment status is most common?
-- ------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_billing_recovery AS
SELECT
    i.insurance_id,
    i.provider_name,
    i.plan_type,
    i.coverage_pct                                  AS contracted_coverage_pct,
    i.status                                        AS provider_status,
    -- Volume metrics
    COUNT(fb.billing_key)                           AS total_bills,
    COUNT(CASE WHEN fb.payment_status = 'Paid'    THEN 1 END) AS paid_bills,
    COUNT(CASE WHEN fb.payment_status = 'Partial' THEN 1 END) AS partial_bills,
    COUNT(CASE WHEN fb.payment_status = 'Pending' THEN 1 END) AS pending_bills,
    COUNT(CASE WHEN fb.payment_status = 'Overdue' THEN 1 END) AS overdue_bills,
    -- Financial metrics
    SUM(fb.total_amount)                            AS total_billed,
    SUM(fb.insurance_covered)                       AS total_insurance_covered,
    SUM(fb.patient_paid)                            AS total_patient_paid,
    SUM(fb.outstanding_amount)                      AS total_outstanding,
    -- Recovery rate (avg of computed column)
    CAST(AVG(fb.recovery_rate) AS DECIMAL(5,2))     AS avg_recovery_rate_pct,
    -- Actual vs contracted coverage
    CAST(
        SUM(fb.insurance_covered) * 100.0
        / NULLIF(SUM(fb.total_amount), 0)
    AS DECIMAL(5,2))                                AS actual_coverage_pct
FROM gold.fact_billing fb
JOIN gold.dim_insurance i ON fb.insurance_key = i.insurance_key
GROUP BY
    i.insurance_id, i.provider_name, i.plan_type,
    i.coverage_pct, i.status;
GO

-- ------------------------------------------------------------
-- VIEW 5: vw_patient_analysis
-- Business Q : Who are the most frequent patients?
--              Which country has most patients?
--              What is patient lifetime billing value?
-- ------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_patient_analysis AS
SELECT
    p.patient_id,
    p.full_name,
    p.gender,
    p.age,
    p.blood_type,
    p.country,
    p.insurance_status,
    p.registration_date,
    -- Appointment metrics
    COUNT(DISTINCT fa.appointment_key)              AS total_appointments,
    COUNT(DISTINCT CASE WHEN fa.appointment_status = 'Completed'
          THEN fa.appointment_key END)              AS completed_appointments,
    SUM(fa.consultation_fee)                        AS total_consultation_fees,
    -- Billing metrics
    COUNT(DISTINCT fb.billing_key)                  AS total_bills,
    SUM(fb.total_amount)                            AS lifetime_billed,
    SUM(fb.patient_paid)                            AS lifetime_paid,
    SUM(fb.outstanding_amount)                      AS total_outstanding,
    -- First and last visit
    MIN(da.full_date)                               AS first_visit_date,
    MAX(da.full_date)                               AS last_visit_date
FROM gold.dim_patient p
LEFT JOIN gold.fact_appointments fa ON p.patient_key = fa.patient_key
LEFT JOIN gold.fact_billing fb      ON p.patient_key = fb.patient_key
LEFT JOIN gold.dim_date da          ON fa.date_key   = da.date_key
WHERE p.is_current = 1
GROUP BY
    p.patient_id, p.full_name, p.gender, p.age,
    p.blood_type, p.country, p.insurance_status,
    p.registration_date;
GO











-- ============================================================
-- PART C: DATA QUALITY CHECK PROCEDURE
-- Run this after every ETL to validate Gold layer integrity
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_data_quality_check AS
BEGIN
    SET NOCOUNT ON;
    PRINT '============================================';
    PRINT 'Data Quality Check: ' + CONVERT(NVARCHAR, GETDATE(), 120);
    PRINT '============================================';

    -- CHECK 1: Row counts across all Gold tables
    PRINT '--- Row Counts ---';
    SELECT
        'gold.dim_date'             AS tbl, COUNT(*) AS rows FROM gold.dim_date
    UNION ALL SELECT 'gold.dim_patient',        COUNT(*) FROM gold.dim_patient
    UNION ALL SELECT 'gold.dim_doctor',         COUNT(*) FROM gold.dim_doctor
    UNION ALL SELECT 'gold.dim_department',     COUNT(*) FROM gold.dim_department
    UNION ALL SELECT 'gold.dim_treatment',      COUNT(*) FROM gold.dim_treatment
    UNION ALL SELECT 'gold.dim_insurance',      COUNT(*) FROM gold.dim_insurance
    UNION ALL SELECT 'gold.fact_appointments',  COUNT(*) FROM gold.fact_appointments
    UNION ALL SELECT 'gold.fact_billing',       COUNT(*) FROM gold.fact_billing;

    -- CHECK 2: NULL checks on fact table foreign keys
    PRINT '--- NULL Foreign Keys in fact_appointments ---';
    SELECT
        SUM(CASE WHEN date_key       IS NULL THEN 1 ELSE 0 END) AS null_date_key,
        SUM(CASE WHEN patient_key    IS NULL THEN 1 ELSE 0 END) AS null_patient_key,
        SUM(CASE WHEN doctor_key     IS NULL THEN 1 ELSE 0 END) AS null_doctor_key,
        SUM(CASE WHEN department_key IS NULL THEN 1 ELSE 0 END) AS null_department_key,
        SUM(CASE WHEN treatment_key  IS NULL THEN 1 ELSE 0 END) AS null_treatment_key
    FROM gold.fact_appointments;

    PRINT '--- NULL Foreign Keys in fact_billing ---';
    SELECT
        SUM(CASE WHEN date_key      IS NULL THEN 1 ELSE 0 END) AS null_date_key,
        SUM(CASE WHEN patient_key   IS NULL THEN 1 ELSE 0 END) AS null_patient_key,
        SUM(CASE WHEN doctor_key    IS NULL THEN 1 ELSE 0 END) AS null_doctor_key,
        SUM(CASE WHEN treatment_key IS NULL THEN 1 ELSE 0 END) AS null_treatment_key,
        SUM(CASE WHEN insurance_key IS NULL THEN 1 ELSE 0 END) AS null_insurance_key
    FROM gold.fact_billing;

    -- CHECK 3: Negative or zero measures
    PRINT '--- Invalid Measures ---';
    SELECT
        SUM(CASE WHEN consultation_fee < 0  THEN 1 ELSE 0 END) AS negative_fees,
        SUM(CASE WHEN duration_minutes <= 0 THEN 1 ELSE 0 END) AS zero_duration
    FROM gold.fact_appointments;

    SELECT
        SUM(CASE WHEN total_amount <= 0       THEN 1 ELSE 0 END) AS zero_total,
        SUM(CASE WHEN outstanding_amount < 0  THEN 1 ELSE 0 END) AS negative_outstanding,
        SUM(CASE WHEN insurance_covered < 0   THEN 1 ELSE 0 END) AS negative_covered
    FROM gold.fact_billing;

    -- CHECK 4: SCD2 integrity
    -- No patient or doctor should have more than 1 is_current=1 row
    PRINT '--- SCD2 Integrity (should return 0 rows) ---';
    SELECT patient_id, COUNT(*) AS current_rows
    FROM gold.dim_patient
    WHERE is_current = 1
    GROUP BY patient_id
    HAVING COUNT(*) > 1;

    SELECT doctor_id, COUNT(*) AS current_rows
    FROM gold.dim_doctor
    WHERE is_current = 1
    GROUP BY doctor_id
    HAVING COUNT(*) > 1;

    -- CHECK 5: Date range validation
    PRINT '--- Date Range in Facts ---';
    SELECT
        MIN(full_date) AS earliest_appointment,
        MAX(full_date) AS latest_appointment
    FROM gold.fact_appointments fa
    JOIN gold.dim_date d ON fa.date_key = d.date_key;

    SELECT
        MIN(full_date) AS earliest_bill,
        MAX(full_date) AS latest_bill
    FROM gold.fact_billing fb
    JOIN gold.dim_date d ON fb.date_key = d.date_key;

    PRINT '============================================';
    PRINT 'Data Quality Check Complete.';
    PRINT 'All NULL counts and SCD2 violations should be 0.';
    PRINT '============================================';
END;
GO

-- ============================================================
-- RUN DATA QUALITY CHECK NOW
-- ============================================================
EXEC gold.sp_data_quality_check;
GO