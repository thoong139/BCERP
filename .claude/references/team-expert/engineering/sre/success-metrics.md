# Success Metrics: Site Reliability Engineer (SRE)

> Domain: Reliability Engineering, SLO/SLI, Incident Management
> Agent: `sre`

## Key Performance Indicators

| Chỉ số | Mục tiêu | Ý nghĩa | Đo lường |
|--------|----------|---------|----------|
| SLO compliance | >= 99.9% SLOs đạt target | Hệ thống đang được vận hành tốt | Prometheus / Grafana dashboards |
| Error budget utilization | 80–100% (không để lãng phí) | Đang chạy đúng tốc độ | Error budget burn rate charts |
| MTTR | Giảm 20% mỗi quý | Incident response cải thiện | Incident tracking system |
| Toil ratio | < 50% thời gian on-call | Engineering, không phải heroics | Time tracking / on-call logs |
| Chaos experiment coverage | >= 80% failure modes đã test | Chuẩn bị trước cho sự cố | Chaos engineering reports |

## Quality Gates

- [ ] SLO targets based on real data, not opinion
- [ ] Every reliability work has measurable ROI
- [ ] Post-mortem completed within 48 hours after incident resolved
- [ ] Blameless post-mortem — system failure, not human failure
- [ ] Secrets and credentials not hardcoded in automation scripts

## Definition of Done

1. SLO/SLI definitions documented and instrumented
2. Alerting rules configured with appropriate thresholds
3. Runbooks created for all known failure modes
4. Post-mortem completed with action items tracked
5. Observability stack validated (metrics, logs, traces)
6. Capacity planning recommendations documented
