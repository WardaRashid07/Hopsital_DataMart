USE HospitalMart;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO

-- dim_date
IF OBJECT_ID('gold.dim_date', 'U') IS NULL
CREATE TABLE gold.dim_date (
    date_key      INT          NOT NULL,
    full_date     DATE         NOT NULL,
    year          INT,
    quarter       INT,
    quarter_name  NVARCHAR(5),
    month         INT,
    month_name    NVARCHAR(20),
    day_of_month  INT,
    day_of_week   INT,
    day_name      NVARCHAR(20),
    week_number   INT,
    is_weekend    BIT,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);

-- dim_patient
IF OBJECT_ID('gold.dim_patient', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_patient (
        patient_key         INT             NOT NULL    IDENTITY(1,1),
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
        insurance_status    NVARCHAR(20),
        registration_date   DATE,
        effective_date      DATE            NOT NULL,
        end_date            DATE,
        is_current          BIT             NOT NULL    DEFAULT 1,
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_dim_patient PRIMARY KEY (patient_key)
    );
    CREATE INDEX IX_dim_patient_id      ON gold.dim_patient (patient_id, is_current);
    CREATE INDEX IX_dim_patient_country ON gold.dim_patient (country, is_current);
END

-- dim_doctor
IF OBJECT_ID('gold.dim_doctor', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_doctor (
        doctor_key          INT             NOT NULL    IDENTITY(1,1),
        doctor_id           INT             NOT NULL,
        first_name          NVARCHAR(100)   NOT NULL,
        last_name           NVARCHAR(100)   NOT NULL,
        full_name           NVARCHAR(200),
        specialization      NVARCHAR(100),
        department_id       INT,
        qualification       NVARCHAR(100),
        hire_date           DATE,
        status              NVARCHAR(20),
        effective_date      DATE            NOT NULL,
        end_date            DATE,
        is_current          BIT             NOT NULL    DEFAULT 1,
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_dim_doctor PRIMARY KEY (doctor_key)
    );
    CREATE INDEX IX_dim_doctor_id   ON gold.dim_doctor (doctor_id, is_current);
    CREATE INDEX IX_dim_doctor_spec ON gold.dim_doctor (specialization, is_current);
END

-- dim_department
IF OBJECT_ID('gold.dim_department', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_department (
        department_key      INT             NOT NULL    IDENTITY(1,1),
        department_id       INT             NOT NULL    UNIQUE,
        department_name     NVARCHAR(100)   NOT NULL,
        building            NVARCHAR(50),
        floor               NVARCHAR(20),
        head_doctor         NVARCHAR(100),
        established_date    DATE,
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_dim_department PRIMARY KEY (department_key)
    );
    CREATE INDEX IX_dim_department_id ON gold.dim_department (department_id);
END

-- dim_treatment
IF OBJECT_ID('gold.dim_treatment', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_treatment (
        treatment_key       INT             NOT NULL    IDENTITY(1,1),
        treatment_id        INT             NOT NULL    UNIQUE,
        treatment_name      NVARCHAR(150)   NOT NULL,
        treatment_type      NVARCHAR(100),
        diagnosis_code      NVARCHAR(20),
        diagnosis_name      NVARCHAR(150),
        standard_cost       DECIMAL(10,2),
        duration_minutes    INT,
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_dim_treatment PRIMARY KEY (treatment_key)
    );
    CREATE INDEX IX_dim_treatment_id   ON gold.dim_treatment (treatment_id);
    CREATE INDEX IX_dim_treatment_type ON gold.dim_treatment (treatment_type);
END

-- dim_insurance
IF OBJECT_ID('gold.dim_insurance', 'U') IS NULL
BEGIN
    CREATE TABLE gold.dim_insurance (
        insurance_key       INT             NOT NULL    IDENTITY(1,1),
        insurance_id        INT             NOT NULL    UNIQUE,
        provider_name       NVARCHAR(150)   NOT NULL,
        plan_type           NVARCHAR(50),
        coverage_pct        DECIMAL(5,2),
        max_coverage_amount DECIMAL(12,2),
        status              NVARCHAR(20),
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_dim_insurance PRIMARY KEY (insurance_key)
    );
    CREATE INDEX IX_dim_insurance_id ON gold.dim_insurance (insurance_id);
END

-- fact_appointments
IF OBJECT_ID('gold.fact_appointments', 'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_appointments (
        appointment_key     INT             NOT NULL    IDENTITY(1,1),
        appointment_id      INT             NOT NULL,
        date_key            INT             NOT NULL,
        patient_key         INT             NOT NULL,
        doctor_key          INT             NOT NULL,
        department_key      INT             NOT NULL,
        treatment_key       INT             NOT NULL,
        appointment_time    NVARCHAR(20),
        appointment_status  NVARCHAR(30),
        duration_minutes    INT,
        consultation_fee    DECIMAL(10,2),
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_fact_appointments  PRIMARY KEY (appointment_key),
        CONSTRAINT FK_appt_date          FOREIGN KEY (date_key)       REFERENCES gold.dim_date(date_key),
        CONSTRAINT FK_appt_patient       FOREIGN KEY (patient_key)    REFERENCES gold.dim_patient(patient_key),
        CONSTRAINT FK_appt_doctor        FOREIGN KEY (doctor_key)     REFERENCES gold.dim_doctor(doctor_key),
        CONSTRAINT FK_appt_department    FOREIGN KEY (department_key) REFERENCES gold.dim_department(department_key),
        CONSTRAINT FK_appt_treatment     FOREIGN KEY (treatment_key)  REFERENCES gold.dim_treatment(treatment_key),
        CONSTRAINT CK_appt_fee           CHECK (consultation_fee >= 0),
        CONSTRAINT CK_appt_duration      CHECK (duration_minutes > 0)
    );
    CREATE INDEX IX_fact_appt_date       ON gold.fact_appointments (date_key);
    CREATE INDEX IX_fact_appt_patient    ON gold.fact_appointments (patient_key);
    CREATE INDEX IX_fact_appt_doctor     ON gold.fact_appointments (doctor_key);
    CREATE INDEX IX_fact_appt_department ON gold.fact_appointments (department_key);
    CREATE INDEX IX_fact_appt_treatment  ON gold.fact_appointments (treatment_key);
    CREATE INDEX IX_fact_appt_date_doc   ON gold.fact_appointments (date_key, doctor_key)
        INCLUDE (consultation_fee, duration_minutes);
    CREATE INDEX IX_fact_appt_date_dept  ON gold.fact_appointments (date_key, department_key)
        INCLUDE (consultation_fee, appointment_status);
END

-- fact_billing
IF OBJECT_ID('gold.fact_billing', 'U') IS NULL
BEGIN
    CREATE TABLE gold.fact_billing (
        billing_key         INT             NOT NULL    IDENTITY(1,1),
        bill_id             INT             NOT NULL,
        appointment_id      INT             NOT NULL,
        date_key            INT             NOT NULL,
        patient_key         INT             NOT NULL,
        doctor_key          INT             NOT NULL,
        treatment_key       INT             NOT NULL,
        insurance_key       INT             NOT NULL,
        payment_status      NVARCHAR(30),
        total_amount        DECIMAL(18,2)   NOT NULL,
        insurance_covered   DECIMAL(18,2)   NOT NULL    DEFAULT 0,
        patient_paid        DECIMAL(18,2)   NOT NULL    DEFAULT 0,
        outstanding_amount  DECIMAL(18,2)   NOT NULL    DEFAULT 0,
        recovery_rate       AS (
                                CASE WHEN total_amount > 0
                                THEN CAST((patient_paid + insurance_covered)
                                     * 100.0 / total_amount AS DECIMAL(10,2))
                                ELSE 0 END
                            ) PERSISTED,
        dwh_load_date       DATETIME                    DEFAULT GETDATE(),
        CONSTRAINT PK_fact_billing      PRIMARY KEY (billing_key),
        CONSTRAINT FK_bill_date         FOREIGN KEY (date_key)       REFERENCES gold.dim_date(date_key),
        CONSTRAINT FK_bill_patient      FOREIGN KEY (patient_key)    REFERENCES gold.dim_patient(patient_key),
        CONSTRAINT FK_bill_doctor       FOREIGN KEY (doctor_key)     REFERENCES gold.dim_doctor(doctor_key),
        CONSTRAINT FK_bill_treatment    FOREIGN KEY (treatment_key)  REFERENCES gold.dim_treatment(treatment_key),
        CONSTRAINT FK_bill_insurance    FOREIGN KEY (insurance_key)  REFERENCES gold.dim_insurance(insurance_key),
        CONSTRAINT CK_bill_total        CHECK (total_amount > 0),
        CONSTRAINT CK_bill_covered      CHECK (insurance_covered >= 0),
        CONSTRAINT CK_bill_paid         CHECK (patient_paid >= 0),
        CONSTRAINT CK_bill_outstanding  CHECK (outstanding_amount >= 0)
    );
    CREATE INDEX IX_fact_bill_date      ON gold.fact_billing (date_key);
    CREATE INDEX IX_fact_bill_patient   ON gold.fact_billing (patient_key);
    CREATE INDEX IX_fact_bill_doctor    ON gold.fact_billing (doctor_key);
    CREATE INDEX IX_fact_bill_insurance ON gold.fact_billing (insurance_key);
    CREATE INDEX IX_fact_bill_treatment ON gold.fact_billing (treatment_key);
    CREATE INDEX IX_fact_bill_date_ins  ON gold.fact_billing (date_key, insurance_key)
        INCLUDE (total_amount, insurance_covered, outstanding_amount);
END
GO

-- Verify all 8 Gold tables exist
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'gold'
ORDER BY TABLE_NAME;