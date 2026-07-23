import mysql.connector

# Database connection details
DB_CONFIG = {
    "host": "localhost",
    "database": "universitydb",
    "user": "root",
    "password": "root123"
}

print("--- Self-Monitoring Consistency Check ---")

try:
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # 1. List all audit log records in log format
    print("\n--- Audit Log Records ---")
    cursor.execute("SELECT log_id, action, student_id, action_time FROM audit_log ORDER BY log_id")
    logs = cursor.fetchall()
    for log in logs:
        print(f"[{log[3]}] Log ID: {log[0]} | Action: {log[1]} | Student ID: {log[2]}")

    # 2. Method 1: Count students directly from student table
    cursor.execute("SELECT COUNT(*) FROM student")
    student_count = cursor.fetchone()[0]

    # 3. Method 2: Calculate expected students from audit log
    cursor.execute("""
        SELECT
            (SELECT COUNT(*) FROM audit_log WHERE action='INSERT') -
            (SELECT COUNT(*) FROM audit_log WHERE action='DELETE')
    """)
    audit_count = cursor.fetchone()[0]
    if audit_count is None:
        audit_count = 0

    print("\n--- Consistency Check ---")
    print("-" * 40)
    print("Method 1 - Student Table Count:", student_count)
    print("Method 2 - Audit Log Calculated Count:", audit_count)
    print("-" * 40)

    # Compare independent results
    if student_count != audit_count:
        print("Result: CONSISTENCY FAILURE")
        print(f"Mismatch detected: Student table = {student_count}, Audit log = {audit_count}")
    else:
        print("Result: CONSISTENCY CHECK PASSED")
        print(f"Both methods report {student_count} students.")

    cursor.close()
    conn.close()

except Exception as e:
    print("Error:", e)