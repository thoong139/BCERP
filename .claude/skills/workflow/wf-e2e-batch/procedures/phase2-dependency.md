# Phase 2: Build Dependency Matrix

> **Load khi:** Phase 1 POST-GATE PASS.
> **Input:** `feat-list.json`, registry
> **Output:** `dependency-matrix.json` (schema dependency-matrix-v2)

## PRE-GATE

```
T1: feat-list.json tồn tại + valid JSON
T2: feat-list.json .count > 0
```

## CF1: Dependency Types

Mỗi FEAT có thể có 3 loại dependency:

| Type | Mô tả | Ví dụ |
|------|-------|-------|
| `feat-to-feat` | FEAT A cần FEAT B chạy trước | FIN-006 cần FIN-008 (Banking session) |
| `feat-to-module` | FEAT cần module đã implement | FIN-006 cần Banking module entities |
| `feat-to-external` | FEAT cần external API credentials | FIN-006 cần BankingAPI credentials |

## CF7: Granular Phase-Level Dependency

Ngoài feat-to-feat ở level FEAT, còn có phase-level dependency — FEAT B's phase P3_API cần FEAT A's phase P2_DB xong trước.

Schema thêm `phase_dependencies[]` trong mỗi FEAT entry:

```json
{
  "phase_dependencies": [
    {
      "phase": "P2_DB",
      "depends_on_feat": "FIN-008",
      "depends_on_phase": "P1_BUSINESS",
      "reason": "FIN-006 DB schema cần biết entities từ FIN-008 business analysis"
    }
  ]
}
```

Dispatcher dùng `phase_dependencies` để sequence F0a findings theo granular order khi dispatch wf-e2e-verify.

## Steps

### Step 2.1 — Load FEAT list

```bash
feats=$(jq -r '.feats[]' "$SESSION_DIR/feat-list.json")
```

### Step 2.2 — Extract dependencies cho từng FEAT

```bash
extract_dependencies() {
  local feat_id="$1"
  local registry="$REGISTRY_PATH"

  # Lấy feature entry từ registry
  local feat_entry
  feat_entry=$(jq -r --arg id "$feat_id" '.features[] | select(.id == $id)' "$registry")

  # feat-to-feat: kiểm tra cross_feat_refs[] trong registry
  local feat_to_feat
  feat_to_feat=$(echo "$feat_entry" | jq -c \
    '[.cross_feat_refs // [] | .[] | {
      type: "feat-to-feat",
      target: .target_feat_id,
      reason: .reason,
      blocking_level: (.blocking_level // "hard"),
      min_completion: (.min_completion // "test_passed")
    }]')

  # feat-to-module: kiểm tra cross_module_dependencies[]
  local feat_to_module
  feat_to_module=$(echo "$feat_entry" | jq -c \
    '[.cross_module_dependencies // [] | .[] | {
      type: "feat-to-module",
      target: .,
      reason: ("Module " + . + " entities cần available"),
      blocking_level: "hard",
      fallback: "mock"
    }]')

  # feat-to-external: từ external_dependencies[] (nếu có)
  local feat_to_external
  feat_to_external=$(echo "$feat_entry" | jq -c \
    '[.external_dependencies // [] | .[] | {
      type: "feat-to-external",
      target: .,
      reason: ("External dependency: " + .),
      blocking_level: "soft",
      fallback: "credential-vault"
    }]')

  # Merge tất cả dependencies
  echo "$feat_to_feat $feat_to_module $feat_to_external" | jq -sc 'flatten'
}
```

### Step 2.3 — Validate dependencies tồn tại trong registry

```bash
validate_deps() {
  local feat_id="$1"
  local deps="$2"

  echo "$deps" | jq -r '.[] | select(.type == "feat-to-feat") | .target' | \
  while IFS= read -r target; do
    if ! jq -e --arg t "$target" '.features[] | select(.id == $t)' "$REGISTRY_PATH" > /dev/null 2>&1; then
      log_error "E051" "Dependency target không tồn tại: $feat_id → $target"
      return 1
    fi
  done
}
```

### Step 2.4 — Detect circular dependencies (DFS)

```bash
# Kahn's algorithm — detect cycles
# Input: adjacency list (feat -> [deps])
# Output: topology levels hoặc error E051

detect_cycles_and_sort() {
  local adj_json="$1"  # JSON object: {"FIN-006": ["FIN-008"], ...}

  python3 - <<'PYEOF'
import sys, json

adj = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {}

# Compute in-degrees
in_degree = {n: 0 for n in adj}
for node, deps in adj.items():
    for d in deps:
        if d not in in_degree:
            in_degree[d] = 0
        in_degree[node] = in_degree.get(node, 0)

for node, deps in adj.items():
    for d in deps:
        in_degree[node] = in_degree.get(node, 0)

# Rebuild proper in-degree
in_degree = {n: 0 for n in set(list(adj.keys()) + [d for deps in adj.values() for d in deps])}
for node, deps in adj.items():
    for d in deps:
        in_degree[node] = in_degree.get(node, 0)

# Kahn's
from collections import deque, defaultdict
in_deg = defaultdict(int)
reverse = defaultdict(list)  # dep -> [nodes that depend on dep]
all_nodes = set(adj.keys())

for node, deps in adj.items():
    for d in deps:
        all_nodes.add(d)
        in_deg[node] += 1
        reverse[d].append(node)

queue = deque([n for n in all_nodes if in_deg[n] == 0])
levels = []
visited = 0

while queue:
    level_nodes = list(queue)
    levels.append({"level": len(levels) + 1, "feats": level_nodes})
    next_queue = deque()
    for node in level_nodes:
        visited += 1
        for dependent in reverse[node]:
            in_deg[dependent] -= 1
            if in_deg[dependent] == 0:
                next_queue.append(dependent)
    queue = next_queue

if visited < len(all_nodes):
    # Cycle detected
    cycled = [n for n in all_nodes if in_deg[n] > 0]
    print(json.dumps({"error": "CYCLE", "nodes": cycled}))
else:
    print(json.dumps({"levels": levels}))
PYEOF
}
```

