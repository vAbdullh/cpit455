import mysql.connector

# Database connection details
DB_CONFIG = {
    "host": "localhost",
    "database": "universitydb",
    "user": "root",
    "password": "root123"
}

print("--- Test: Protection System Guard ---")

email_to_check = "sara@kau.edu.sa"
print(f"Checking permission to register email: {email_to_check}...")

try:
    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # Query if email exists
    cursor.execute("SELECT COUNT(*) FROM student WHERE email = %s", (email_to_check,))
    exists = cursor.fetchone()[0] > 0

    if exists:
        print("Result: VETOED (Duplicate email - student already registered)")
    else:
        print("Result: PERMITTED (Email is unique)")

    cursor.close()
    conn.close()

except Exception as e:
    print("Error:", e)