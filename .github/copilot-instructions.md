
AI-first repository instructions for service-nebula
=================================================

Purpose
-------
This file is the authoritative AI instruction for this repository. It is optimized for automated agents to follow strictly.

metadata:
	agent_version: 1.0
	canonical_location: ".github/copilot-instructions.md"

rules:
	- id: secret_handling
		description: "Never output or commit secrets (unseal keys, root tokens, private keys). If secrets are required, ask the user how to provide them securely and wait."

	- id: plan_before_apply
		description: "Always produce a plan before making infrastructure changes. Provide a `terragrunt plan -out=tfplan` or `terraform plan` summary. Do not run `apply` unless the user explicitly approves."

	- id: non_code_changes_must_be_requested
		description: "If a requested change requires anything outside code modifications (running commands, supplying tokens, network access, manual approvals), ask the user explicitly and wait."

	- id: minimal_scope
		description: "Prefer the smallest, non-breaking change that satisfies the request. When applicable present both a minimal and a robust option."
# Repository AI instructions — service-nebula

Short overview (human-friendly)
--------------------------------
- This repository bootstraps a local Kubernetes development environment (kind) inside a devcontainer and deploys infrastructure using Terragrunt/Terraform and Helm.
- Key modules: `modules/kind-cluster`, `modules/vault` (with automated init/unseal), `modules/traefik`, `modules/cilium`, and `modules/cert-manager`.
- Bootstrapping (devcontainer) flow is driven from `.devcontainer/build/postCreateCommand.sh`, which runs `terragrunt init` and an `apply.sh` wrapper that performs a staged bootstrap (cluster -> charts -> post-init tasks).

Quick verification commands (how to validate locally)
----------------------------------------------------
1. Initialize and plan in the terraform root:

```bash
cd .devcontainer/tf
terragrunt init -upgrade
terragrunt plan -out=tfplan
```

2. Inspect Vault init automation (do NOT run apply without approval):

```bash
less .devcontainer/tf/modules/vault/modules/init/main.tf
kubectl get pods -n vault
```

3. Check providers file and pinned versions:

```bash
less .devcontainer/tf/providers_generated.tf
```

Locations to check first
-----------------------
- `.devcontainer/` — devcontainer settings and bootstrap scripts (postCreateCommand.sh, build scripts).
- `.devcontainer/tf/` — Terraform root used by the devcontainer bootstrap.
- `.devcontainer/tf/modules/` — modules for vault, traefik, cilium, kind-cluster, etc.
- `tf/` (if present) — other terraform roots for different environments.

AI-first authoritative instructions (machine-friendly)
----------------------------------------------------
The section below is written for automated agents. Follow it exactly.

```yaml
agent_version: 1.0
canonical_location: ".github/copilot-instructions.md"

rules:
  - id: secret_handling
    description: "Never output or commit secrets (unseal keys, root tokens, private keys). If secrets are required, ask the user how to provide them securely and wait."

  - id: plan_before_apply
    description: "Always produce a plan before making infrastructure changes. Provide a `terragrunt plan -out=tfplan` or `terraform plan` summary. Do not run `apply` unless the user explicitly approves."

  - id: non_code_changes_must_be_requested
    description: "If a requested change requires anything outside code modifications (running commands, supplying tokens, network access, manual approvals), ask the user explicitly and wait."

  - id: minimal_scope
    description: "Prefer the smallest, non-breaking change that satisfies the request. When applicable present both a minimal and a robust option."

ask_checklist:
  - key: target_environment
    prompt: "Which environment should changes target? (e.g., kind-mgmt, CI)"

  - key: files_in_scope
    prompt: "Which files/modules should be edited? Provide globs or explicit lists."

  - key: action_type
    prompt: "Do you want a PLAN (default) or an APPLY? If APPLY, provide explicit approval and credential provisioning method."

  - key: credentials
    prompt: "Will you provide credentials/tokens (e.g., VAULT_TOKEN, kubeconfig)? If yes, how will they be supplied?"

  - key: run_commands
    prompt: "Should the assistant execute commands in your environment? If yes, describe execution environment and confirm."

response_schema:
  type: object
  properties:
    summary: { type: string }
    files_read: { type: array, items: { type: string } }
    files_changed: { type: array, items: { type: string } }
    plan_summary: { type: string }
    commands_to_verify: { type: array, items: { type: string } }
    risks: { type: array, items: { type: string } }
    audit_checks: { type: array, items: { type: object } }

workflow:
  - step: "1. Parse user's request and identify concrete files/modules affected."
  - step: "2. Run the `ask_checklist`. If any item is unanswered, ask exactly that question and pause."
  - step: "3. Generate a minimal plan and an optional robust plan; include plan-summary."
  - step: "4. Perform self-audit checks (no secrets, plan present, minimal changes) and include results."
  - step: "5. Output a JSON response conforming to `response_schema`. Wait for explicit user approval before editing or applying."

self_audit_checks:
  - id: no_secrets_committed
    check: "Scan diffs for PEM blocks, `root_token`, `unseal_key`, and long base64 blobs. Fail if likely secret found."

  - id: plan_produced
    check: "Confirm a terraform/terragrunt plan summary exists for infra changes."

  - id: minimal_change
    check: "Verify changed lines are minimal for the objective; else explain why more is needed."

prompt_templates:
  minimal_change: |
    {"task":"<short description>","files":["<file1>","<file2>"],"constraints":["no-secrets","minimal"],"output":"json"}

  debug_infra: |
    {"task":"Investigate <error>","context":"<kubectl/helm/terraform output>","output":"json with plan and options"}

operator_notes:
  - "Agents must not execute remote or local commands without explicit approval from the user."
  - "If credentials are required for provider operations, list them and request the user's provisioning method."

```

If you'd like, I can also add a path-specific instruction file under `.github/instructions/` for `*.tf` files that enforces additional Terraform-specific checks and templates. Ask and I'll scaffold it.