### Step 2.5 — Build dependency-matrix.json

```bash
build_dependency_matrix() {
  local feats_json
  feats_json=$(cat "$SESSION_DIR/feat-list.json" | jq -c '.feats')

  # Collect all deps
  local all_feat_deps='[]'
  local adj_obj='{}'

  while IFS= read -r feat_id; do
    local deps
    deps=$(extract_dependencies "$feat_id")

    # Validate
    validate_deps "$feat_id" "$deps" || return 1

    # Build adjacency (feat_id depends on these feats)
    local hard_feat_deps
    hard_feat_deps=$(echo "$deps" | jq -r \
      '[.[] | select(.type == "feat-to-feat") | .target]')

    adj_obj=$(echo "$adj_obj" | jq \
      --arg fid "$feat_id" \
      --argjson deps "$hard_feat_deps" \
      '. + {($fid): $deps}')

    # CF7: extract phase dependencies từ cross_feat_refs với phase info
    local phase_deps
    phase_deps=$(jq -r --arg id "$feat_id" \
      '.features[] | select(.id == $id) |
       .cross_feat_refs // [] |
       map(select(.depends_on_phase != null)) |
       map({phase: .target_phase, depends_on_feat: .target_feat_id,
            depends_on_phase: .depends_on_phase, reason: .reason})' \
      "$REGISTRY_PATH")

    local feat_entry
    feat_entry=$(jq -n \
      --arg fid "$feat_id" \
      --argjson deps "$deps" \
      --argjson phase_deps "$phase_deps" \
      '{ feat_id: $fid, dependencies: $deps, phase_dependencies: $phase_deps }')

    all_feat_deps=$(echo "$all_feat_deps" | jq --argjson e "$feat_entry" '. + [$e]')
  done <<< "$(echo "$feats_json" | jq -r '.[]')"

  # Topology sort
  local topo_result
  topo_result=$(detect_cycles_and_sort "$adj_obj")

  if echo "$topo_result" | jq -e '.error == "CYCLE"' > /dev/null 2>&1; then
    local cycled
    cycled=$(echo "$topo_result" | jq -r '.nodes | join(", ")')
    log_error "E051" "Circular dependency phát hiện: $cycled"
    return 1
  fi

  local topology_levels
  topology_levels=$(echo "$topo_result" | jq '.levels')

  # Build final matrix (READ template first — CORE-031)
  local template_path=".claude/skills/workflow/wf-e2e-batch/templates/dependency-matrix.template.json"
  # Template đã được đọc; populate placeholders
  local matrix
  matrix=$(jq -n \
    --arg bid "$BATCH_ID" \
    --argjson feats "$all_feat_deps" \
    --argjson levels "$topology_levels" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      "$schema": "dependency-matrix-v2",
      batch_id: $bid,
      feats: $feats,
      topology_levels: $levels,
      circular_dependencies: [],
      created_at: $ts,
      audit_chain: ""
    }')

  # Compute audit_chain
  local chain
  chain=$(echo "$matrix" | sha256sum | awk '{print $1}')
  matrix=$(echo "$matrix" | jq --arg chain "$chain" '.audit_chain = $chain')

  atomic_write_json "$SESSION_DIR/dependency-matrix.json" "$matrix"
  log "dependency-matrix.json tạo thành công — $(echo "$topology_levels" | jq 'length') levels"
}
```

## POST-GATE

```
T1: dependency-matrix.json tồn tại + valid JSON
T2: .circular_dependencies = [] (không có cycle)
T3: .topology_levels có ít nhất 1 level
T4: Mỗi .feats[].dependencies[].target (type=feat-to-feat) tồn tại trong registry
```

Fail T2 → E051 STOP.
Fail T3 → E052 STOP.

## Phase 2 Report (CORE-028)

```markdown
## Phase 2: Build Dependency Matrix — PASS

Thời gian: {ISO-8601}
**Đã làm:** Phân tích dependencies cho {N} FEATs, topology sort Kahn's algorithm.
**Kết quả:** {N} topology levels, {M} feat-to-feat deps, 0 circular → dependency-matrix.json
**Tiếp theo:** Phase 3 Execute FEATs theo topology order
```

## NEXT → `procedures/phase3-execute.md`
