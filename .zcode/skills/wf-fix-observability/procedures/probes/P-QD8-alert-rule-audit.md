# P-QD8-alert-rule-audit — Alert Rule Coverage Audit

> **Type:** static (grep+jq) | **Profile:** deep/exhaustive | **Severity default:** MEDIUM | **Cache:** allowed

Phat hien thieu sot trong alert rules — production loi nhung khong ai duoc thong bao.

---

## Detection Logic

### Step 1 — Look for alert rule definitions

```bash
# Common alert config files
ALERT_FILES=$(find . -type f \( \
  -name "alerts.yml" -o -name "alerts.yaml" \
  -o -name "alert-rules.yml" -o -name "*-alerts.yml" \
  -o -path "*/prometheus/*.yml" -o -path "*/grafana/*.yml" \
  -o -name "alertmanager.yml" -o -name "alarm.tf" \
  \) 2>/dev/null | head -20)

if [ -z "$ALERT_FILES" ]; then
  emit_signal_jsonl \
    "P-QD8-alert-rule-audit" \
    "medium" \
    "Khong tim thay alert rule config files" \
    "Project khong co alert rules (Prometheus/Grafana/CloudWatch alarm). Production incident → khong ai duoc thong bao → MTTD (mean time to detect) cao." \
    "(no alert config)" 0 "" "[]"
  exit 0
fi
```

### Step 2 — Check coverage of golden signals

Golden signals (Google SRE): latency, traffic, errors, saturation. Alert rules nen cover at least latency + errors.

```bash
HAS_LATENCY_ALERT=$(grep -ciE "latency|p9[0-9]|response_time|duration_seconds" $ALERT_FILES 2>/dev/null)
HAS_ERROR_ALERT=$(grep -ciE "error_rate|errors_total|5xx|http.*5\\\\d" $ALERT_FILES 2>/dev/null)
HAS_SATURATION_ALERT=$(grep -ciE "memory|cpu_usage|disk_usage|saturation|connection.*pool" $ALERT_FILES 2>/dev/null)

if [ "$HAS_LATENCY_ALERT" = "0" ]; then
  emit_signal_jsonl \
    "P-QD8-alert-rule-audit" \
    "medium" \
    "Alert rules thieu latency monitoring" \
    "Khong tim thay alert rule cho latency/response_time. Recommend: alert khi p95 latency > SLO target (vd: 1s)." \
    "$(echo $ALERT_FILES | head -1)" 0 "" "[]"
fi

if [ "$HAS_ERROR_ALERT" = "0" ]; then
  emit_signal_jsonl \
    "P-QD8-alert-rule-audit" \
    "high" \
    "Alert rules thieu error rate monitoring" \
    "Khong tim thay alert rule cho error_rate/5xx. Production loi → khong duoc thong bao → user phat hien truoc team. Recommend: alert khi error_rate > 1% trong 5 phut." \
    "$(echo $ALERT_FILES | head -1)" 0 "" "[]"
fi

if [ "$HAS_SATURATION_ALERT" = "0" ]; then
  emit_signal_jsonl \
    "P-QD8-alert-rule-audit" \
    "medium" \
    "Alert rules thieu saturation (CPU/memory/pool) monitoring" \
    "Khong tim thay alert cho CPU/memory/connection pool saturation. Risk: server slow → cascade fail truoc khi team biet." \
    "$(echo $ALERT_FILES | head -1)" 0 "" "[]"
fi
```

### Step 3 — Check alert routing / on-call config

```bash
HAS_PAGER=$(grep -ciE "pagerduty|opsgenie|slack|discord|sns:" $ALERT_FILES 2>/dev/null)

if [ "$HAS_PAGER" = "0" ]; then
  emit_signal_jsonl \
    "P-QD8-alert-rule-audit" \
    "medium" \
    "Alert routing thieu — no PagerDuty/Slack/Opsgenie integration" \
    "Alert rules co the trigger nhung khong route den on-call channel. Effective alert can include integration tao ra ticket / page on-call." \
    "$(echo $ALERT_FILES | head -1)" 0 "" "[]"
fi
```

## Negative Patterns (KHONG emit)

1. Project la library/SDK (no deployment, alert N/A).
2. Project chua deploy production (early stage).
3. Alert rules dat o platform khac (DataDog SaaS, externally managed).
