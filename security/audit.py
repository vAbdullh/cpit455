import logging
import datetime
from functools import wraps

# SECGUIDE-9: log path configurable; in production use environment variable
LOG_FILE = "security/security_audit.log"

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(message)s",           # we control the format ourselves below
)
_log = logging.getLogger("security.audit")


def audit(user: str, action: str, detail: str = "") -> None:
    ts = datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z"
    _log.info("%s  user=%s  action=%s  %s", ts, user, action, detail)


def safe_handler(f):
    @wraps(f)
    def wrapper(*a, **kw):
        try:
            return f(*a, **kw)
        except PermissionError as pe:
            audit("system", "ACCESS_DENIED", str(pe))
            return {"error": "access denied"}, 403   # SECGUIDE-3: generic message
        except Exception:
            audit("system", "INTERNAL_ERROR", f.__name__)
            # SECGUIDE-3: no detail to the client
            return {"error": "request could not be completed"}, 500
    return wrapper
