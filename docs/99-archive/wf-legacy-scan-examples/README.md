# wf-legacy-scan v5.0 — Example Outputs

Ba ví dụ output thực tế từ các scenario khác nhau (đã được sanitize — không có secrets/PII).

## Scenarios

| Folder | Dự án | Profile | Ngôn ngữ | Domain |
|--------|-------|---------|---------|--------|
| [`small-en-standard/`](small-en-standard/) | Web app nhỏ (47 files) | standard | English | E-Commerce |
| [`medium-vn-standard/`](medium-vn-standard/) | HR system (183 files) | standard | Vietnamese | HR |
| [`large-mixed-deep/`](large-mixed-deep/) | ERP platform (1,847 files) | deep | Mixed EN/VN | Finance/HR/Ops |

## Files trong mỗi scenario

| File | Mô tả |
|------|-------|
| `scan-state.json` | Pipeline state — session, layers, status, checkpoint |
| `domain-hints.json` | IPS-B domain detection — keywords EN+VN, confidence, agent routing |
| `project-context.md` | Output chính — tech stack, modules, gaps, recommendations |
| `impact-graph.json` | Dependency ripple graph (large-mixed-deep có circular detection) |

## Điểm chú ý

### small-en-standard
- IPS-B detect E-Commerce (0.71) qua English keywords
- standard profile = v4.1 behaviour
- impact-graph không có circular dependencies

### medium-vn-standard
- IPS-B detect HR (0.88) qua Vietnamese keywords (7 từ khoá)
- `language_mix.vn_ratio = 0.68` → Vietnamese-dominant project
- hr-expert được routing cho L5 extraction

### large-mixed-deep
- deep profile → `depth_map.L4/L5 = "deep"` → dual expert routing (finance + hr)
- `synthesis_mode = "full+insights"` (deep profile feature)
- Circular dependency detected: ke-toan ↔ cong-no
- 1 error trong error_log (timeout retry — resolved)
- Workload Gate sẽ trigger trước khi bắt đầu (1,847 files × deep)

## Liên kết

- [User Guide](../../../wf-legacy-scan-v5-guide.md)
- [Release Notes](../../../wf-legacy-scan-v5.0.0-release-notes.md)
- [Design ADRs](../08-tradeoffs-adr.md)
