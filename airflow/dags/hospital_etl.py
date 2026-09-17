from datetime import datetime

import pyodbc

from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator


def get_connection():
    password = "MY_PASS"

    return pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};"
        "SERVER=host.docker.internal,1433;"
        "DATABASE=HospitalMart;"
        "UID=etl_service;"
        f"PWD={password};"
        "Encrypt=no;"
    )


def load_bronze():
    conn = get_connection()

    cursor = conn.cursor()
    cursor.execute("EXEC bronze.sp_load_bronze")

    conn.commit()

    cursor.close()
    conn.close()

    print("Bronze layer loaded successfully.")


def load_silver():
    conn = get_connection()

    cursor = conn.cursor()
    cursor.execute("EXEC silver.sp_load_silver")

    conn.commit()

    cursor.close()
    conn.close()

    print("Silver layer loaded successfully.")


def load_gold():
    conn = get_connection()

    cursor = conn.cursor()
    cursor.execute("EXEC dbo.sp_run_full_etl")

    conn.commit()

    cursor.close()
    conn.close()

    print("Gold layer loaded successfully.")


def data_quality_check():
    conn = get_connection()

    cursor = conn.cursor()
    cursor.execute("EXEC gold.sp_data_quality_check")

    # Consume result sets returned by the procedure
    while cursor.nextset():
        pass

    cursor.close()
    conn.close()

    print("Data quality check completed successfully.")


with DAG(
    dag_id="hospital_full_etl",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    description="Hospital Data Warehouse Bronze to Silver to Gold ETL",
) as dag:

    bronze_task = PythonOperator(
        task_id="load_bronze",
        python_callable=load_bronze,
    )

    silver_task = PythonOperator(
        task_id="load_silver",
        python_callable=load_silver,
    )

    gold_task = PythonOperator(
        task_id="load_gold",
        python_callable=load_gold,
    )

    quality_task = PythonOperator(
        task_id="data_quality_check",
        python_callable=data_quality_check,
    )

    bronze_task >> silver_task >> gold_task >> quality_task