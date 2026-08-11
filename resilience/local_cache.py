import json
import os
import time
import mysql.connector
DB_CONFIG = {
    "host": "localhost",
    "database": "universitydb",
    "user": "root",
    "password": "root123"
}

BACKUP_DB_CONFIG = {
    "host": "localhost",
    "database": "universitydb_backup",
    "user": "root",
    "password": "root123"
}


class LocalSummaryCache:
    def __init__(self, path="session_cache.json", ttl_hours=24):
        self.path = path
        self.ttl = ttl_hours * 3600

    def download_for_session(self, db_config=DB_CONFIG):
        conn = None
        try:
            try:
                conn = mysql.connector.connect(**db_config)
            except Exception:
                conn = mysql.connector.connect(**BACKUP_DB_CONFIG)

            cursor = conn.cursor(dictionary=True)
            # Only critical fields — no email (least privilege)
            cursor.execute(
                "SELECT student_id, name, gpa FROM student"
            )
            rows = cursor.fetchall()
            cursor.close()

            # Convert to dict keyed by student_id for fast lookup
            records = {}
            for row in rows:
                records[str(row["student_id"])] = {
                    "student_id": row["student_id"],
                    "name": row["name"],
                    "gpa": float(row["gpa"])
                }

            blob = {
                "fetched_at": time.time(),
                "record_count": len(records),
                "records": records
            }
            with open(self.path, "w") as f:
                json.dump(blob, f, indent=2)

            # Least-privilege file permissions (owner read/write only)
            try:
                os.chmod(self.path, 0o600)
            except OSError:
                pass  # Windows may not support chmod

            return len(records)

        finally:
            if conn:
                conn.close()

    def get(self, record_id):
        if not os.path.exists(self.path):
            return None
        with open(self.path) as f:
            blob = json.load(f)
        if time.time() - blob["fetched_at"] > self.ttl:
            return None  # stale: refuse to serve
        return blob["records"].get(str(record_id))

    def get_all(self):
        if not os.path.exists(self.path):
            return None, None
        with open(self.path) as f:
            blob = json.load(f)
        if time.time() - blob["fetched_at"] > self.ttl:
            return None, None  # stale: refuse to serve
        return list(blob["records"].values()), blob["fetched_at"]

    def cache_age_seconds(self):
        if not os.path.exists(self.path):
            return None
        with open(self.path) as f:
            blob = json.load(f)
        return time.time() - blob["fetched_at"]

    def secure_delete(self):
        if os.path.exists(self.path):
            try:
                with open(self.path, "r+b") as f:
                    length = os.path.getsize(self.path)
                    f.write(b"\x00" * length)
            except Exception:
                pass
            os.remove(self.path)
if __name__ == "__main__":
    print("=" * 60)
    print("  Resilience — Local Summary Cache Demonstration")
    print("=" * 60)

    cache = LocalSummaryCache(path="session_cache.json", ttl_hours=24)

    # Step 1: Download summaries
    print("\n[1] Downloading critical summary data...")
    count = cache.download_for_session()
    print(f"    Cached {count} student summaries (student_id, name, gpa only)")
    print(f"    Email excluded — least privilege")

    # Step 2: Read from cache
    records, fetched_at = cache.get_all()
    if records:
        age = cache.cache_age_seconds()
        print(f"\n[2] Reading from cache (age: {age:.0f}s):")
        for rec in records[:5]:  # Show first 5
            print(f"    ID={rec['student_id']}  "
                  f"Name={rec['name']}  GPA={rec['gpa']}")
        if len(records) > 5:
            print(f"    ... and {len(records) - 5} more")

    # Step 3: Lookup a single record
    single = cache.get("1")
    if single:
        print(f"\n[3] Single lookup (ID=1): {single}")
    else:
        print("\n[3] No record with ID=1 in cache")

    # Step 4: Secure delete
    print("\n[4] Securely deleting cache file...")
    cache.secure_delete()
    print("    Cache file overwritten with zeros and removed.")

    print("\nDone.")
