"""
security/access.py  –  Application-level authorisation
SECGUIDE-2  Avoid single point of failure: auth + authz are independent checks
SECGUIDE-8  Compartmentalise assets: roles segment the application
"""
from functools import wraps
from security.auth import session_expired
from security.audit import audit


# ---------------------------------------------------------------------------
# Decorator: authentication gate
# ---------------------------------------------------------------------------
def login_required(f):
    """
    SECGUIDE-2 / SECGUIDE-3: first protection layer.  If the session is
    absent OR has timed out, clear it and refuse the request (fail securely).
    """
    @wraps(f)
    def wrapper(session, *a, **kw):
        if "username" not in session or session_expired(session):
            session.clear()       # SECGUIDE-3: wipe stale session on expiry
            raise PermissionError("not authenticated")   # -> HTTP 401
        return f(session, *a, **kw)
    return wrapper


# ---------------------------------------------------------------------------
# Decorator: authorisation gate
# ---------------------------------------------------------------------------
def role_required(*roles):
    """
    SECGUIDE-8: compartmentalise.  Only callers whose session role is listed
    in `roles` may proceed.  All denials are audited (SECGUIDE-5).
    """
    def deco(f):
        @wraps(f)
        def wrapper(session, *a, **kw):
            user_role = session.get("role", "")
            if user_role not in roles:
                audit(
                    session.get("username", "anon"),
                    "AUTHZ_DENY",
                    f"action={f.__name__} required={roles} actual={user_role}",
                )
                raise PermissionError("not authorised")  # -> HTTP 403
            return f(session, *a, **kw)
        return wrapper
    return deco


def get_record(db, table: str, column: str, value) -> list:
    """
    Generic parameterised fetch.  The placeholder ? ensures the driver
    escapes `value` as a literal; it can never alter the SQL syntax.
    """
    return db.query(f"SELECT * FROM {table} WHERE {column} = ?", (value,))
