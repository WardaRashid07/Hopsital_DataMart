-- ============================================================
-- BRONZE LAYER — staging tables (match CSV exactly, BULK INSERT target)
-- + final tables (staging columns + permanent audit columns)
-- Idempotent: safe to run any number of times.
-- ============================================================
USE HospitalMart;

-- ---------------- patients ----------------
IF OBJECT_ID('bronze.patients_stg', 'U') IS NULL
CREATE TABLE bronze.patients_stg (
    patient_id          NVARCHAR(50),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    gender              NVARCHAR(20),
    birth_date          NVARCHAR(50),
    blood_type          NVARCHAR(10),
    city                NVARCHAR(100),
    country             NVARCHAR(100),
    phone               NVARCHAR(30),
    email               NVARCHAR(150),
    registration_date   NVARCHAR(50),
    insurance_status    NVARCHAR(30)
);

IF OBJECT_ID('bronze.patients', 'U') IS NULL
CREATE TABLE bronze.patients (
    patient_id          NVARCHAR(50),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    gender              NVARCHAR(20),
    birth_date          NVARCHAR(50),
    blood_type          NVARCHAR(10),
    city                NVARCHAR(100),
    country             NVARCHAR(100),
    phone               NVARCHAR(30),
    email               NVARCHAR(150),
    registration_date   NVARCHAR(50),
    insurance_status    NVARCHAR(30),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- doctors ----------------
IF OBJECT_ID('bronze.doctors_stg', 'U') IS NULL
CREATE TABLE bronze.doctors_stg (
    doctor_id           NVARCHAR(50),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    specialization      NVARCHAR(100),
    department_id       NVARCHAR(50),
    qualification       NVARCHAR(100),
    hire_date           NVARCHAR(50),
    status              NVARCHAR(30),
    phone               NVARCHAR(30)
);

IF OBJECT_ID('bronze.doctors', 'U') IS NULL
CREATE TABLE bronze.doctors (
    doctor_id           NVARCHAR(50),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    specialization      NVARCHAR(100),
    department_id       NVARCHAR(50),
    qualification       NVARCHAR(100),
    hire_date           NVARCHAR(50),
    status              NVARCHAR(30),
    phone               NVARCHAR(30),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- departments ----------------
IF OBJECT_ID('bronze.departments_stg', 'U') IS NULL
CREATE TABLE bronze.departments_stg (
    department_id       NVARCHAR(50),
    department_name     NVARCHAR(100),
    building            NVARCHAR(50),
    floor               NVARCHAR(20),
    head_doctor         NVARCHAR(100),
    established_date    NVARCHAR(50)
);

IF OBJECT_ID('bronze.departments', 'U') IS NULL
CREATE TABLE bronze.departments (
    department_id       NVARCHAR(50),
    department_name     NVARCHAR(100),
    building            NVARCHAR(50),
    floor               NVARCHAR(20),
    head_doctor         NVARCHAR(100),
    established_date    NVARCHAR(50),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- treatments ----------------
IF OBJECT_ID('bronze.treatments_stg', 'U') IS NULL
CREATE TABLE bronze.treatments_stg (
    treatment_id        NVARCHAR(50),
    treatment_name      NVARCHAR(150),
    treatment_type      NVARCHAR(100),
    diagnosis_code      NVARCHAR(20),
    diagnosis_name      NVARCHAR(150),
    standard_cost       NVARCHAR(50),
    duration_minutes    NVARCHAR(20)
);

IF OBJECT_ID('bronze.treatments', 'U') IS NULL
CREATE TABLE bronze.treatments (
    treatment_id        NVARCHAR(50),
    treatment_name      NVARCHAR(150),
    treatment_type      NVARCHAR(100),
    diagnosis_code      NVARCHAR(20),
    diagnosis_name      NVARCHAR(150),
    standard_cost       NVARCHAR(50),
    duration_minutes    NVARCHAR(20),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- insurance_providers ----------------
IF OBJECT_ID('bronze.insurance_providers_stg', 'U') IS NULL
CREATE TABLE bronze.insurance_providers_stg (
    insurance_id        NVARCHAR(50),
    provider_name       NVARCHAR(150),
    plan_type           NVARCHAR(50),
    coverage_pct        NVARCHAR(20),
    max_coverage_amount NVARCHAR(50),
    status              NVARCHAR(30)
);

IF OBJECT_ID('bronze.insurance_providers', 'U') IS NULL
CREATE TABLE bronze.insurance_providers (
    insurance_id        NVARCHAR(50),
    provider_name       NVARCHAR(150),
    plan_type           NVARCHAR(50),
    coverage_pct        NVARCHAR(20),
    max_coverage_amount NVARCHAR(50),
    status              NVARCHAR(30),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- appointments ----------------
IF OBJECT_ID('bronze.appointments_stg', 'U') IS NULL
CREATE TABLE bronze.appointments_stg (
    appointment_id      NVARCHAR(50),
    patient_id          NVARCHAR(50),
    doctor_id           NVARCHAR(50),
    department_id       NVARCHAR(50),
    treatment_id        NVARCHAR(50),
    appointment_date    NVARCHAR(50),
    appointment_time    NVARCHAR(20),
    duration_minutes    NVARCHAR(20),
    status              NVARCHAR(30),
    consultation_fee    NVARCHAR(50),
    notes               NVARCHAR(500)
);

IF OBJECT_ID('bronze.appointments', 'U') IS NULL
CREATE TABLE bronze.appointments (
    appointment_id      NVARCHAR(50),
    patient_id          NVARCHAR(50),
    doctor_id           NVARCHAR(50),
    department_id       NVARCHAR(50),
    treatment_id        NVARCHAR(50),
    appointment_date    NVARCHAR(50),
    appointment_time    NVARCHAR(20),
    duration_minutes    NVARCHAR(20),
    status              NVARCHAR(30),
    consultation_fee    NVARCHAR(50),
    notes               NVARCHAR(500),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- bills ----------------
IF OBJECT_ID('bronze.bills_stg', 'U') IS NULL
CREATE TABLE bronze.bills_stg (
    bill_id             NVARCHAR(50),
    appointment_id      NVARCHAR(50),
    patient_id          NVARCHAR(50),
    doctor_id           NVARCHAR(50),
    insurance_id        NVARCHAR(50),
    treatment_id        NVARCHAR(50),
    bill_date           NVARCHAR(50),
    total_amount        NVARCHAR(50),
    insurance_covered   NVARCHAR(50),
    patient_paid        NVARCHAR(50),
    outstanding_amount  NVARCHAR(50),
    payment_status      NVARCHAR(30)
);

IF OBJECT_ID('bronze.bills', 'U') IS NULL
CREATE TABLE bronze.bills (
    bill_id             NVARCHAR(50),
    appointment_id      NVARCHAR(50),
    patient_id          NVARCHAR(50),
    doctor_id           NVARCHAR(50),
    insurance_id        NVARCHAR(50),
    treatment_id        NVARCHAR(50),
    bill_date           NVARCHAR(50),
    total_amount        NVARCHAR(50),
    insurance_covered   NVARCHAR(50),
    patient_paid        NVARCHAR(50),
    outstanding_amount  NVARCHAR(50),
    payment_status      NVARCHAR(30),
    dwh_source          NVARCHAR(100) NULL,
    dwh_load_date       DATETIME      NULL
);

-- ---------------- verify ----------------
SELECT 'patients'    AS tbl, COUNT(*) AS rows FROM bronze.patients
UNION ALL SELECT 'doctors',      COUNT(*) FROM bronze.doctors
UNION ALL SELECT 'departments',  COUNT(*) FROM bronze.departments
UNION ALL SELECT 'treatments',   COUNT(*) FROM bronze.treatments
UNION ALL SELECT 'insurance',    COUNT(*) FROM bronze.insurance_providers
UNION ALL SELECT 'appointments', COUNT(*) FROM bronze.appointments
UNION ALL SELECT 'bills',        COUNT(*) FROM bronze.bills;