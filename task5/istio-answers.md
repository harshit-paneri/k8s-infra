# Task 5: Istio Service Mesh — Knowledge Assessment

## Question 1: Role of Istio in Kubernetes & Sidecar Proxy Model

### What is Istio?
Istio is a **service mesh** — an infrastructure layer that transparently manages service-to-service communication within a Kubernetes cluster. It provides **security**, **observability**, and **traffic management** without requiring changes to application code.

### The Sidecar Proxy Model (Envoy)

```
┌─────────────────────────────────────────┐
│              Kubernetes Pod              │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │  Application  │  │  Envoy Proxy    │  │
│  │  Container    │◄─▶  (Sidecar)      │  │
│  │  (your code)  │  │  Port 15001     │  │
│  └──────────────┘  └────────┬────────┘  │
│                              │iptables   │
└──────────────────────────────┼───────────┘
                               │
                               ▼
                    ┌──────────────────┐
                    │  istiod (Control  │
                    │  Plane)           │
                    │  - Pilot (config) │
                    │  - Citadel (certs)│
                    │  - Galley (valid) │
                    └──────────────────┘
```

**How it works:**
1. When a pod is created in an Istio-enabled namespace, the **Istio mutating webhook** automatically injects an **Envoy proxy sidecar** container alongside the application container.
2. **iptables rules** are configured (via init container) to intercept ALL inbound and outbound traffic from the application container and redirect it through the Envoy proxy.
3. The application communicates normally (e.g., `http://backend-service:8000`), completely unaware that traffic is routed through Envoy.
4. **istiod** (the control plane) pushes configuration to all Envoy proxies via xDS APIs, including routing rules, TLS certificates, and policies.

### Problems it Solves vs Application-Level Networking

| Problem | Without Istio (App-Level) | With Istio (Sidecar) |
|---------|--------------------------|---------------------|
| **mTLS** | Each app must implement TLS client/server certs | Automatic — Envoy handles cert rotation |
| **Retries/Timeouts** | Code in every service (e.g., retry library) | Declarative YAML — VirtualService config |
| **Circuit Breaking** | Library-dependent (Hystrix, resilience4j) | DestinationRule — language agnostic |
| **Load Balancing** | Basic DNS round-robin | Advanced: consistent hashing, locality-aware |
| **Observability** | Instrument every service with tracing SDKs | Automatic: metrics, logs, traces from proxy |
| **Access Control** | Each service checks auth tokens | AuthorizationPolicy — centralized L7 policies |
| **Canary Deployments** | Custom ingress routing per service | VirtualService weight-based traffic splitting |

**Key advantage**: Istio moves networking concerns from application code (L7) to infrastructure (sidecar proxy), making services **polyglot** — a Go service and Python service get the same security and observability without code changes.

---

## Question 2: PeerAuthentication vs AuthorizationPolicy

### PeerAuthentication
Controls **transport-level security (mTLS)** between services. It determines **HOW** services communicate — whether they must use mutual TLS.

```yaml
# Enforce strict mTLS across all services in namespace
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: strict-mtls
  namespace: dodo-app
spec:
  mtls:
    mode: STRICT    # Only accept mTLS connections
```

**Modes:**
| Mode | Behavior |
|------|----------|
| `STRICT` | Only accept mTLS; reject non-TLS traffic |
| `PERMISSIVE` | Accept both mTLS and plaintext (migration mode) |
| `DISABLE` | No mTLS |
| `UNSET` | Inherit from parent (mesh-wide → namespace → workload) |

### AuthorizationPolicy
Controls **application-level access control (L7 authorization)**. It determines **WHO** can access **WHAT** — which services can call which endpoints.

```yaml
# Only allow frontend to call backend's /api/* endpoints
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-access
  namespace: dodo-app
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/dodo-app/sa/frontend-sa"]
      to:
        - operation:
            methods: ["GET", "POST"]
            paths: ["/api/*"]
```

### Key Differences

