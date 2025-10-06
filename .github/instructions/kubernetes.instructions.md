```instructions
---
applyTo:
  - "charts/**/Chart.yaml"
  - "charts/**/values*.yaml"
  - "**/tf/modules/**/charts/**/Chart.yaml"
  - "**/tf/modules/**/charts/**/values*.yaml"
  - "deploy/**/*.yaml"
  - "deploy/**/*.yml"
  - "manifests/**/*.yaml"
  - "manifests/**/*.yml"
  - "**/k8s/**"
---

Kubernetes & Helm instructions — service-nebula
=============================================

Purpose
-------
These instructions apply to Copilot coding agents or other AI assistants making changes to Kubernetes manifests, Helm charts (`Chart.yaml`, `values.yaml`) or related YAML files in this repository. They supplement the repository-level guidance in `.github/copilot-instructions.md`.

High-level constraints (follow exactly)
-------------------------------------
- Prefer declarative Kubernetes APIs and controllers over imperative scripts. Use Helm charts or Kubernetes manifests instead of `local-exec` in Terraform when possible.
- Keep Helm values minimal and explicit. Do not add secrets in chart values — use sealed secrets, ExternalSecrets, or reference Kubernetes Secrets managed outside the repo.
- Always include readiness/liveness probes for workloads and resource requests/limits for production-like charts.
- Avoid cluster-scoped changes in application charts unless explicitly requested and authorized.

Ask-ahead checklist (must be answered before making changes)
----------------------------------------------------------
Before editing any Kubernetes-related files, ask the user these exact questions and wait for answers:

1) target_cluster: "Which cluster or environment should this change target? (e.g., kind-mgmt, CI, prod)"
2) files_in_scope: "Which files or charts should I edit? Provide globs or paths."
3) secrets_strategy: "How should secrets be provided? (sealed-secrets, ExternalSecrets, Vault integration)"
4) rollout_policy: "What rollout strategy and acceptable downtime are allowed?"
5) testing_plan: "How should I validate chart changes? (helm template + kubeval, dry-run, e2e smoke tests)"

Kubernetes response schema (agents must use)
-----------------------------------------
When proposing changes, respond using this JSON-friendly schema as the first message after the ask-checklist is complete.

{
  "summary": "<one-line summary>",
  "files_read": ["path/to/file.yaml"],
  "files_changed": ["path/to/file.yaml"],
  "validation_summary": "<helm template/kubeval outcomes>",
  "commands_to_verify": ["helm lint", "helm template", "kubeval"],
  "risks": ["requires cluster-admin for CRD installation"],
  "audit_checks": [ {"name":"lint","result":"PASS"}, {"name":"probes","result":"PASS"} ]
}

Self-audit checks (run automatically on proposed changes)
------------------------------------------------------

- lint: run `helm lint` for charts changed.
- template: run `helm template` and validate rendered manifests with `kubeval` or a similar tool.
- probes: ensure Deployments/StatefulSets include readiness and liveness probes.
- resources: ensure CPU/memory requests and limits are set for pods in charts intended for runtime environments.
- no_secrets: scan diffs for secrets-like material (PEM blocks, base64 strings > 120 chars). Fail if found.
- chart_versioning: if changing Chart.yaml version or appVersion, follow semantic versioning and include a changelog entry in chart README.

Implementation & style rules
---------------------------
- Prefer `helm_release` or `helmfile` style management when used via Terraform; keep Helm values files small and inject environment-specific overrides at deployment time.
- Use `kustomize` or templating only when it simplifies overlays for multiple environments; prefer separate values files for `kind-mgmt`, `ci`, and `prod`.
- For CRDs, upstream-provide only: vendor CRDs only when necessary and include a clear upgrade path.

Additional checks and behaviors
------------------------------
- If a proposed change requires creating a Job or long-running pod to bootstrap state (for example: database migrations or vault initialization), prefer implementing an in-cluster Kubernetes Job with clear idempotency and a small TTL rather than host-side scripts.
- If an in-cluster Job is not possible, include a runbook describing how to run the script safely outside the cluster and how to re-run it.

Examples of unacceptable changes
--------------------------------
- Committing plaintext secrets into `values.yaml` or manifests.
- Adding cluster-admin RBAC changes without approval.

If you cannot comply
--------------------
If any checklist item is unanswered or the agent cannot run the self-audit, ask the user for that item and do not make changes.

``` 
