# payments-api — Kubernetes container-hardening case study

A real before/after: a Kubernetes workload carrying the misconfigurations found
in most un-reviewed clusters (root, privileged, Docker-socket mount, plaintext
secrets) → hardened to **0 critical findings**, proven by two scanners.

👉 **Read the write-up: [CASE-STUDY.md](./CASE-STUDY.md)**

## Result

| Scanner | Before | After |
| --- | --- | --- |
| kube-score CRITICAL | 9 | **0** |
| checkov failed checks | 22 | **1** † |

<sub>† a documented design tradeoff, not an oversight — see the case study.</sub>

## What's here

| Path | What it is |
| --- | --- |
| `before/` | ❌ the insecure manifests (the scan baseline) |
| `after/` | ✅ the hardened manifests: Deployment, Service, NetworkPolicy, PDB, Namespace |
| `scan.sh` | reproduces the before/after scanner numbers |

## Reproduce the numbers

```bash
# install scanners
pip install checkov
# kube-score: https://github.com/zegl/kube-score/releases

./scan.sh
```

## The hardening, at a glance

- non-root (UID 65532), no privilege escalation, no privileged mode
- all Linux capabilities dropped, read-only root filesystem, seccomp RuntimeDefault
- image pinned by digest; CPU/memory/ephemeral-storage requests + limits
- liveness + readiness probes; podAntiAffinity; PodDisruptionBudget
- default-deny NetworkPolicy; ClusterIP (not internet-facing)
- secrets via `secretKeyRef`; no Docker socket; dedicated namespace

---

Built by [Abhichandra](https://www.abhichandra.online) — SRE / Platform Engineer.
Available for scoped platform & container-security work.
