# Hardening a Kubernetes workload — 9 critical findings to 0, scanner-verified

**The work:** took a Kubernetes deployment carrying the misconfigurations found in
most un-reviewed clusters — root, privileged, Docker-socket mounted, secrets in
plaintext — and hardened it to pass CIS-style checks, with the before/after
proven by two independent scanners.

---

## The problem

A `payments-api` deployment shipped with the defaults nobody circled back to
fix. None of this is contrived — it's what a scanner finds on a cluster that's
never had a security review:

- **Privileged, root container** with `allowPrivilegeEscalation: true` and a
  writable root filesystem — a container escape starts with full host access.
- **The Docker socket mounted via `hostPath`** — a textbook container-breakout
  path straight to the node.
- **Secrets as plaintext env vars** (`DB_PASSWORD`, a live Stripe key) — visible
  to anyone who can `describe` the pod.
- **`:latest` image tag** — you can't tell what's running or roll back cleanly.
- **No resource limits, no probes, no NetworkPolicy, no PodDisruptionBudget** —
  one pod can starve a node, and every pod in the cluster can reach it.
- **Internet-facing `LoadBalancer`** pointing straight at the pods.

Scanned as-is, the baseline was:

| Scanner | Baseline |
| --- | --- |
| kube-score | **9 CRITICAL**, 1 WARNING |
| checkov (CIS Kubernetes) | 68 passed, **22 failed** |

## What I changed

Every change maps to a specific finding:

- **Dropped root and privilege.** `runAsNonRoot`, UID/GID 65532,
  `privileged: false`, `allowPrivilegeEscalation: false`, **all Linux
  capabilities dropped**, `readOnlyRootFilesystem: true` with an explicit
  writable `emptyDir` only for `/tmp`, and seccomp `RuntimeDefault`.
- **Removed the Docker socket mount** entirely.
- **Secrets via `secretKeyRef`** from a Kubernetes Secret, not plaintext env.
- **Pinned the image by digest** (`@sha256:…`) — immutable and traceable.
- **Added resource requests/limits** (CPU, memory, ephemeral-storage), **liveness
  and readiness probes**, a **default-deny NetworkPolicy**, a
  **PodDisruptionBudget**, and **podAntiAffinity** to spread replicas.
- **Moved off `default` namespace**, disabled the service-account token mount,
  and switched the Service to `ClusterIP`.

## The result

| Scanner | Before | After |
| --- | --- | --- |
| kube-score CRITICAL | 9 | **0** |
| kube-score WARNING | 1 | **0** |
| checkov — failed checks | 22 | **1** |
| checkov — passed checks | 68 | **89** |
| Runs as root / privileged | yes | **no** |
| Docker socket exposed | yes | **no** |
| Secrets in plaintext env | yes | **no** (Secret refs) |

<sub>Numbers produced by [`scan.sh`](./scan.sh) using kube-score 1.19.0 and
checkov 3.3.22 — run it to reproduce them. The one remaining checkov finding
(`CKV_K8S_35`, "prefer secrets as files over env vars") is a deliberate,
documented choice: `secretKeyRef` env injection is a reasonable norm for a
12-factor app; mounting secrets as files is the stricter alternative and is a
one-line change if a client's policy requires it.</sub>

**Why it matters to the business:** the baseline is a cluster where a single
compromised pod reaches the host and every neighbour, and live credentials sit
in plain view. The hardened version removes the escape paths, contains the blast
radius with a default-deny network, and makes "what's running" unambiguous — the
difference between passing a security audit and failing one.

---

*Stack: Kubernetes, kube-score, checkov (CIS Kubernetes Benchmark), Pod Security
Standards. The full before/after manifests are in the repo so every number is
reproducible.*
