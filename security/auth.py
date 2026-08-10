import re, time
from werkzeug.security import generate_password_hash as gen_hash, check_password_hash as check_hash

SESSION_TIMEOUT, MAX_FAILS, LOCKOUT_WINDOW = 900, 5, 600
_failed = {}

class WeakPasswordError(Exception): pass
class AccountLockedError(Exception): pass

def _lockout_status(user: str, add_fail: bool = False) -> bool:
    from security.audit import audit
    fails = [t for t in _failed.get(user, []) if time.time() - t < LOCKOUT_WINDOW]
    if add_fail:
        fails.append(time.time())
        if len(fails) >= MAX_FAILS: audit("system", "ACCOUNT_LOCKED", f"username={user}")
    _failed[user] = fails
    return len(fails) >= MAX_FAILS

def register_user(db, username: str, password: str, role: str = "user"):
    if len(password) < 12 or not all(re.search(p, password) for p in [r"[a-z]", r"[A-Z]", r"\d", r"[^\w\s]"]):
        raise WeakPasswordError("Weak password.")
    db.execute("INSERT INTO users(username, pw_hash, role) VALUES (?, ?, ?)", (username, gen_hash(password), role))

def verify_login(db, username: str, password: str):
    from security.audit import audit
    if _lockout_status(username): raise AccountLockedError("Locked.")
    
    row = db.query("SELECT pw_hash, role FROM users WHERE username = ?", (username,))
    if row and check_hash(row[0][0], password):
        _failed.pop(username, None)
        audit(username, "LOGIN_OK", "")
        return {"username": username, "role": row[0][1], "login_time": time.time()}
        
    _lockout_status(username, add_fail=True)
    audit("anon" if not row else username, "LOGIN_FAIL", f"username={username} reason={'unknown_user' if not row else 'bad_password'}")
    return None

def session_expired(session: dict) -> bool:
    return time.time() - session.get("login_time", 0) > SESSION_TIMEOUT