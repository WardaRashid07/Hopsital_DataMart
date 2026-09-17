# 🏥 Hospital Data Mart

A complete, end-to-end **data warehousing solution** built on Microsoft SQL Server, implementing the **Medallion Architecture** (Bronze → Silver → Gold) with a **Constellation Schema** for hospital analytics.

Designed as a portfolio project demonstrating industry best practices in data engineering, dimensional modeling, ETL development, and business analytics.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        SOURCE SYSTEMS                           │
│  Registration System · HR System · Scheduling · Billing · ERP  │
│              Object Type: CSV Files                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │  BULK INSERT
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                       BRONZE LAYER                              │
│                  Raw Data — No Transformations                  │
│         Load Type: Full Load · Truncate & Insert                │
│                                                                 │
│  bronze.patients          bronze.doctors                        │
│  bronze.departments       bronze.treatments                     │
│  bronze.insurance_providers                                     │
│  bronze.appointments      bronze.bills                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │  silver.sp_load_silver
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                       SILVER LAYER                              │
│           Cleaned · Standardized · Deduplicated                 │
│         Load Type: Full Load · Truncate & Insert                │
│                                                                 │
│  Transformations: Data Cleansing · Type Casting                 │
│  Standardization · Derived Columns · NULL Handling             │
│                                                                 │
│  silver.patients          silver.doctors                        │
│  silver.departments       silver.treatments                     │
│  silver.insurance_providers                                     │
│  silver.appointments      silver.bills                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │  dbo.sp_run_full_etl
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        GOLD LAYER                               │
│              Business-Ready · Constellation Schema              │
│         Load Type: Incremental · SCD Type 1 & 2                │
│                                                                 │
│  DIMENSIONS              FACTS                                  │
│  gold.dim_date           gold.fact_appointments                 │
│  gold.dim_patient        gold.fact_billing                      │
│  gold.dim_doctor                                                │
│  gold.dim_department                                            │
│  gold.dim_treatment                                             │
│  gold.dim_insurance                                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ANALYTICS LAYER                             │
│          Views · KPI Queries · Data Quality Checks              │
│                                                                 │
│  Power BI · Ad-hoc SQL · Reporting                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📐 Data Model — Constellation Schema

```
                        gold.dim_date
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    gold.dim_patient   gold.dim_doctor  gold.dim_treatment
              │              │              │
              └──────────────┼──────────────┘
                             │
                   gold.fact_appointments
                   gold.fact_billing ─────── gold.dim_insurance
                             │
                   gold.dim_department
```

> **Why Constellation Schema?**  
> Two fact tables (`fact_appointments` and `fact_billing`) share multiple dimension tables. This is called a **Constellation (Galaxy) Schema** — more realistic than a basic star schema and better suited to hospital operations where appointments and billing are separate business processes with different grains and different timing.

---

## 📊 Fact Tables

### `gold.fact_appointments`
**Grain:** One row per appointment

| Column | Type | Description |
|--------|------|-------------|
| appointment_key | INT IDENTITY | Surrogate PK |
| appointment_id | INT | Business key (traceability) |
| date_key | INT | FK → dim_date |
| patient_key | INT | FK → dim_patient |
| doctor_key | INT | FK → dim_doctor |
| department_key | INT | FK → dim_department |
| treatment_key | INT | FK → dim_treatment |
| appointment_status | NVARCHAR | Completed/Scheduled/Cancelled/No-Show |
| duration_minutes | INT | Length of appointment |
| consultation_fee | DECIMAL | Revenue measure |

### `gold.fact_billing`
**Grain:** One row per bill

| Column | Type | Description |
|--------|------|-------------|
| billing_key | INT IDENTITY | Surrogate PK |
| bill_id | INT | Business key (traceability) |
| date_key | INT | FK → dim_date |
| patient_key | INT | FK → dim_patient |
| doctor_key | INT | FK → dim_doctor |
| treatment_key | INT | FK → dim_treatment |
| insurance_key | INT | FK → dim_insurance |
| total_amount | DECIMAL | Total billed |
| insurance_covered | DECIMAL | Paid by insurance |
| patient_paid | DECIMAL | Paid by patient |
| outstanding_amount | DECIMAL | Still owed |
| recovery_rate | DECIMAL | Computed: (paid / total) × 100 |

