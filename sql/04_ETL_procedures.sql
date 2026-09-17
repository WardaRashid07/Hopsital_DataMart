-- ============================================================
-- HOSPITAL DATA MART
-- LAYER    : ETL Procedures (Silver → Gold)
-- DATABASE : HospitalMart
-- PURPOSE  : Load all Gold dimension and fact tables from Silver.
--            Handles SCD Type 1 (overwrite) and SCD Type 2 (history)
--            Includes DimDate population and master ETL procedure.
-- RUN      : EXEC dbo.sp_run_full_etl
-- ============================================================
USE HospitalMart;
GO

-- ============================================================
-- PROCEDURE 1: gold.sp_load_dim_date
-- Type   : Static — run once, covers 2010-2035
-- Logic  : Populates date dimension with calendar attributes
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_dim_date AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.dim_date...';
    DECLARE @d DATE = '2010-01-01';
    DECLARE @end DATE = '2035-12-31';
    WHILE @d <= @end
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM gold.dim_date
            WHERE date_key = CONVERT(INT, FORMAT(@d, 'yyyyMMdd'))
        )
        BEGIN
            INSERT INTO gold.dim_date (
                date_key, full_date, year, quarter, quarter_name,
                month, month_name, day_of_month, day_of_week,
                day_name, week_number, is_weekend
            )
            VALUES (
                CONVERT(INT, FORMAT(@d, 'yyyyMMdd')),
                @d,
                YEAR(@d),
                DATEPART(QUARTER, @d),
                'Q' + CAST(DATEPART(QUARTER, @d) AS NVARCHAR(1)),
                MONTH(@d),
                FORMAT(@d, 'MMMM'),
                DAY(@d),
                DATEPART(WEEKDAY, @d),
                FORMAT(@d, 'dddd'),
                DATEPART(WEEK, @d),
                CASE WHEN DATEPART(WEEKDAY, @d) IN (1, 7) THEN 1 ELSE 0 END
            );
        END
        SET @d = DATEADD(DAY, 1, @d);
    END
    PRINT '   Rows loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR);
    PRINT '   dim_date covers 2010-01-01 to 2035-12-31';
END;
GO

-- ============================================================
-- PROCEDURE 2: gold.sp_load_dim_department
-- Type   : SCD Type 1 — overwrite changes, no history
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_dim_department AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.dim_department (SCD Type 1)...';
    UPDATE d
    SET
        d.department_name   = s.department_name,
        d.building          = s.building,
        d.floor             = s.floor,
        d.head_doctor       = s.head_doctor,
        d.established_date  = s.established_date,
        d.dwh_load_date     = GETDATE()
    FROM gold.dim_department d
    JOIN silver.departments s ON d.department_id = s.department_id;

    INSERT INTO gold.dim_department (
        department_id, department_name, building,
        floor, head_doctor, established_date
    )
    SELECT
        s.department_id, s.department_name, s.building,
        s.floor, s.head_doctor, s.established_date
    FROM silver.departments s
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.dim_department d
        WHERE d.department_id = s.department_id
    );
    PRINT '   dim_department loaded.';
END;
GO

-- ============================================================
-- PROCEDURE 3: gold.sp_load_dim_treatment
-- Type   : SCD Type 1 — overwrite changes, no history
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_dim_treatment AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.dim_treatment (SCD Type 1)...';
    UPDATE d
    SET
        d.treatment_name    = s.treatment_name,
        d.treatment_type    = s.treatment_type,
        d.diagnosis_code    = s.diagnosis_code,
        d.diagnosis_name    = s.diagnosis_name,
        d.standard_cost     = s.standard_cost,
        d.duration_minutes  = s.duration_minutes,
        d.dwh_load_date     = GETDATE()
    FROM gold.dim_treatment d
    JOIN silver.treatments s ON d.treatment_id = s.treatment_id;

    INSERT INTO gold.dim_treatment (
        treatment_id, treatment_name, treatment_type,
        diagnosis_code, diagnosis_name,
        standard_cost, duration_minutes
    )
    SELECT
        s.treatment_id, s.treatment_name, s.treatment_type,
        s.diagnosis_code, s.diagnosis_name,
        s.standard_cost, s.duration_minutes
    FROM silver.treatments s
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.dim_treatment d
        WHERE d.treatment_id = s.treatment_id
    );
    PRINT '   dim_treatment loaded.';
