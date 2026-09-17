-- ============================================================
-- HOSPITAL DATA MART
-- LAYER    : Silver (Cleaned & Standardized)
-- DATABASE : HospitalMart
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
-- REJECTED ROWS LOG
-- Captures rows dropped during Bronze -> Silver cleaning, with
-- the reason and the full raw row (as JSON) for review.
-- Refreshed each sp_load_silver run — shows the most recent
-- run's rejects, consistent with the full-reload pattern used
-- everywhere else in this pipeline (not an unbounded history).
-- ============================================================
IF OBJECT_ID('silver.rejected_rows', 'U') IS NULL
CREATE TABLE silver.rejected_rows (
    rejected_id       INT IDENTITY(1,1) NOT NULL,
    source_table      NVARCHAR(50)   NOT NULL,
    rejection_reason  NVARCHAR(300)  NOT NULL,
    raw_row_json      NVARCHAR(MAX)  NULL,
    rejected_at       DATETIME       NOT NULL DEFAULT GETDATE(),
    CONSTRAINT PK_silver_rejected_rows PRIMARY KEY (rejected_id)
);
GO

-- ============================================================
-- SILVER TABLES
-- Proper data types enforced here (not in Bronze)
-- Audit column dwh_load_date added to every table
-- ============================================================

IF OBJECT_ID('silver.patients', 'U') IS NULL
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

IF OBJECT_ID('silver.doctors', 'U') IS NULL
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

IF OBJECT_ID('silver.departments', 'U') IS NULL
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

IF OBJECT_ID('silver.treatments', 'U') IS NULL
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

IF OBJECT_ID('silver.insurance_providers', 'U') IS NULL
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

IF OBJECT_ID('silver.appointments', 'U') IS NULL
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

IF OBJECT_ID('silver.bills', 'U') IS NULL
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