---

## 🔄 Slowly Changing Dimensions (SCD)

| Dimension | SCD Type | Tracked Changes | Reason |
|-----------|----------|-----------------|--------|
| dim_patient | **Type 2** | insurance_status, city, country | Historical accuracy — patient segment at time of visit matters |
| dim_doctor | **Type 2** | specialization, department_id, status | Doctor may move departments — credit history correctly |
| dim_department | **Type 1** | All attributes | Overwrite — no history needed |
| dim_treatment | **Type 1** | standard_cost, treatment_type | Overwrite — cost changes just update |
| dim_insurance | **Type 1** | coverage_pct, status | Overwrite |
| dim_date | **Static** | None | Pre-populated, never changes |

**SCD Type 2** uses three tracking columns on `dim_patient` and `dim_doctor`:
- `effective_date` — when this version became active
- `end_date` — when this version was superseded (NULL = still active)
- `is_current` — BIT flag for quick filtering (1 = current record)

---

## 📁 Repository Structure

```
HospitalDataMart/
│
├── 01_bronze_layer.sql          — 7 raw staging tables + sp_load_bronze
├── 02_silver_layer.sql          — 7 cleaned tables + sp_load_silver
├── 03_gold_ddl.sql              — 6 dims + 2 facts + indexes + constraints
├── 04_etl_procedures.sql        — 8 ETL procedures + sp_run_full_etl
├── 05_analytics_views.sql       — 5 views + 7 KPI queries + sp_data_quality_check
│
├── datasets/
│   ├── patients.csv             — 5,000 rows (Registration System)
│   ├── doctors.csv              — 200 rows (HR System)
│   ├── departments.csv          — 20 rows (Admin System)
│   ├── treatments.csv           — 150 rows (Clinical System)
│   ├── insurance_providers.csv  — 30 rows (Finance System)
│   ├── appointments.csv         — 35,000 rows (Scheduling System)
│   └── bills.csv                — 10,000 rows (Billing System)
│
└── README.md
```

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| SQL Server Express 2022 | Database engine |
| SSMS 20 | Query editor and database management |
| T-SQL | ETL stored procedures and analytics |
| Power BI Desktop | Dashboard and reporting |
| GitHub | Version control and portfolio |

---

## 🚀 Setup & Execution

