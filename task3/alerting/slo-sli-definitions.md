# ═══════════════════════════════════════════════════════════════════
# SLI/SLO Definitions for Dodo Payments
# ═══════════════════════════════════════════════════════════════════

## SLI/SLO Framework

### What are SLIs and SLOs?
- **SLI (Service Level Indicator)**: A quantitative measure of service quality (e.g., latency, error rate)
- **SLO (Service Level Objective)**: A target value for an SLI (e.g., "99.9% of requests < 200ms")
- **Error Budget**: The allowed amount of unreliability (100% - SLO)

---

## Backend API Service

### SLI: Availability
- **Definition**: Proportion of successful HTTP responses (non-5xx)
- **Measurement**: `sum(rate(http_requests_total{status!~"5.."}[30d])) / sum(rate(http_requests_total[30d]))`
- **SLO**: 99.95%
- **Error Budget**: 0.05% ≈ 21.6 minutes/month of downtime
- **Alert Threshold**: < 99.5% in any 1-hour window → PAGE

### SLI: Latency
- **Definition**: P99 response time for all API requests
- **Measurement**: `histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))`
- **SLO**: P99 < 200ms for 99.9% of requests
- **Error Budget**: 0.1% of requests can exceed 200ms
- **Alert Threshold**: P99 > 500ms for 5 minutes → WARNING; P99 > 1s for 2 min → CRITICAL

### SLI: Throughput
- **Definition**: Requests per second handled successfully
- **Measurement**: `sum(rate(http_requests_total{status!~"5.."}[5m]))`
- **SLO**: > 100 req/s sustained capacity
- **Alert Threshold**: 0 req/s for 5 minutes → CRITICAL

---

## Frontend Service

### SLI: Availability
- **Definition**: Proportion of successful health check responses
- **Measurement**: Probe success rate from Prometheus blackbox exporter
- **SLO**: 99.9%
- **Error Budget**: 0.1% ≈ 43.2 minutes/month
- **Alert Threshold**: < 99% in 30 min → CRITICAL

---

## PostgreSQL Database

### SLI: Query Latency
- **Definition**: P95 query execution time
- **Measurement**: `pg_stat_statements_mean_exec_time` (via postgres_exporter)
- **SLO**: P95 < 50ms
- **Alert Threshold**: P95 > 100ms for 5 minutes → WARNING

### SLI: Connection Availability
- **Definition**: Database accepting connections
- **Measurement**: `pg_up` metric
- **SLO**: 99.99%
- **Alert Threshold**: `pg_up == 0` for 1 minute → CRITICAL

---

## Error Budget Policy

| Error Budget Consumed | Action |
|----------------------|--------|
| < 50% | Normal development velocity |
| 50 - 75% | Increased monitoring, reduce risky changes |
| 75 - 100% | Freeze feature releases, focus on reliability |
| > 100% | All hands on reliability, incident review required |
