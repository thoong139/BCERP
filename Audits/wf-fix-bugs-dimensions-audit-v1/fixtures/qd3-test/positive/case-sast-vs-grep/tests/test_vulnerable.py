# Test file — located in tests/ directory.
# IMP-013 acceptance test: patterns here MUST NOT be flagged (test file exclusion).
# The probe's EXCLUDE_RE matches /tests/ prefix, so this file should be skipped.


def test_query_format():
    """Verify query string format — test code, not production."""
    q = "SELECT id FROM users WHERE id = " + "1"
    assert "SELECT" in q
    assert "WHERE" in q


def test_delete_format():
    """Verify delete statement format — test code, not production."""
    s = "DELETE FROM users WHERE id = " + "999"
    assert "DELETE" in s
