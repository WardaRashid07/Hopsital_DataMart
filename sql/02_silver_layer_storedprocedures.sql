
-- ============================================================
-- STORED PROCEDURE: silver.sp_load_silver
-- PURPOSE : Reads from bronze, applies all cleaning rules,
--           inserts into silver tables.
-- RUN     : EXEC silver.sp_load_silver
-- ============================================================
CREATE OR ALTER PROCEDURE silver.sp_load_silver AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATETIME = GETDATE();
    PRINT '============================================';
    PRINT 'Silver Layer Load Started: ' + CONVERT(NVARCHAR, @start, 120);
    PRINT '============================================';

    -- --------------------------------------------------------
    -- PATIENTS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.patients...';
    TRUNCATE TABLE silver.patients;
    INSERT INTO silver.patients (
        patient_id, first_name, last_name, full_name, gender,
        birth_date, age, blood_type, city, country,
        phone, email, registration_date, insurance_status, dwh_load_date
    )
    SELECT
        TRY_CAST(patient_id AS INT),
        TRIM(first_name),
        TRIM(last_name),
        TRIM(first_name) + ' ' + TRIM(last_name),
        -- Standardize gender
        CASE UPPER(TRIM(gender))
            WHEN 'M'       THEN 'Male'
            WHEN 'MALE'    THEN 'Male'
            WHEN 'F'       THEN 'Female'
            WHEN 'FEMALE'  THEN 'Female'
            ELSE 'Other'
        END,
        TRY_CAST(birth_date AS DATE),
        -- Derive age from birth_date
        DATEDIFF(YEAR,
            TRY_CAST(birth_date AS DATE),
            GETDATE()),
        TRIM(blood_type),
        TRIM(city),
        TRIM(country),
        TRIM(phone),
        LOWER(TRIM(email)),             -- normalize emails to lowercase
        TRY_CAST(registration_date AS DATE),
        -- Standardize insurance status
        CASE UPPER(TRIM(insurance_status))
            WHEN 'YES'    THEN 'Active'
            WHEN 'Y'      THEN 'Active'
            WHEN '1'      THEN 'Active'
            WHEN 'ACTIVE' THEN 'Active'
            ELSE 'Inactive'
        END,
        GETDATE()
    FROM (
        -- Deduplicate: keep one row per patient_id
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY patient_id
                   ORDER BY registration_date DESC
               ) AS rn
        FROM bronze.patients
        WHERE TRY_CAST(patient_id AS INT) IS NOT NULL  -- drop rows with bad IDs
          AND first_name IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- --------------------------------------------------------
    -- DOCTORS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.doctors...';
    TRUNCATE TABLE silver.doctors;
    INSERT INTO silver.doctors (
        doctor_id, first_name, last_name, full_name,
        specialization, department_id, qualification,
        hire_date, status, phone, dwh_load_date
    )
    SELECT
        TRY_CAST(doctor_id AS INT),
        TRIM(first_name),
        TRIM(last_name),
        TRIM(first_name) + ' ' + TRIM(last_name),
        TRIM(specialization),
        TRY_CAST(department_id AS INT),
        TRIM(qualification),
        TRY_CAST(hire_date AS DATE),
        CASE UPPER(TRIM(status))
            WHEN 'ACTIVE'   THEN 'Active'
            WHEN 'A'        THEN 'Active'
            ELSE 'Inactive'
        END,
        TRIM(phone),
        GETDATE()
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY doctor_id
                   ORDER BY hire_date DESC
               ) AS rn
        FROM bronze.doctors
        WHERE TRY_CAST(doctor_id AS INT) IS NOT NULL
          AND first_name IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- --------------------------------------------------------
    -- DEPARTMENTS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.departments...';
    TRUNCATE TABLE silver.departments;
    INSERT INTO silver.departments (
        department_id, department_name, building,
        floor, head_doctor, established_date, dwh_load_date
    )
    SELECT
        TRY_CAST(department_id AS INT),
        TRIM(department_name),
        TRIM(building),
        TRIM(floor),
        TRIM(head_doctor),
        TRY_CAST(established_date AS DATE),
        GETDATE()
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY department_id
                   ORDER BY established_date DESC
               ) AS rn
        FROM bronze.departments
        WHERE TRY_CAST(department_id AS INT) IS NOT NULL
          AND department_name IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- --------------------------------------------------------
    -- TREATMENTS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.treatments...';
    TRUNCATE TABLE silver.treatments;
    INSERT INTO silver.treatments (
        treatment_id, treatment_name, treatment_type,
        diagnosis_code, diagnosis_name,
        standard_cost, duration_minutes, dwh_load_date
    )
    SELECT
        TRY_CAST(treatment_id AS INT),
        TRIM(treatment_name),
        TRIM(treatment_type),
        UPPER(TRIM(diagnosis_code)),    -- ICD codes are uppercase standard
        TRIM(diagnosis_name),
        TRY_CAST(standard_cost AS DECIMAL(10,2)),
        TRY_CAST(duration_minutes AS INT),
        GETDATE()
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY treatment_id
                   ORDER BY treatment_id
               ) AS rn
        FROM bronze.treatments
        WHERE TRY_CAST(treatment_id AS INT) IS NOT NULL
          AND treatment_name IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- --------------------------------------------------------
    -- INSURANCE PROVIDERS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.insurance_providers...';
    TRUNCATE TABLE silver.insurance_providers;
    INSERT INTO silver.insurance_providers (
        insurance_id, provider_name, plan_type,
        coverage_pct, max_coverage_amount, status, dwh_load_date
    )
    SELECT
        TRY_CAST(insurance_id AS INT),
        TRIM(provider_name),
        TRIM(plan_type),
        TRY_CAST(coverage_pct AS DECIMAL(5,2)),
        TRY_CAST(max_coverage_amount AS DECIMAL(12,2)),
        CASE UPPER(TRIM(status))
            WHEN 'ACTIVE'   THEN 'Active'
            WHEN 'A'        THEN 'Active'
            ELSE 'Inactive'
        END,
        GETDATE()
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY insurance_id
                   ORDER BY insurance_id
               ) AS rn
        FROM bronze.insurance_providers
        WHERE TRY_CAST(insurance_id AS INT) IS NOT NULL
          AND provider_name IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- --------------------------------------------------------
    -- APPOINTMENTS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.appointments...';
    TRUNCATE TABLE silver.appointments;
    INSERT INTO silver.appointments (
        appointment_id, patient_id, doctor_id, department_id,
        treatment_id, appointment_date, appointment_time,
        duration_minutes, status, consultation_fee, notes, dwh_load_date
    )
    SELECT
        TRY_CAST(appointment_id AS INT),
        TRY_CAST(patient_id AS INT),
        TRY_CAST(doctor_id AS INT),
        TRY_CAST(department_id AS INT),
        TRY_CAST(treatment_id AS INT),
        TRY_CAST(appointment_date AS DATE),
        TRIM(appointment_time),
        TRY_CAST(duration_minutes AS INT),
        -- Standardize appointment status
        CASE UPPER(TRIM(status))
            WHEN 'COMPLETED'  THEN 'Completed'
            WHEN 'COMPLETE'   THEN 'Completed'
            WHEN 'SCHEDULED'  THEN 'Scheduled'
            WHEN 'CANCELLED'  THEN 'Cancelled'
            WHEN 'CANCELED'   THEN 'Cancelled'
            WHEN 'NO-SHOW'    THEN 'No-Show'
            WHEN 'NOSHOW'     THEN 'No-Show'
            ELSE TRIM(status)
        END,
        TRY_CAST(consultation_fee AS DECIMAL(10,2)),
        TRIM(notes),
        GETDATE()
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY appointment_id
                   ORDER BY appointment_date DESC
               ) AS rn
        FROM bronze.appointments
        WHERE TRY_CAST(appointment_id AS INT) IS NOT NULL
          AND TRY_CAST(appointment_date AS DATE) IS NOT NULL  -- drop bad dates
          AND TRY_CAST(patient_id AS INT) IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- --------------------------------------------------------
    -- BILLS
    -- --------------------------------------------------------
    PRINT '>> Loading silver.bills...';
    TRUNCATE TABLE silver.bills;
    INSERT INTO silver.bills (
        bill_id, appointment_id, patient_id, doctor_id,
        insurance_id, treatment_id, bill_date,
        total_amount, insurance_covered, patient_paid,
        outstanding_amount, payment_status, dwh_load_date
    )
    SELECT
        TRY_CAST(bill_id AS INT),
        TRY_CAST(appointment_id AS INT),
        TRY_CAST(patient_id AS INT),
        TRY_CAST(doctor_id AS INT),
        TRY_CAST(insurance_id AS INT),
        TRY_CAST(treatment_id AS INT),
        TRY_CAST(bill_date AS DATE),
        TRY_CAST(total_amount AS DECIMAL(12,2)),
        ISNULL(TRY_CAST(insurance_covered AS DECIMAL(12,2)), 0),
        ISNULL(TRY_CAST(patient_paid AS DECIMAL(12,2)), 0),
        ISNULL(TRY_CAST(outstanding_amount AS DECIMAL(12,2)), 0),
        -- Standardize payment status
        CASE UPPER(TRIM(payment_status))
            WHEN 'PAID'     THEN 'Paid'
            WHEN 'PARTIAL'  THEN 'Partial'
            WHEN 'PENDING'  THEN 'Pending'
            WHEN 'OVERDUE'  THEN 'Overdue'
            ELSE TRIM(payment_status)
        END,
        GETDATE()
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY bill_id
                   ORDER BY bill_date DESC
               ) AS rn
        FROM bronze.bills
        WHERE TRY_CAST(bill_id AS INT) IS NOT NULL
          AND TRY_CAST(total_amount AS DECIMAL(12,2)) > 0   -- drop zero/null bills
          AND TRY_CAST(bill_date AS DATE) IS NOT NULL
    ) t
    WHERE rn = 1;
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    PRINT '============================================';
    PRINT 'Silver Layer Load Completed.';
    PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @start, GETDATE()) AS NVARCHAR) + ' seconds';
    PRINT '============================================';
