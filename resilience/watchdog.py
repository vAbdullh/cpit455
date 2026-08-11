import time
import requests

class ServerWatchdog:
    def __init__(self, health_url, timeout=2.0, failures_before_alarm=3):
        self.health_url = health_url
        self.timeout = timeout
        self.threshold = failures_before_alarm
        self.consecutive_failures = 0
        self.state = "UP"

    def poll(self) -> str:
        try:
            r = requests.get(self.health_url, timeout=self.timeout)
            ok = (r.status_code == 200)
        except Exception:
            ok = False

        if ok:
            self.consecutive_failures = 0
            if self.state == "DOWN":
                self.state = "RECOVERING"
            else:
                self.state = "UP"
        else:
            self.consecutive_failures += 1
            if self.consecutive_failures >= self.threshold:
                self.state = "DOWN"

        return self.state

if __name__ == "__main__":
    HEALTH_URL = "http://localhost:8080/StudentWebApp/login.jsp"

    wd = ServerWatchdog(HEALTH_URL, timeout=2.0, failures_before_alarm=3)

    print("Watchdog started - polling every 5 seconds")
    print(f"  Health URL : {HEALTH_URL}")
    print(f"  Timeout    : {wd.timeout}s")
    print(f"  Threshold  : {wd.threshold} consecutive failures")
    print("-" * 55)

    try:
        while True:
            state = wd.poll()
            ts = time.strftime("%H:%M:%S")
            failures = wd.consecutive_failures

            if state == "UP":
                status = "UP"
            elif state == "RECOVERING":
                status = "RECOVERING"
            else:
                status = "DOWN"

            print(f"[{ts}] State={status:12s}  "
                  f"Consecutive failures={failures}")

            time.sleep(5)

    except KeyboardInterrupt:
        print("\nWatchdog stopped.")
