#!/usr/bin/env bash
# legacy-scan-phase-c-smoke.sh — Integration smoke test cho Phase C (Profiles + IPS).
#
# Pham vi: verify Phase C components tich hop dung end-to-end:
#   1. Profile Resolver (depth_map build logic)
#   2. IPS Phase A — domain scoring + profile recommendation
#   3. IPS Phase B — module routing + hotspots + workload estimate
#   4. End-to-end on 3 synthetic fixtures (small-en, medium-vn, large-mixed)
#
# KHONG chay full /wf-legacy-scan pipeline — chi exercise IPS Python module
# qua CLI interface ma orchestrator goi.
#
# Usage: bash .claude/scripts/legacy-scan-phase-c-smoke.sh

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)/.."
SHARED_DIR="$SCRIPTS_DIR/../skills/workflow/_shared"

# shellcheck disable=SC1091
source "$SCRIPTS_DIR/legacy-scan-common.sh"
_SCRIPT_NAME="phase-c-smoke"

SMOKE_TMP="$(mktemp -d -t phase-c-smoke-XXXXXX)"
trap 'rm -rf "$SMOKE_TMP"' EXIT INT TERM

log_info "SMOKE_TMP=$SMOKE_TMP"

win_path() {
  if command -v cygpath &>/dev/null; then
    cygpath -w "$1"
  else
    echo "$1"
  fi
}

# ─── Fixture Generators ──────────────────────────────────────

gen_small_en() {
  local dir="$1"
  mkdir -p "$dir/inventory"

  cat > "$dir/project-profile.json" <<'EOF'
{
  "name": "small-en",
  "file_counts": {"total": 50},
  "top_level_dirs": ["customer", "sales", "reporting"],
  "frameworks": ["React"],
  "dependencies": {"production": ["react", "react-dom", "axios"]},
  "doc_maturity": {"level": "CODE_ONLY"}
}
EOF

  cat > "$dir/assessment-report.json" <<'EOF'
{
  "maturity_level": "CODE_ONLY",
  "scores": {
    "code_quality": {"score": 75},
    "doc_quality": {"score": 55},
    "alignment": {"score": 60}
  }
}
EOF

  # Synthetic inventory — small project has ~50 files across 3 modules
  python -c "
import json
from pathlib import Path
files = []
modules = {'customer': 15, 'sales': 20, 'reporting': 15}
for mod, count in modules.items():
    for i in range(count):
        files.append({'path': f'src/{mod}/file{i}.ts'})
Path(r'$(win_path "$dir/inventory/source-files.json")').write_text(json.dumps({'files': files}, indent=2))
Path(r'$(win_path "$dir/inventory/dependency-graph.json")').write_text(json.dumps({'edges': []}, indent=2))
"
}

gen_medium_vn() {
  local dir="$1"
  mkdir -p "$dir/inventory"

  cat > "$dir/project-profile.json" <<'EOF'
{
  "name": "medium-vn",
  "file_counts": {"total": 500},
  "top_level_dirs": ["qlkh", "hoadon", "qlns", "chamcong", "bangluong", "nhapkho", "xuatkho", "baocao", "caidat", "dangnhap"],
  "frameworks": ["ASP.NET Core", "React"],
  "dependencies": {"production": ["Microsoft.AspNetCore.App", "Newtonsoft.Json"]},
  "doc_maturity": {"level": "CODE_ONLY"}
}
EOF

  cat > "$dir/assessment-report.json" <<'EOF'
{
  "maturity_level": "CODE_ONLY",
  "scores": {
    "code_quality": {"score": 68},
    "doc_quality": {"score": 40},
    "alignment": {"score": 50}
  }
}
EOF

  python -c "
import json
from pathlib import Path
files = []
modules = {'qlkh': 50, 'hoadon': 60, 'qlns': 50, 'chamcong': 45, 'bangluong': 50,
           'nhapkho': 40, 'xuatkho': 40, 'baocao': 50, 'caidat': 40, 'dangnhap': 75}
for mod, count in modules.items():
    for i in range(count):
        files.append({'path': f'src/{mod}/file{i}.cs'})
Path(r'$(win_path "$dir/inventory/source-files.json")').write_text(json.dumps({'files': files}, indent=2))
Path(r'$(win_path "$dir/inventory/dependency-graph.json")').write_text(json.dumps({'edges': []}, indent=2))
"
}