### Prerequisites
- [SQL Server Express](https://www.microsoft.com/en-us/sql-server/sql-server-downloads) (free)
- [SSMS 20](https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms) (free)

### Step-by-Step

**1. Create the database**
```sql
CREATE DATABASE HospitalDataMart;
USE HospitalDataMart;
```

**2. Run scripts in order**
```
01_bronze_layer.sql       →  Creates bronze schema + 7 raw tables + procedure
02_silver_layer.sql       →  Creates silver schema + 7 clean tables + procedure
03_gold_ddl.sql           →  Creates gold schema + star schema DDL
04_etl_procedures.sql     →  Creates all ETL procedures + runs full ETL
05_analytics_views.sql    →  Creates views + runs data quality check
```

**3. Update CSV file paths**

Before running `01_bronze_layer.sql`, update the file paths in `bronze.sp_load_bronze` to match your local machine:
```sql
FROM 'C:\YourPath\datasets\patients.csv'
```

**4. Load Bronze layer**
```sql
EXEC bronze.sp_load_bronze;
```

**5. Run full ETL pipeline**
```sql
EXEC dbo.sp_run_full_etl;
```

**6. Validate data quality**
```sql
EXEC gold.sp_data_quality_check;
```

**7. Query the analytics views**
```sql
SELECT * FROM gold.vw_monthly_appointments   ORDER BY year, month;
SELECT * FROM gold.vw_doctor_performance     ORDER BY total_revenue DESC;
SELECT * FROM gold.vw_department_summary     ORDER BY total_appointments DESC;
SELECT * FROM gold.vw_billing_recovery       ORDER BY total_outstanding DESC;
SELECT * FROM gold.vw_patient_analysis       ORDER BY lifetime_billed DESC;
```

---

## 📈 Key KPIs & Business Metrics

| KPI | Formula | View |
|-----|---------|------|
| Completion Rate | Completed / Total × 100 | vw_monthly_appointments |
| Cancellation Rate | Cancelled / Total × 100 | vw_monthly_appointments |
| Total Consultation Revenue | SUM(consultation_fee) | vw_doctor_performance |
| Billing Recovery Rate | (Paid + Covered) / Total × 100 | vw_billing_recovery |
| Outstanding Debt | SUM(outstanding_amount) | vw_billing_recovery |
| Patient Lifetime Value | SUM(total_amount) per patient | vw_patient_analysis |
| YoY Appointment Growth | (Current − Previous) / Previous × 100 | KPI Query 4 |
| Avg Consultation Duration | AVG(duration_minutes) | vw_doctor_performance |

---

## ✅ Data Quality Rules

| Rule | Enforcement |
|------|------------|
| No NULL foreign keys in fact tables | sp_data_quality_check |
| consultation_fee must be ≥ 0 | CHECK constraint on fact_appointments |
| duration_minutes must be > 0 | CHECK constraint on fact_appointments |
| total_amount must be > 0 | CHECK constraint on fact_billing |
| outstanding_amount must be ≥ 0 | CHECK constraint on fact_billing |
| Valid appointment statuses only | CHECK constraint on fact_appointments |
| Valid payment statuses only | CHECK constraint on fact_billing |
| No duplicate is_current=1 per patient/doctor | sp_data_quality_check SCD2 check |
| No duplicate IDs in Silver | ROW_NUMBER() deduplication in sp_load_silver |

---

## 🔑 Design Decisions

**Why Constellation Schema over Star?**
The hospital has two distinct business processes — appointments and billing — that occur at different times with different dimensions. Merging them into one fact table would produce a sparse table full of NULLs. Two fact tables sharing dimensions is the correct Kimball approach.

**Why SCD Type 2 on patients and doctors?**
A patient's insurance status at the time of the appointment determines what they were billed. If we only kept today's status, historical billing analysis would be wrong. SCD Type 2 preserves that historical truth by versioning the dimension row.

**Why computed persisted column for recovery_rate?**
`recovery_rate` is calculated once at load time and stored physically. Every analytics query gets the result instantly without recalculating across 10,000 rows. Consistency is also guaranteed — it always uses the same formula.

**Why surrogate keys instead of using business keys directly?**
Business keys from source systems can be recycled or change when systems are replaced. Surrogate keys (`IDENTITY`) isolate the warehouse from upstream changes and enable SCD Type 2 versioning.

**Why incremental load on fact tables?**
Running `EXEC dbo.sp_run_full_etl` multiple times will never create duplicate rows in the fact tables. The `WHERE NOT EXISTS` clause ensures only new appointments and bills are inserted each run.

---

## 📋 Business Problem Statement

A hospital manages thousands of appointments and billing transactions daily across multiple departments. Data lives in separate source systems — scheduling, HR, clinical, and finance — making it impossible to answer cross-functional questions like:

- Which doctor generates the most revenue?
- Which department has the highest cancellation rate?
- What percentage of bills are recovered from insurance?
- How does patient volume trend year over year?

This data mart integrates all source systems into a single analytical layer, enabling hospital management to answer these questions instantly through SQL queries or Power BI dashboards.

---

## 🛡️ License

This project is licensed under the [MIT License](LICENSE). Free to use, modify, and share with attribution.

---

## 🙏 Acknowledgments

Architecture and dimensional modeling approach inspired by **Baraa Khatib Salkini** (*Data with Baraa*) and the Kimball Group's dimensional modeling principles.
