USE HospitalMart;
GO

CREATE OR ALTER PROCEDURE bronze.sp_load_bronze
    @source_folder NVARCHAR(400) = 'D:\User\warda\Downloads\'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @start DATETIME = GETDATE();
    DECLARE @sql NVARCHAR(MAX);
    PRINT '=== Bronze Load Started: ' + CONVERT(NVARCHAR, @start, 120) + ' ===';

    -- ---------------- patients ----------------
    PRINT '>> Loading bronze.patients...';
    TRUNCATE TABLE bronze.patients_stg;
    SET @sql = N'BULK INSERT bronze.patients_stg FROM ''' + @source_folder + N'patients.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.patients;
    INSERT INTO bronze.patients (
        patient_id, first_name, last_name, gender, birth_date, blood_type,
        city, country, phone, email, registration_date, insurance_status,
        dwh_source, dwh_load_date
    )
    SELECT
        patient_id, first_name, last_name, gender, birth_date, blood_type,
        city, country, phone, email, registration_date, insurance_status,
        'patients.csv', GETDATE()
    FROM bronze.patients_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- ---------------- doctors ----------------
    PRINT '>> Loading bronze.doctors...';
    TRUNCATE TABLE bronze.doctors_stg;
    SET @sql = N'BULK INSERT bronze.doctors_stg FROM ''' + @source_folder + N'doctors.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.doctors;
    INSERT INTO bronze.doctors (
        doctor_id, first_name, last_name, specialization, department_id,
        qualification, hire_date, status, phone, dwh_source, dwh_load_date
    )
    SELECT
        doctor_id, first_name, last_name, specialization, department_id,
        qualification, hire_date, status, phone, 'doctors.csv', GETDATE()
    FROM bronze.doctors_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- ---------------- departments ----------------
    PRINT '>> Loading bronze.departments...';
    TRUNCATE TABLE bronze.departments_stg;
    SET @sql = N'BULK INSERT bronze.departments_stg FROM ''' + @source_folder + N'departments.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.departments;
    INSERT INTO bronze.departments (
        department_id, department_name, building, floor, head_doctor,
        established_date, dwh_source, dwh_load_date
    )
    SELECT
        department_id, department_name, building, floor, head_doctor,
        established_date, 'departments.csv', GETDATE()
    FROM bronze.departments_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- ---------------- treatments ----------------
    PRINT '>> Loading bronze.treatments...';
    TRUNCATE TABLE bronze.treatments_stg;
    SET @sql = N'BULK INSERT bronze.treatments_stg FROM ''' + @source_folder + N'treatments.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.treatments;
    INSERT INTO bronze.treatments (
        treatment_id, treatment_name, treatment_type, diagnosis_code,
        diagnosis_name, standard_cost, duration_minutes, dwh_source, dwh_load_date
    )
    SELECT
        treatment_id, treatment_name, treatment_type, diagnosis_code,
        diagnosis_name, standard_cost, duration_minutes, 'treatments.csv', GETDATE()
    FROM bronze.treatments_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- ---------------- insurance_providers ----------------
    PRINT '>> Loading bronze.insurance_providers...';
    TRUNCATE TABLE bronze.insurance_providers_stg;
    SET @sql = N'BULK INSERT bronze.insurance_providers_stg FROM ''' + @source_folder + N'insurance_providers.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.insurance_providers;
    INSERT INTO bronze.insurance_providers (
        insurance_id, provider_name, plan_type, coverage_pct,
        max_coverage_amount, status, dwh_source, dwh_load_date
    )
    SELECT
        insurance_id, provider_name, plan_type, coverage_pct,
        max_coverage_amount, status, 'insurance_providers.csv', GETDATE()
    FROM bronze.insurance_providers_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- ---------------- appointments ----------------
    PRINT '>> Loading bronze.appointments...';
    TRUNCATE TABLE bronze.appointments_stg;
    SET @sql = N'BULK INSERT bronze.appointments_stg FROM ''' + @source_folder + N'appointments.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.appointments;
    INSERT INTO bronze.appointments (
        appointment_id, patient_id, doctor_id, department_id, treatment_id,
        appointment_date, appointment_time, duration_minutes, status,
        consultation_fee, notes, dwh_source, dwh_load_date
    )
    SELECT
        appointment_id, patient_id, doctor_id, department_id, treatment_id,
        appointment_date, appointment_time, duration_minutes, status,
        consultation_fee, notes, 'appointments.csv', GETDATE()
    FROM bronze.appointments_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    -- ---------------- bills ----------------
    PRINT '>> Loading bronze.bills...';
    TRUNCATE TABLE bronze.bills_stg;
    SET @sql = N'BULK INSERT bronze.bills_stg FROM ''' + @source_folder + N'bills.csv''
        WITH (FIELDTERMINATOR='','', ROWTERMINATOR=''0x0a'', FIRSTROW=2, TABLOCK);';
    EXEC sp_executesql @sql;
    TRUNCATE TABLE bronze.bills;
    INSERT INTO bronze.bills (
        bill_id, appointment_id, patient_id, doctor_id, insurance_id, treatment_id,
        bill_date, total_amount, insurance_covered, patient_paid,
        outstanding_amount, payment_status, dwh_source, dwh_load_date
    )
    SELECT
        bill_id, appointment_id, patient_id, doctor_id, insurance_id, treatment_id,
        bill_date, total_amount, insurance_covered, patient_paid,
        outstanding_amount, payment_status, 'bills.csv', GETDATE()
    FROM bronze.bills_stg;
    PRINT '   Rows: ' + CAST(@@ROWCOUNT AS NVARCHAR);

    PRINT '=== Bronze Load Completed in ' +
          CAST(DATEDIFF(SECOND, @start, GETDATE()) AS NVARCHAR) + 's ===';
END;
GO

-- Run it:
EXEC bronze.sp_load_bronze;
-- Or, for a container path later: EXEC bronze.sp_load_bronze @source_folder = '/data/';