END;
GO

-- ============================================================
-- PROCEDURE 4: gold.sp_load_dim_insurance
-- Type   : SCD Type 1 — overwrite changes, no history
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_dim_insurance AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.dim_insurance (SCD Type 1)...';
    UPDATE d
    SET
        d.provider_name       = s.provider_name,
        d.plan_type           = s.plan_type,
        d.coverage_pct        = s.coverage_pct,
        d.max_coverage_amount = s.max_coverage_amount,
        d.status              = s.status,
        d.dwh_load_date       = GETDATE()
    FROM gold.dim_insurance d
    JOIN silver.insurance_providers s ON d.insurance_id = s.insurance_id;

    INSERT INTO gold.dim_insurance (
        insurance_id, provider_name, plan_type,
        coverage_pct, max_coverage_amount, status
    )
    SELECT
        s.insurance_id, s.provider_name, s.plan_type,
        s.coverage_pct, s.max_coverage_amount, s.status
    FROM silver.insurance_providers s
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.dim_insurance d
        WHERE d.insurance_id = s.insurance_id
    );
    PRINT '   dim_insurance loaded.';
END;
GO

-- ============================================================
-- PROCEDURE 5: gold.sp_load_dim_patient
-- Type   : SCD Type 2 — full history tracking
-- Tracks : insurance_status, city, country changes
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_dim_patient AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.dim_patient (SCD Type 2)...';

    UPDATE gold.dim_patient
    SET
        end_date      = CAST(GETDATE() AS DATE),
        is_current    = 0
    WHERE is_current = 1
      AND patient_id IN (
          SELECT s.patient_id
          FROM silver.patients s
          JOIN gold.dim_patient d
            ON s.patient_id = d.patient_id
           AND d.is_current = 1
          WHERE
              ISNULL(s.insurance_status, '') <> ISNULL(d.insurance_status, '')
           OR ISNULL(s.city, '')             <> ISNULL(d.city, '')
           OR ISNULL(s.country, '')          <> ISNULL(d.country, '')
      );

    INSERT INTO gold.dim_patient (
        patient_id, first_name, last_name, full_name, gender,
        birth_date, age, blood_type, city, country,
        insurance_status, registration_date,
        effective_date, end_date, is_current
    )
    SELECT
        s.patient_id, s.first_name, s.last_name, s.full_name, s.gender,
        s.birth_date, s.age, s.blood_type, s.city, s.country,
        s.insurance_status, s.registration_date,
        CAST(GETDATE() AS DATE),
        NULL,
        1
    FROM silver.patients s
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.dim_patient d
        WHERE d.patient_id = s.patient_id
          AND d.is_current = 1
    );
    PRINT '   dim_patient loaded.';
END;
GO

-- ============================================================
-- PROCEDURE 6: gold.sp_load_dim_doctor
-- Type   : SCD Type 2 — full history tracking
-- Tracks : specialization, department_id, status changes
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_dim_doctor AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.dim_doctor (SCD Type 2)...';

    UPDATE gold.dim_doctor
    SET
        end_date   = CAST(GETDATE() AS DATE),
        is_current = 0
    WHERE is_current = 1
      AND doctor_id IN (
          SELECT s.doctor_id
          FROM silver.doctors s
          JOIN gold.dim_doctor d
            ON s.doctor_id = d.doctor_id
           AND d.is_current = 1
          WHERE
              ISNULL(s.specialization, '') <> ISNULL(d.specialization, '')
           OR ISNULL(s.department_id, 0)  <> ISNULL(d.department_id, 0)
           OR ISNULL(s.status, '')         <> ISNULL(d.status, '')
      );

    INSERT INTO gold.dim_doctor (
        doctor_id, first_name, last_name, full_name,
        specialization, department_id, qualification,
        hire_date, status,
        effective_date, end_date, is_current
    )
    SELECT
        s.doctor_id, s.first_name, s.last_name, s.full_name,
        s.specialization, s.department_id, s.qualification,
        s.hire_date, s.status,
        CAST(GETDATE() AS DATE),
        NULL,
        1
    FROM silver.doctors s
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.dim_doctor d
        WHERE d.doctor_id = s.doctor_id
          AND d.is_current = 1
    );
    PRINT '   dim_doctor loaded.';
