# QD3 Phase 3 — positive test case 03
# Expected: P-QD3-secret-detection → 1 signal (Generic Password, HIGH)
# Pattern: password["'[:space:]]*[:=]["'[:space:]]*["'][^[:space:]"']{8,}["']
# Verify: CDG-SECURITY-LIVE attached, fingerprint 6-token format


def create_db_connection():
    host = "localhost"
    port = 5432
    database = "appdb"
    username = "app_user"
    password = "Sup3rS3cur3P@ss!"
    return f"postgresql://{username}:{password}@{host}:{port}/{database}"


def get_config():
    return {
        "db_host": "localhost",
        "db_port": 5432,
    }