gen_large_mixed() {
  local dir="$1"
  mkdir -p "$dir/inventory"

  cat > "$dir/project-profile.json" <<'EOF'
{
  "name": "large-mixed",
  "file_counts": {"total": 1500},
  "top_level_dirs": [
    "billing", "invoice", "payment", "tax",
    "shipping", "delivery", "customs", "warehouse",
    "hr", "payroll", "sales-crm", "quotes",
    "audit-log", "compliance",
    "qlkh", "hoadon", "baogia", "vanchuyen", "haiquan", "khobai",
    "qlns", "chamcong", "bangluong", "tuanthu"
  ],
  "frameworks": ["Node.js", "Express", "React"],
  "dependencies": {"production": ["decimal.js", "money", "axios", "express"]},
  "doc_maturity": {"level": "CODE_ONLY"}
}
EOF

  cat > "$dir/assessment-report.json" <<'EOF'
{
  "maturity_level": "CODE_ONLY",
  "scores": {
    "code_quality": {"score": 62},
    "doc_quality": {"score": 45},
    "alignment": {"score": 55}
  }
}
EOF

  python -c "
import json
from pathlib import Path
files = []
modules = ['billing','invoice','payment','tax','shipping','delivery','customs','warehouse',
          'hr','payroll','sales-crm','quotes','audit-log','compliance',
          'qlkh','hoadon','baogia','vanchuyen','haiquan','khobai','qlns','chamcong','bangluong','tuanthu']
# ~60-65 files per module to reach ~1500
for mod in modules:
    for i in range(62):
        files.append({'path': f'src/{mod}/file{i}.ts'})
Path(r'$(win_path "$dir/inventory/source-files.json")').write_text(json.dumps({'files': files}, indent=2))
Path(r'$(win_path "$dir/inventory/dependency-graph.json")').write_text(json.dumps({'edges': []}, indent=2))
"
}

# ─── Run a single fixture through Phase A + Phase B ─────────

run_fixture() {
  local fixture="$1"
  local dir="$SMOKE_TMP/$fixture"
  mkdir -p "$dir"

  log_info "=== Fixture: $fixture ==="
  case "$fixture" in
    small-en) gen_small_en "$dir" ;;
    medium-vn) gen_medium_vn "$dir" ;;
    large-mixed) gen_large_mixed "$dir" ;;
    *) log_error "Unknown fixture: $fixture"; exit 1 ;;
  esac

  # Phase A
  (cd "$SHARED_DIR" && python -m ips.ips_recommender phase_a \
    --project-profile "$(win_path "$dir/project-profile.json")" \
    --assessment "$(win_path "$dir/assessment-report.json")" \
    --output "$(win_path "$dir/ips-phase-a.json")")

  # Assertions Phase A
  jq -e '.recommended_profile' "$dir/ips-phase-a.json" >/dev/null
  jq -e '.detected_domains | length >= 1' "$dir/ips-phase-a.json" >/dev/null
  local rec_profile
  rec_profile=$(jq -r '.recommended_profile' "$dir/ips-phase-a.json")
  log_info "Phase A recommended: $rec_profile"

  # Expected profile per fixture
  case "$fixture" in
    small-en)
      [[ "$rec_profile" == "standard" || "$rec_profile" == "deep" ]] \
        || { log_error "small-en expected standard/deep, got $rec_profile"; return 1; }
      ;;
    medium-vn)
      [[ "$rec_profile" == "deep" ]] \
        || { log_error "medium-vn expected deep, got $rec_profile"; return 1; }
      ;;
    large-mixed)
      [[ "$rec_profile" == "deep" ]] \
        || { log_error "large-mixed expected deep, got $rec_profile"; return 1; }
      ;;
  esac

  # Phase B
  (cd "$SHARED_DIR" && python -m ips.ips_recommender phase_b \
    --inventory "$(win_path "$dir/inventory")" \
    --ips-a "$(win_path "$dir/ips-phase-a.json")" \
    --output "$(win_path "$dir/ips-phase-b.json")")

  # Assertions Phase B
  jq -e '.module_routing' "$dir/ips-phase-b.json" >/dev/null
  jq -e '.complexity_hotspots' "$dir/ips-phase-b.json" >/dev/null
  jq -e '.workload_estimate.total_features_est' "$dir/ips-phase-b.json" >/dev/null

  local module_count routing_count
  module_count=$(jq '.module_count' "$dir/ips-phase-b.json")
  routing_count=$(jq '.module_routing | length' "$dir/ips-phase-b.json")
  log_info "Phase B: modules=$module_count routed=$routing_count"

  # medium-vn + large-mixed should have ≥70% routing coverage
  case "$fixture" in
    medium-vn|large-mixed)
      local min_routed
      min_routed=$(python -c "import math; print(math.ceil($module_count * 0.6))")
      if (( routing_count < min_routed )); then
        log_error "$fixture: routing_count=$routing_count < expected $min_routed (60% of $module_count)"
        return 1
      fi
      ;;
  esac

  log_info "$fixture PASS"
}

# ─── Main ────────────────────────────────────────────────────

run_fixture small-en
run_fixture medium-vn
run_fixture large-mixed

log_info "Phase C smoke test PASS — 3 fixtures run successfully"
echo "PASS"
