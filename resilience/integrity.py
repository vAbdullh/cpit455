import hashlib
import json
import mysql.connector

CHECKSUM_SECRET = "CPIT455_SECRET"

DB_CONFIG = {
    "host": "localhost",
    "database": "universitydb",
    "user": "root",
    "password": "root123"
}


def record_checksum(record: dict, secret: str = CHECKSUM_SECRET) -> str:
    payload = json.dumps(record, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256((secret + payload).encode()).hexdigest()


def ensure_checksum_column(cursor):
    cursor.execute("""
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = 'universitydb'
          AND TABLE_NAME   = 'student'
          AND COLUMN_NAME  = 'checksum'
    """)
    if cursor.fetchone()[0] == 0:
        cursor.execute(
            "ALTER TABLE student ADD COLUMN checksum VARCHAR(64) DEFAULT NULL"
        )
        print("[+] Added 'checksum' column to student table.")


def recompute_all(cursor) -> int:
    cursor.execute("SELECT student_id, name, email, gpa FROM student")
    rows = cursor.fetchall()
    count = 0
    for sid, name, email, gpa in rows:
        rec = {
            "student_id": sid,
            "name": name,
            "email": email,
            "gpa": float(gpa)
        }
        chk = record_checksum(rec)
        cursor.execute(
            "UPDATE student SET checksum = %s WHERE student_id = %s",
            (chk, sid)
        )
        count += 1
    return count


def verify_all(cursor) -> list:
    corrupted = []
    cursor.execute(
        "SELECT student_id, name, email, gpa, checksum FROM student"
    )
    rows = cursor.fetchall()
    for sid, name, email, gpa, stored in rows:
        rec = {
            "student_id": sid,
            "name": name,
            "email": email,
            "gpa": float(gpa)
        }
        expected = record_checksum(rec)
        if stored != expected:
            corrupted.append({
                "student_id": sid,
                "name": name,
                "stored": stored,
                "expected": expected
            })
    return corrupted

if __name__ == "__main__":
    print("=" * 60)
    print("  Resilience — Integrity Check Demonstration")
    print("=" * 60)

    conn = mysql.connector.connect(**DB_CONFIG)
    cursor = conn.cursor()

    # Step 1: Ensure the checksum column exists
    ensure_checksum_column(cursor)
    conn.commit()

    # Step 2: Recompute all checksums (establish baseline)
    updated = recompute_all(cursor)
    conn.commit()
    print(f"\n[1] Recomputed checksums for {updated} records.")

    # Step 3: Verify — all should pass
    corrupted = verify_all(cursor)
    print(f"[2] Verification: {len(corrupted)} corrupted records found.")
    if not corrupted:
        print("    ✅ All records are intact.\n")

    # Step 4: Simulate corruption (malicious insider changes a GPA directly)
    cursor.execute("SELECT student_id, name, gpa FROM student LIMIT 1")
    row = cursor.fetchone()
    if row:
        sid, name, old_gpa = row
        fake_gpa = 4.0 if old_gpa < 4.0 else 0.0
        cursor.execute(
            "UPDATE student SET gpa = %s WHERE student_id = %s",
            (fake_gpa, sid)
        )
        conn.commit()
        print(f"[3] Simulated corruption: student '{name}' (ID={sid}) "
              f"GPA changed {old_gpa} → {fake_gpa} directly in DB.")

        # Step 5: Verify again — should catch the tampered record
        corrupted = verify_all(cursor)
        print(f"[4] Verification: {len(corrupted)} corrupted record(s) found.")
        for c in corrupted:
            print(f"    🔴 Student ID={c['student_id']} "
                  f"Name='{c['name']}' — CHECKSUM MISMATCH")
            print(f"       Stored:   {c['stored'][:32]}...")
            print(f"       Expected: {c['expected'][:32]}...")

        # Step 6: Restore original GPA
        cursor.execute(
            "UPDATE student SET gpa = %s WHERE student_id = %s",
            (old_gpa, sid)
        )
        # Recompute the checksum for the restored record
        rec = {
            "student_id": sid,
            "name": name,
            "email": "",  # need the email too
            "gpa": float(old_gpa)
        }
        # Get email to restore properly
        cursor.execute(
            "SELECT email FROM student WHERE student_id = %s", (sid,)
        )
        email = cursor.fetchone()[0]
        rec["email"] = email
        chk = record_checksum(rec)
        cursor.execute(
            "UPDATE student SET checksum = %s WHERE student_id = %s",
            (chk, sid)
        )
        conn.commit()
        print(f"\n[5] Restored student '{name}' GPA to {old_gpa} "
              "and recomputed checksum.")
    else:
        print("[!] No students in the database to demonstrate with.")

    cursor.close()
    conn.close()
    print("\nDone.")
