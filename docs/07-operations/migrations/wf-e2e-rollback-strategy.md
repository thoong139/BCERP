# wf-e2e v8.0 — Rollback Strategy

## Triggers

- Scenario PASS rate giảm <50%
- Runtime tăng >50% so với v7 baseline
- Critical bug trong v8 (security, data loss)
- Cross-skill consumer break không fix nhanh được

## Procedure

### Step 1: Tag Stable Point

```bash
# TRƯỚC khi merge Tier 0 (chạy 1 lần)
git tag v7-stable-pre-refactor HEAD~1
git push origin v7-stable-pre-refactor
```

### Step 2: Rollback Script

```bash
bash .claude/scripts/wf-e2e-rollback-v8-to-v7.sh
```

Nội dung script:
1. Checkout v7-stable-pre-refactor cho wf-e2e-* files
2. Remove wf-e2e-finding, wf-e2e-batch, wf-e2e-credentials directories
3. Restore wf-e2e-test/SKILL.md monolithic (v1.0.0)
4. Revert e2e-status.template.json về schema v7

### Step 3: Data Migration

```bash
# Convert v8 sessions → v7 compat
for session_dir in .mc-data/work/wf-e2e-verify/sessions/*/; do
  status_file="$session_dir/e2e-status.json"
  if [ -f "$status_file" ] && jq -e '.f0_infra' "$status_file" > /dev/null 2>&1; then
    jq 'del(.f0_infra, .f0a_finding, .f0b_seed, .f6_f5_loops)' "$status_file" > tmp.$$ && mv tmp.$$ "$status_file"
    echo "Migrated (v8→v7): $status_file"
  fi
done
```

### Recovery Time Target

<30 phút từ trigger đến restored functionality.

## Phòng Ngừa

- Chạy integration test scenarios (O4) trước mỗi phase rollout
- Monitor scenario PASS rate sau mỗi deployment
- Alert nếu context overflow >15% (2× baseline)
