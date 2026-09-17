-- ============================================================
-- HOSPITAL DATA MART
-- LAYER    : Silver (Cleaned & Standardized)
-- DATABASE : HospitalDataMart
-- PURPOSE  : Clean, standardize, fix data types, remove
--            duplicates, handle NULLs from Bronze layer.
--            Silver = trusted, clean source of truth.
-- LOAD TYPE: Full Load — Truncate & Insert on every run
-- ============================================================

USE HospitalMart;
GO

-- ------------------------------------------------------------
-- CREATE SCHEMA
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

-- ============================================================
-- SILVER TABLES
-- Proper data types enforced here (not in Bronze)
-- Audit column dwh_load_date added to every table
-- ============================================================

-- ------------------------------------------------------------
-- 1. silver.patients
-- Cleaning applied:
--   - TRIM whitespace from all string columns
--   - Standardize gender: M/Male/male → 'Male', F/Female → 'Female', else 'Other'
--   - TRY_CAST birth_date and registration_date to DATE
--   - Standardize insurance_status: Yes/Y/1 → 'Active', else 'Inactive'
--   - Remove duplicates: keep latest by registration_date
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.patients', 'U') IS NOT NULL DROP TABLE silver.patients;
CREATE TABLE silver.patients (
    patient_id          INT             NOT NULL,
    first_name          NVARCHAR(100)   NOT NULL,
    last_name           NVARCHAR(100)   NOT NULL,
    full_name           NVARCHAR(200),
    gender              NVARCHAR(20),
    birth_date          DATE,
    age                 INT,
    blood_type          NVARCHAR(10),
    city                NVARCHAR(100),
    country             NVARCHAR(100),
    phone               NVARCHAR(30),
    email               NVARCHAR(150),
    registration_date   DATE,
    insurance_status    NVARCHAR(20),
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_patients PRIMARY KEY (patient_id)
);

-- ------------------------------------------------------------
-- 2. silver.doctors
-- Cleaning applied:
--   - TRIM all strings
--   - Standardize status: Active/active/A → 'Active', else 'Inactive'
--   - TRY_CAST hire_date to DATE
--   - Remove duplicates: keep latest by hire_date
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.doctors', 'U') IS NOT NULL DROP TABLE silver.doctors;
CREATE TABLE silver.doctors (
    doctor_id           INT             NOT NULL,
    first_name          NVARCHAR(100)   NOT NULL,
    last_name           NVARCHAR(100)   NOT NULL,
    full_name           NVARCHAR(200),
    specialization      NVARCHAR(100),
    department_id       INT,
    qualification       NVARCHAR(100),
    hire_date           DATE,
    status              NVARCHAR(20),
    phone               NVARCHAR(30),
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_doctors PRIMARY KEY (doctor_id)
);

-- ------------------------------------------------------------
-- 3. silver.departments
-- Cleaning applied:
--   - TRIM all strings
--   - TRY_CAST established_date to DATE
--   - Remove duplicates
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.departments', 'U') IS NOT NULL DROP TABLE silver.departments;
CREATE TABLE silver.departments (
    department_id       INT             NOT NULL,
    department_name     NVARCHAR(100)   NOT NULL,
    building            NVARCHAR(50),
    floor               NVARCHAR(20),
    head_doctor         NVARCHAR(100),
    established_date    DATE,
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_departments PRIMARY KEY (department_id)
);

-- ------------------------------------------------------------
-- 4. silver.treatments
-- Cleaning applied:
--   - TRIM all strings
--   - TRY_CAST standard_cost to DECIMAL
--   - TRY_CAST duration_minutes to INT
--   - Remove duplicates
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.treatments', 'U') IS NOT NULL DROP TABLE silver.treatments;
CREATE TABLE silver.treatments (
    treatment_id        INT             NOT NULL,
    treatment_name      NVARCHAR(150)   NOT NULL,
    treatment_type      NVARCHAR(100),
    diagnosis_code      NVARCHAR(20),
    diagnosis_name      NVARCHAR(150),
    standard_cost       DECIMAL(10,2),
    duration_minutes    INT,
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_treatments PRIMARY KEY (treatment_id)
);

-- ------------------------------------------------------------
-- 5. silver.insurance_providers
-- Cleaning applied:
--   - TRIM all strings
--   - TRY_CAST coverage_pct to DECIMAL
--   - TRY_CAST max_coverage_amount to DECIMAL
--   - Standardize status: Active/active → 'Active', else 'Inactive'
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.insurance_providers', 'U') IS NOT NULL DROP TABLE silver.insurance_providers;
CREATE TABLE silver.insurance_providers (
    insurance_id        INT             NOT NULL,
    provider_name       NVARCHAR(150)   NOT NULL,
    plan_type           NVARCHAR(50),
    coverage_pct        DECIMAL(5,2),
    max_coverage_amount DECIMAL(12,2),
    status              NVARCHAR(20),
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_insurance PRIMARY KEY (insurance_id)
);

-- ------------------------------------------------------------
-- 6. silver.appointments
-- Cleaning applied:
--   - TRIM all strings
--   - TRY_CAST appointment_date to DATE
--   - TRY_CAST duration_minutes to INT
--   - TRY_CAST consultation_fee to DECIMAL
--   - Standardize status: Completed/completed → 'Completed' etc.
--   - Drop rows where appointment_date is NULL (invalid records)
--   - Remove duplicates: keep one row per appointment_id
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.appointments', 'U') IS NOT NULL DROP TABLE silver.appointments;
CREATE TABLE silver.appointments (
    appointment_id      INT             NOT NULL,
    patient_id          INT             NOT NULL,
    doctor_id           INT             NOT NULL,
    department_id       INT             NOT NULL,
    treatment_id        INT             NOT NULL,
    appointment_date    DATE            NOT NULL,
    appointment_time    NVARCHAR(20),
    duration_minutes    INT,
    status              NVARCHAR(30),
    consultation_fee    DECIMAL(10,2),
    notes               NVARCHAR(500),
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_appointments PRIMARY KEY (appointment_id)
);

-- ------------------------------------------------------------
-- 7. silver.bills
-- Cleaning applied:
--   - TRIM all strings
--   - TRY_CAST all amount columns to DECIMAL
--   - TRY_CAST bill_date to DATE
--   - Standardize payment_status: Paid/paid → 'Paid' etc.
--   - Drop rows where total_amount is NULL or <= 0
--   - Remove duplicates: keep one row per bill_id
-- ------------------------------------------------------------
--IF OBJECT_ID('silver.bills', 'U') IS NOT NULL DROP TABLE silver.bills;
CREATE TABLE silver.bills (
    bill_id             INT             NOT NULL,
    appointment_id      INT             NOT NULL,
    patient_id          INT             NOT NULL,
    doctor_id           INT             NOT NULL,
    insurance_id        INT,
    treatment_id        INT             NOT NULL,
    bill_date           DATE            NOT NULL,
    total_amount        DECIMAL(12,2)   NOT NULL,
    insurance_covered   DECIMAL(12,2),
    patient_paid        DECIMAL(12,2),
    outstanding_amount  DECIMAL(12,2),
    payment_status      NVARCHAR(30),
    dwh_load_date       DATETIME        DEFAULT GETDATE(),
    CONSTRAINT PK_silver_bills PRIMARY KEY (bill_id)
);
GO
