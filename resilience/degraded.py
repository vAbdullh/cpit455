import time
from watchdog import ServerWatchdog
from local_cache import LocalSummaryCache


# ----------------------------------------------------------------
# Service classification (mirrors Task 1.2)
# ----------------------------------------------------------------
CRITICAL = {"view_students", "search_student", "login", "access_control"}
IMPORTANT = {"add_student", "monitor_health"}
NON_CRITICAL = {"delete_student", "ui_styling"}


def format_age(seconds):
    """Human-readable age string."""
    if seconds is None:
        return "unknown"
    if seconds < 60:
        return f"{seconds:.0f} seconds"
    elif seconds < 3600:
        return f"{seconds / 60:.0f} minutes"
    else:
        return f"{seconds / 3600:.1f} hours"


class ServiceRouter:
    def __init__(self, watchdog, cache):
        self.watchdog = watchdog
        self.cache = cache
        self.queued_writes = []

    def call(self, service, **kw):
       state = self.watchdog.state

        # --- Normal mode: forward to live database ---
        if state == "UP":
            return {
                "status": "ok",
                "message": f"Service '{service}' executed normally.",
                "degraded": False
            }

        # --- Server is DOWN or RECOVERING: degraded mode ---

        # Non-critical services: refuse immediately
        if service in NON_CRITICAL:
            return {
                "status": "unavailable",
                "message": "Non-critical service suspended while the "
                           "system is degraded. Please retry later.",
                "service": service
            }

        # Important services: refuse but with softer message
        if service in IMPORTANT:
            if service == "add_student":
                # Queue the write so no action is lost (recovery)
                self.queued_writes.append({
                    "service": service,
                    "params": kw,
                    "queued_at": time.time()
                })
                return {
                    "status": "queued_offline",
                    "message": "Recorded locally; will sync when "
                               "service returns.",
                    "queue_size": len(self.queued_writes)
                }
            return {
                "status": "unavailable",
                "message": f"Service '{service}' is temporarily "
                           "unavailable. Please retry later.",
                "service": service
            }

        # Critical services: serve from local cache
        if service == "view_students":
            records, fetched_at = self.cache.get_all()
            if records is None:
                return {
                    "status": "unavailable",
                    "message": "No local cache available. "
                               "Critical service cannot be served."
                }
            age_seconds = time.time() - fetched_at
            return {
                "status": "degraded",
                "data": records,
                "degraded": True,
                "cache_age": format_age(age_seconds),
                "cache_age_seconds": age_seconds,
                "message": f"⚠️ DEGRADED MODE: Showing cached data "
                           f"from {format_age(age_seconds)} ago. "
                           f"This data may not reflect recent changes."
            }

        if service == "search_student":
            record = self.cache.get(kw.get("record_id"))
            if record is None:
                return {
                    "status": "unavailable",
                    "message": "No local copy available for this record."
                }
            age_seconds = self.cache.cache_age_seconds()
            result = dict(record)
            result["degraded"] = True
            result["cache_age"] = format_age(age_seconds)
            return {
                "status": "degraded",
                "data": result,
                "degraded": True,
                "cache_age": format_age(age_seconds),
                "message": f"⚠️ DEGRADED: Data is "
                           f"{format_age(age_seconds)} old."
            }

        return {
            "status": "ok",
            "message": f"Service '{service}' allowed in degraded mode.",
            "degraded": state != "UP"
        }

    def get_queued_writes(self):
        """Return all queued offline writes for replay during reinstatement."""
        return list(self.queued_writes)

    def clear_queue(self):
        """Clear the queue after successful replay."""
        self.queued_writes.clear()


# ----------------------------------------------------------------
# Demonstration
# ----------------------------------------------------------------
if __name__ == "__main__":
    print("=" * 60)
    print("  Resilience — Degraded-Mode Service Router Demo")
    print("=" * 60)

    # Create components
    HEALTH_URL = "http://localhost:8080/StudentWebApp/login.jsp"
    watchdog = ServerWatchdog(HEALTH_URL, timeout=2.0, failures_before_alarm=3)
    cache = LocalSummaryCache(path="session_cache.json", ttl_hours=24)

    # Step 1: Download cache while server is up
    print("\n[1] Downloading local cache while server is available...")
    try:
        count = cache.download_for_session()
        print(f"    Cached {count} records.")
    except Exception as e:
        print(f"    Could not connect to DB: {e}")
        print("    Creating a dummy cache for demo purposes...")
        import json
        dummy = {
            "fetched_at": time.time(),
            "record_count": 2,
            "records": {
                "1": {"student_id": 1, "name": "Ahmad Ali", "gpa": 3.8},
                "2": {"student_id": 2, "name": "Sara Khan", "gpa": 3.5}
            }
        }
        with open("session_cache.json", "w") as f:
            json.dump(dummy, f)

    router = ServiceRouter(watchdog, cache)

    # Step 2: Test in normal mode (UP)
    print("\n[2] System is UP — normal operation:")
    watchdog.state = "UP"
    result = router.call("view_students")
    print(f"    view_students → {result['status']}: {result['message']}")
    result = router.call("delete_student", record_id=1)
    print(f"    delete_student → {result['status']}: {result['message']}")

    # Step 3: Simulate DOWN
    print("\n[3] System is DOWN — degraded mode:")
    watchdog.state = "DOWN"

    result = router.call("view_students")
    print(f"    view_students → {result['status']}")
    print(f"      {result['message']}")
    if result.get("data"):
        print(f"      Records served: {len(result['data'])}")

    result = router.call("delete_student", record_id=1)
    print(f"    delete_student → {result['status']}: {result['message']}")

    result = router.call("add_student", name="Test", gpa=3.0)
    print(f"    add_student → {result['status']}: {result['message']}")
    print(f"      Queued writes: {result['queue_size']}")

    result = router.call("add_student", name="Test2", gpa=3.5)
    print(f"    add_student → {result['status']}: {result['message']}")
    print(f"      Queued writes: {result['queue_size']}")

    # Step 4: Show queued writes
    print(f"\n[4] Queued writes for replay: {len(router.get_queued_writes())}")
    for w in router.get_queued_writes():
        print(f"    Service={w['service']} Params={w['params']}")

    # Cleanup
    cache.secure_delete()
    print("\n[5] Cache securely deleted.")
    print("\nDone.")
