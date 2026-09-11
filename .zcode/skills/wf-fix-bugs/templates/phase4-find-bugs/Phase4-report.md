## Phase 4: Find Bugs — [STATUS_PASS_FAIL]

Thời gian: [STARTED_AT] → [COMPLETED_AT]
Session ID: [SESSION_ID]

**Đã làm:** Dispatch [LANES_TOTAL] lane agents song song (max 10) để scan signals theo từng dimension. Mỗi lane chạy static-scan, runtime, llm-scan (nếu --llm-scan). Playwright: [PLAYWRIGHT_SUMMARY].

**Kết quả:** [LANES_COMPLETED]/[LANES_TOTAL] lanes hoàn tất. Tổng [TOTAL_SIGNALS] signals (Static [STATIC_TOTAL] / Runtime [RUNTIME_TOTAL] / LLM [LLM_TOTAL]). Mức độ: [SEV_CRIT] CRITICAL, [SEV_HIGH] HIGH. Probe failures: [PROBE_FAILURES_TOTAL].

**Chi tiết (cho downstream + audit):** `[SUMMARY_PATH]` — cross-lane rollup gồm severity/fixability breakdown, registry coverage (REQ-ID/FEAT-ID/MODULE), evidence index, CDG decisions, audit chain (sha256). File `lanes/QD*/` chứa per-lane signals + evidence.

**Tiếp theo:** Phase 5 — Triage (aggregate + classify + CDG handoff). Nếu N=0 → jump Phase 7.
