from security.audit import audit

# Roles that may read any record regardless of ownership
PRIVILEGED_ROLES = {"admin", "safety_officer"}
# Roles that see redacted personal data
REDACTED_ROLES   = {"clerk"}


def read_student_record(
    db,
    requesting_user: str,
    requesting_role: str,
    student_id: int,
) -> dict | None:
    row = db.query(
        "SELECT owner_username, name, email, gpa FROM student WHERE student_id = ?",
        (student_id,),
    )
    if not row:
        return None

    owner, name, email, gpa = row[0]

    # SECGUIDE-2: second ownership gate (beyond application-level role check)
    if owner != requesting_user and requesting_role not in PRIVILEGED_ROLES:
        audit(
            requesting_user,
            "RECORD_DENY",
            f"student_id={student_id} owner={owner} (IDOR attempt)",
        )
        raise PermissionError("not your record")  # blocks the IDOR attack

    # SECGUIDE-8 / SEC5: redact personal fields for low-privilege roles
    if requesting_role in REDACTED_ROLES:
        email = "***REDACTED***"

    return {"student_id": student_id, "owner": owner,
            "name": name, "email": email, "gpa": gpa}


def change_safety_flag(
    db,
    requesting_user: str,
    requesting_role: str,
    new_value: bool,
) -> None:
    if requesting_role not in PRIVILEGED_ROLES:
        audit(requesting_user, "SAFETY_FLAG_DENY",
              f"attempted change to {new_value}")
        raise PermissionError("not authorised to alter safety configuration")
    # The actual DB/application update is done in the calling layer.
    audit(requesting_user, "SAFETY_FLAG_CHANGE",
          f"new_value={new_value}")
