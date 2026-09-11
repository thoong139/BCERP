# Change Plan — [Change Summary]

| Field | Value |
|-------|-------|
| **Change ID** | {CHANGE_ID} |
| **Change Type** | {CHANGE_TYPE} |
| **Total Tasks** | {N} |
| **Risk Level** | {LEVEL} |
| **Estimated Complexity** | {LOW/MEDIUM/HIGH} |

## Execution Tasks

### Group 1: Registry & Requirements
| # | File | Action | Mo ta | Verify |
|---|------|--------|-------|--------|
| 1 | [path] | UPDATE | [mo ta] | jq validate |

### Group 2: Feature Specs & Architecture
| # | File | Action | Mo ta | Verify |
|---|------|--------|-------|--------|
| 2 | [path] | UPDATE | [mo ta] | REQ-ID check |

### Group 3: Code Changes
| # | File | Action | REQ-IDs | Mo ta | Verify |
|---|------|--------|---------|-------|--------|
| 3 | [path] | MODIFY | [IDs] | [mo ta] | compile |

### Group 4: Test Changes
| # | File | Action | Mo ta | Verify |
|---|------|--------|-------|--------|
| 4 | [path] | UPDATE | [mo ta] | test pass |

## Execution Order
1. Group 1 (Registry) → validate
2. Group 2 (Docs) → mini-verify sau moi file
3. Group 3 (Code) → mini-verify sau moi file
4. Group 4 (Tests) → run tests

## Checkpoint Strategy
- Checkpoint sau: Group 2 (docs done), Group 3 (code done)

## Rollback Plan
- Registry: restore tu backup `req-registry.json.pre-change-*`
- Code: `git checkout -- [files]`