| Aspect | PeerAuthentication | AuthorizationPolicy |
|--------|-------------------|-------------------|
| **Layer** | Transport (L4) — TLS handshake | Application (L7) — request routing |
| **What it controls** | *How* traffic is encrypted | *Who* can access *what* |
| **Scope** | Mesh → Namespace → Workload | Namespace → Workload |
| **Analogy** | "Lock the door" | "Check their ID badge" |
| **Example** | "All traffic to this namespace must be mTLS" | "Only frontend can POST to /api/transactions" |

### Enforcing Strict mTLS Across a Namespace

```yaml
# Step 1: Namespace-level strict mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: namespace-strict
  namespace: dodo-app
spec:
  mtls:
    mode: STRICT

---
# Step 2: Corresponding DestinationRule to ensure clients use mTLS
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: namespace-mtls
  namespace: dodo-app
spec:
  host: "*.dodo-app.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL    # Use Istio-managed certs
```

---

## Question 3: Traffic Management — Canary Deployment

### How Istio Traffic Management Works

Istio's traffic management builds on two key concepts:

1. **VirtualService** — Defines **routing rules**: how to route requests to a service (host matching, weight-based splitting, header-based routing, fault injection).
2. **DestinationRule** — Defines **destination policies**: how to group service instances into **subsets** (versions) and apply circuit breaking, load balancing, and TLS settings.

```
Request → VirtualService (routing rules) → DestinationRule (which subset) → Pod
```

### Canary Deployment Walk-Through

**Scenario**: Deploy backend v2 alongside v1, gradually shifting traffic.

```yaml
# Step 1: DestinationRule — Define subsets (versions)
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-dr
  namespace: dodo-app
spec:
  host: backend-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: DEFAULT
        maxRequestsPerConnection: 10
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
      trafficPolicy:
        connectionPool:
          http:
            maxRequestsPerConnection: 5   # More conservative for new version

---
# Step 2: VirtualService — Traffic splitting
# Phase 1: 90% v1, 10% v2 (canary)
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-vs
  namespace: dodo-app
spec:
  hosts:
    - backend-service
  http:
    - route:
        - destination:
            host: backend-service
            subset: v1
          weight: 90
        - destination:
            host: backend-service
            subset: v2
          weight: 10
      retries:
        attempts: 3
        perRetryTimeout: 2s
```

**Gradual rollout steps:**
```
Phase 1: 90/10 → Monitor metrics for 15 min
Phase 2: 70/30 → Monitor metrics for 15 min  
Phase 3: 50/50 → Monitor metrics for 30 min
Phase 4: 0/100 → Full rollout to v2
```

Update the VirtualService weights at each phase. If error rates spike, immediately set v2 weight to 0 (instant rollback).

---

## Question 4: Istio Ingress Gateway vs Kubernetes Ingress

### Kubernetes Ingress Controller (e.g., NGINX)
- Standard K8s resource
- L7 routing: host-based and path-based
- TLS termination
- Limited to HTTP routing rules
- Controller-specific annotations for advanced features

### Istio Ingress Gateway
- **Standalone Envoy proxy** at the edge of the mesh
- Full L4-L7 traffic management (VirtualService + DestinationRule)
- Integrated with Istio's mTLS, authorization policies, and observability
- Supports more protocols: HTTP, HTTPS, gRPC, TCP, TLS passthrough

```yaml
# Istio Gateway — entry point for external traffic
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: dodo-gateway
  namespace: dodo-app
spec:
  selector:
    istio: ingressgateway    # Use Istio's built-in gateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: dodo-tls-secret
      hosts:
        - "dodo.example.com"

---
# VirtualService bound to the Gateway
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: dodo-vs
  namespace: dodo-app
spec:
  hosts:
    - "dodo.example.com"
  gateways:
    - dodo-gateway
  http:
    - match:
        - uri:
            prefix: /api
      route:
        - destination:
            host: backend-service
            port:
              number: 8000
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: frontend-service
            port:
              number: 80
```

### Key Differences

