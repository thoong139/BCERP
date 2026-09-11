# Fixture: SQL injection via string concatenation
# This file is intentionally vulnerable for SAST probe testing (IMP-013).
# The probe should detect these patterns and emit signals.


def get_user(db, user_id):
    """Return user row by ID — VULNERABLE: SQL string concat."""
    query = "SELECT id, name, email FROM users WHERE id = " + user_id
    return db.execute(query)


def search_users(db, term):
    """Search users by name — VULNERABLE: SQL string concat."""
    sql = "SELECT id, name FROM users WHERE name LIKE '%" + term + "%'"
    return db.execute(sql)


def delete_user(db, user_id):
    """Delete user — VULNERABLE: SQL string concat."""
    stmt = "DELETE FROM users WHERE id = " + str(user_id)
    db.execute(stmt)
