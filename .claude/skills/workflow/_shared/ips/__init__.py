"""IPS — Intelligent Profile & Strategy module cho wf-legacy-scan v5.0.

Components:
- ips_recommender: 2-phase domain detection + profile recommendation (Phase C).
- domain_scorer: Domain signal scoring + confidence computation (Phase C).
- vietnamese_keywords: VN keyword pool + normalize_vn (Phase A.7 + Phase C).
- workload_estimator: Workload estimation cho profile planning (Phase C).
- scan_state_reader: Helper API cho scan-state.json read/write + state machine
  (Phase B + Phase D full API + Phase E L3 partial + write throttle).
- concurrency_controller: 3-tier token bucket (Phase E Task E.3).
- agent_timeout: Per-agent timeout resolution + watchdog registry
  (Phase E Task E.4).
- scan_cache: Content-addressable 2-tier scan cache
  (Phase E Tasks E.5 / E.6 / E.7).
- impact_graph_builder: Build impact-graph.json tu L3/L4/L5 outputs
  (Phase F Task F.1).
- incremental: Staleness detection + delta classification + auto-upgrade
  (Phase F Task F.3).
- workload_gate: Detect + WARN when workload exceeds thresholds, 3 options
  (continue-as-is / downgrade-profile / abort) — Phase F Task F.5 (v5.0 scope
  detect-only; Partition Planner defer v5.1).
- resume_router: 4-Level Resume Router cho `/wf-legacy-scan --resume` —
  discover latest session, read scan-state.json, decide finest-granularity
  resumption point (Phase H Task H.1).

Reference:
- docs/design/skills/wf-legacy-scan/05-profiles-ips.md
- docs/design/skills/wf-legacy-scan/10-vietnamese-keywords.md
- docs/design/skills/wf-legacy-scan/04-data-model.md §1 + §2.2 + §7
- docs/design/skills/wf-legacy-scan/08-tradeoffs-adr.md ADR-LS10/11/12/14
"""

__version__ = "5.0.0-phase-H"