END;
GO

-- ============================================================
-- PROCEDURE 7: gold.sp_load_fact_appointments
-- Logic  : UPDATE existing rows whose status/duration/fee changed
--          INSERT rows not yet in the fact table
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_fact_appointments AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.fact_appointments...';

    UPDATE f
    SET
        f.appointment_status = a.status,
        f.duration_minutes   = a.duration_minutes,
        f.consultation_fee   = a.consultation_fee,
        f.dwh_load_date      = GETDATE()
    FROM gold.fact_appointments f
    JOIN silver.appointments a ON f.appointment_id = a.appointment_id
    WHERE
        ISNULL(f.appointment_status, '') <> ISNULL(a.status, '')
     OR ISNULL(f.duration_minutes, -1)   <> ISNULL(a.duration_minutes, -1)
     OR ISNULL(f.consultation_fee, -1)   <> ISNULL(a.consultation_fee, -1);
    PRINT '   Rows updated: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    INSERT INTO gold.fact_appointments WITH (TABLOCK) (
        appointment_id, date_key, patient_key, doctor_key,
        department_key, treatment_key, appointment_time,
        appointment_status, duration_minutes, consultation_fee
    )
    SELECT
        a.appointment_id,
        CONVERT(INT, FORMAT(a.appointment_date, 'yyyyMMdd')),
        p.patient_key,
        d.doctor_key,
        dept.department_key,
        t.treatment_key,
        a.appointment_time,
        a.status,
        a.duration_minutes,
        a.consultation_fee
    FROM silver.appointments a
    JOIN gold.dim_patient p
        ON a.patient_id = p.patient_id
       AND p.is_current = 1
    JOIN gold.dim_doctor d
        ON a.doctor_id = d.doctor_id
       AND d.is_current = 1
    JOIN gold.dim_department dept
        ON a.department_id = dept.department_id
    JOIN gold.dim_treatment t
        ON a.treatment_id = t.treatment_id
    JOIN gold.dim_date dd
        ON dd.date_key = CONVERT(INT, FORMAT(a.appointment_date, 'yyyyMMdd'))
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.fact_appointments f
        WHERE f.appointment_id = a.appointment_id
    );
    PRINT '   Rows inserted: ' + CAST(@@ROWCOUNT AS NVARCHAR);
END;
GO

-- ============================================================
-- PROCEDURE 8: gold.sp_load_fact_billing
-- Logic  : UPDATE existing rows whose payment/amounts changed
--          INSERT rows not yet in the fact table
-- ============================================================
CREATE OR ALTER PROCEDURE gold.sp_load_fact_billing AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Loading gold.fact_billing...';

    UPDATE f
    SET
        f.payment_status     = b.payment_status,
        f.total_amount       = b.total_amount,
        f.insurance_covered  = b.insurance_covered,
        f.patient_paid       = b.patient_paid,
        f.outstanding_amount = b.outstanding_amount,
        f.dwh_load_date      = GETDATE()
    FROM gold.fact_billing f
    JOIN silver.bills b ON f.bill_id = b.bill_id
    WHERE
        ISNULL(f.payment_status, '')      <> ISNULL(b.payment_status, '')
     OR ISNULL(f.total_amount, -1)        <> ISNULL(b.total_amount, -1)
     OR ISNULL(f.insurance_covered, -1)   <> ISNULL(b.insurance_covered, -1)
     OR ISNULL(f.patient_paid, -1)        <> ISNULL(b.patient_paid, -1)
     OR ISNULL(f.outstanding_amount, -1)  <> ISNULL(b.outstanding_amount, -1);
    PRINT '   Rows updated: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    INSERT INTO gold.fact_billing WITH (TABLOCK) (
        bill_id, appointment_id, date_key,
        patient_key, doctor_key, treatment_key, insurance_key,
        payment_status, total_amount, insurance_covered,
        patient_paid, outstanding_amount
    )
    SELECT
        b.bill_id,
        b.appointment_id,
        CONVERT(INT, FORMAT(b.bill_date, 'yyyyMMdd')),
        p.patient_key,
        d.doctor_key,
        t.treatment_key,
        i.insurance_key,
        b.payment_status,
        b.total_amount,
        b.insurance_covered,
        b.patient_paid,
        b.outstanding_amount
    FROM silver.bills b
    JOIN gold.dim_patient p
        ON b.patient_id = p.patient_id
       AND p.is_current = 1
    JOIN gold.dim_doctor d
        ON b.doctor_id = d.doctor_id
       AND d.is_current = 1
    JOIN gold.dim_treatment t
        ON b.treatment_id = t.treatment_id
    JOIN gold.dim_insurance i
        ON b.insurance_id = i.insurance_id
    JOIN gold.dim_date dd
        ON dd.date_key = CONVERT(INT, FORMAT(b.bill_date, 'yyyyMMdd'))
    WHERE NOT EXISTS (
        SELECT 1 FROM gold.fact_billing f
        WHERE f.bill_id = b.bill_id
    );
    PRINT '   Rows inserted: ' + CAST(@@ROWCOUNT AS NVARCHAR);
