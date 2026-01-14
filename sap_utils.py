import pandas as pd
import pyodbc
import credentials as creds # Reads your secured password
import warnings

# 1. Silence those annoying "SQLAlchemy" warnings globally
warnings.filterwarnings('ignore')

def get_data(sql_query):
    """
    Takes a SQL string, connects to SAP, returns a DataFrame.
    Handles errors automatically.
    """
    # Define connection settings once, here in this file
    conn_str = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={creds.SERVER};"
        f"DATABASE={creds.DATABASE};"
        f"UID={creds.USER};"
        f"PWD={creds.PASSWORD};"
        "Encrypt=no;"
        "TrustServerCertificate=yes;"
    )
    
    conn = None
    try:
        conn = pyodbc.connect(conn_str)
        df = pd.read_sql(sql_query, conn)
        return df
    except Exception as e:
        print(f"❌ Connection Error: {e}")
        return None
    finally:
        # Best Practice: Always close the door when you leave
        if conn:
            conn.close()