| Aspect | K8s Ingress | Istio Ingress Gateway |
|--------|-------------|----------------------|
| **Protocol support** | HTTP/HTTPS | HTTP, HTTPS, gRPC, TCP, TLS |
| **Routing** | Host + path | + headers, query params, weights, fault injection |
| **mTLS** | Not built-in | Integrated (origin + mesh mTLS) |
| **Authorization** | Not built-in | AuthorizationPolicy at gateway |
| **Observability** | Separate setup | Built-in metrics, traces, access logs |
| **Canary** | Annotations (limited) | VirtualService weight-based |
| **Configuration** | Annotations (non-standard) | CRDs (standardized) |

---

## Question 5: Istio for Observability

### How Istio Improves Observability

Since **all traffic flows through Envoy sidecars**, Istio can automatically collect:

1. **Metrics** — Request count, latency, size, error codes (without app instrumentation)
2. **Distributed Traces** — Propagates trace headers, creates spans per hop
3. **Access Logs** — Structured logs for every request with source/destination info

### Integration with Observability Tools

```
┌───────────────────────────────────────────────────────────┐
│                 Envoy Sidecar Proxy                       │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐     │
│  │ Metrics   │  │ Traces   │  │ Access Logs        │     │
│  │ (stats)   │  │ (spans)  │  │ (structured JSON)  │     │
│  └─────┬─────┘  └─────┬────┘  └──────────┬────────┘     │
└────────┼──────────────┼───────────────────┼──────────────┘
         │              │                   │
         ▼              ▼                   ▼
  ┌──────────────┐ ┌──────────┐   ┌──────────────────┐
  │  Prometheus   │ │  Jaeger  │   │ Elasticsearch /  │
  │ (scrape       │ │ (collect │   │ Loki (ingest     │
  │  /stats/      │ │  spans)  │   │  access logs)    │
  │  prometheus)  │ │          │   │                  │
  └──────┬────────┘ └────┬─────┘   └──────────────────┘
         │               │
         ▼               ▼
  ┌──────────────────────────────┐
  │          Grafana              │
  │  ├── Prometheus dashboards   │
  │  ├── Jaeger trace viewer     │
  │  └── Loki log explorer       │
  └──────────────────────────────┘
```

### Prometheus Integration
Istio exposes standard Prometheus metrics from every proxy:

```
# Key metrics auto-generated by Envoy
istio_requests_total{
  source_workload, destination_workload,
  response_code, request_protocol
}
istio_request_duration_milliseconds{...}
istio_request_bytes{...}
istio_response_bytes{...}
```

Prometheus scrapes the `/stats/prometheus` endpoint on each sidecar automatically (Istio configures ServiceMonitor CRDs).

### Grafana Integration
Istio includes **pre-built Grafana dashboards**:
- **Mesh Dashboard** — Global request volume, success rate, latency
- **Service Dashboard** — Per-service request/error/duration metrics
- **Workload Dashboard** — Per-pod resource utilization
- **Performance Dashboard** — Envoy proxy resource usage

These dashboards use the `istio_*` Prometheus metrics automatically.

### Jaeger / Distributed Tracing Integration
- Envoy proxies **generate spans** for every request entering/leaving a sidecar
- Applications must **propagate trace headers** (not generate them) — the following headers are forwarded:
  - `x-request-id`
  - `x-b3-traceid`, `x-b3-spanid`, `x-b3-parentspanid`
  - `x-b3-sampled`, `x-b3-flags`
  - `traceparent` (W3C format)
- Istio sends spans to Jaeger via the **OpenTelemetry Collector** or directly to Jaeger's collector endpoint
- Configure in Istio's mesh config:

```yaml
# istio mesh config for tracing
meshConfig:
  enableTracing: true
  defaultConfig:
    tracing:
      sampling: 100.0   # 100% sampling (reduce in production)
      zipkin:
        address: jaeger-collector.monitoring:9411
```

### The Observability Advantage
Without Istio, each service must:
1. Import Prometheus client library → export metrics
2. Import OpenTelemetry SDK → create/propagate spans
3. Configure structured logging → ship to aggregator

With Istio, all of this happens **automatically at the proxy layer**. The application only needs to propagate trace headers (a few lines of middleware). This is especially valuable for **polyglot architectures** where services are written in different languages.