END;
GO

-- ============================================================
-- RUN THE PROCEDURE
-- ============================================================
EXEC silver.sp_load_silver;
GO

-- ============================================================
-- VERIFICATION QUERIES
-- ============================================================

-- Row counts (should match bronze closely, slightly less after cleaning)
SELECT 'silver.patients'             AS tbl, COUNT(*) AS rows FROM silver.patients
UNION ALL SELECT 'silver.doctors',           COUNT(*) FROM silver.doctors
UNION ALL SELECT 'silver.departments',       COUNT(*) FROM silver.departments
UNION ALL SELECT 'silver.treatments',        COUNT(*) FROM silver.treatments
UNION ALL SELECT 'silver.insurance_providers', COUNT(*) FROM silver.insurance_providers
UNION ALL SELECT 'silver.appointments',      COUNT(*) FROM silver.appointments
UNION ALL SELECT 'silver.bills',             COUNT(*) FROM silver.bills;

-- Check gender standardization worked
SELECT DISTINCT gender FROM silver.patients;

-- Check status standardization worked
SELECT DISTINCT status FROM silver.appointments;
SELECT DISTINCT payment_status FROM silver.bills;

-- Check data types are correct (should show actual dates, not strings)
SELECT TOP 3 patient_id, full_name, birth_date, age, registration_date
FROM silver.patients;

-- Check for any NULLs in critical columns
SELECT COUNT(*) AS null_appointment_dates
FROM silver.appointments
WHERE appointment_date IS NULL;