END;
GO

-- ============================================================
-- MASTER PROCEDURE: dbo.sp_run_full_etl
-- PURPOSE : Runs the complete Silver → Gold pipeline atomically.
--           All steps succeed together, or none are kept.
-- RUN     : EXEC dbo.sp_run_full_etl
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_run_full_etl AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATETIME = GETDATE();
    DECLARE @error_message NVARCHAR(4000);
    DECLARE @error_severity INT;
    DECLARE @error_state INT;

    PRINT '============================================';
    PRINT 'Full ETL Started: ' + CONVERT(NVARCHAR, @start, 120);
    PRINT '============================================';

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC gold.sp_load_dim_date;
        EXEC gold.sp_load_dim_department;
        EXEC gold.sp_load_dim_treatment;
        EXEC gold.sp_load_dim_insurance;
        EXEC gold.sp_load_dim_patient;
        EXEC gold.sp_load_dim_doctor;
        EXEC gold.sp_load_fact_appointments;
        EXEC gold.sp_load_fact_billing;

        COMMIT TRANSACTION;

        PRINT '============================================';
        PRINT 'Full ETL Completed in: ' +
              CAST(DATEDIFF(SECOND, @start, GETDATE()) AS NVARCHAR) + ' seconds';
        PRINT '============================================';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SELECT
            @error_message  = ERROR_MESSAGE(),
            @error_severity = ERROR_SEVERITY(),
            @error_state    = ERROR_STATE();

        PRINT '============================================';
        PRINT 'ETL FAILED — all changes rolled back.';
        PRINT 'Error: ' + @error_message;
        PRINT '============================================';

        RAISERROR(@error_message, @error_severity, @error_state);
    END CATCH
END;
GO

-- ============================================================
-- RUN THE FULL ETL NOW
-- ============================================================
EXEC dbo.sp_run_full_etl;
GO

-- ============================================================
-- VERIFICATION QUERIES — run after ETL completes
-- ============================================================
SELECT 'gold.dim_date'            AS tbl, COUNT(*) AS rows FROM gold.dim_date
UNION ALL SELECT 'gold.dim_patient',       COUNT(*) FROM gold.dim_patient
UNION ALL SELECT 'gold.dim_doctor',        COUNT(*) FROM gold.dim_doctor
UNION ALL SELECT 'gold.dim_department',    COUNT(*) FROM gold.dim_department
UNION ALL SELECT 'gold.dim_treatment',     COUNT(*) FROM gold.dim_treatment
UNION ALL SELECT 'gold.dim_insurance',     COUNT(*) FROM gold.dim_insurance
UNION ALL SELECT 'gold.fact_appointments', COUNT(*) FROM gold.fact_appointments
UNION ALL SELECT 'gold.fact_billing',      COUNT(*) FROM gold.fact_billing;

-- SCD2 check: no patient/doctor should have 2 is_current=1 rows
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