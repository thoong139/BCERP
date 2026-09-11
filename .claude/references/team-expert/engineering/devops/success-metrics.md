# Success Metrics: DevOps Engineer

> Domain: CI/CD, Infrastructure, Deployment
> Agent: `devops`

## DORA Metrics (Industry Standard)

| Chỉ số | Mục tiêu | Đo lường |
|--------|----------|----------|
| Deployment frequency | Nhiều lần deploy mỗi ngày (on-demand) | GitHub Actions / GitLab CI logs |
| Mean Time to Recovery (MTTR) | Dưới 30 phút | Incident tracking system |
| Infrastructure uptime | > 99.9% | Prometheus / CloudWatch metrics |
| Security scan pass rate | 100% cho critical issues | Trivy / Semgrep / CodeQL reports |
| Chi phí tối ưu | Giảm 20% year-over-year thông qua right-sizing | Cloud billing reports |

## Quality Gates

- [ ] Zero-downtime deployment for production environments
- [ ] Automated rollback capability when health checks fail
- [ ] Secrets managed via vault/secrets manager (no hardcoding)
- [ ] Resource limits defined for all containers
- [ ] Security scanning mandatory in pipeline (SAST, dependency scan, container scan)

## Definition of Done

1. Pipeline executes successfully end-to-end
2. All security gates pass (no critical vulnerabilities)
3. Rollback tested and documented
4. Monitoring/observability configured for new services
5. Documentation updated (runbooks, architecture diagrams)
