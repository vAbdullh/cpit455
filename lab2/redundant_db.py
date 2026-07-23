import mysql.connector

# Database connection details
PRIMARY_DB = {
    "host": "localhost",
    "database": "universitydb",
    "user": "root",
    "password": "root123"
}

BACKUP_DB = {
    "host": "localhost",
    "database": "universitydb_backup",
    "user": "root",
    "password": "root123"
}

print("--- Test: Database Connection Failover ---")

# Try primary database first
try:
    print("Connecting to PRIMARY database...")
    conn = mysql.connector.connect(**PRIMARY_DB)
    print("Status: Success (Connected to PRIMARY)")
    
    # Run a simple query to verify data retrieval
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM student")
    count = cursor.fetchone()[0]
    print(f"Data check: Found {count} student records")
    
    cursor.close()
    conn.close()
    print()

except Exception as e:
    print(f"Primary connection failed: {e}")
    print("Initiating failover... Connecting to BACKUP database...")
    
    # Fallback to backup database
    try:
        conn = mysql.connector.connect(**BACKUP_DB)
        print("Status: Success (Connected to BACKUP)")
        
        # Run a simple query to verify data retrieval
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM student")
        count = cursor.fetchone()[0]
        print(f"Data check: Found {count} student records")
        
        cursor.close()
        conn.close()
        print()
    except Exception as backup_error:
        print(f"CRITICAL ERROR: Backup database also failed: {backup_error}")
        print()