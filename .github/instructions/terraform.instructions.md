---
applyTo: "**/*.tf"
---

Terraform instructions — service-nebula
=====================================

Purpose
-------
These instructions apply to any Copilot coding agent or other AI assistant making changes to Terraform (`*.tf`) files in this repository. They are Terraform-specific and supplement the repository-level `.github/copilot-instructions.md` guidance.

High-level constraints (follow exactly)
-------------------------------------
- Follow HashiCorp's opinionated best-practices and anti-pattern guidance closely: https://www.hashicorp.com/en/resources/opinionated-terraform-best-practices-and-anti-patterns
- Keep all changes minimal and standard. Do not add optional providers, flags, or parameters unless the user explicitly requests them.
- Do not hard-code values. Place versions, provider pins, and environment-specific variables at the Terraform root (or Terragrunt root). Pass values into modules via variables, ideally using object/map types.
- Use object-based variables for module inputs where practical instead of many primitive variables.
- Pin provider versions when you introduce or modify providers. Document why a pin was added.
- Avoid plan-time provider API calls that require secrets (for example, Vault provider actions) unless the user explicitly provides credentials and approves. If such calls are necessary, ask for the exact credential provisioning method.
 - When specifying providers prefer the most recent stable provider version available. If you must pin for stability, pin to the most recent known-good version and document why. Audit and recommend updates when newer stable versions are available.
 - Avoid plan-time provider API calls that require secrets (for example, Vault provider actions) unless the user explicitly provides credentials and approves. If such calls are necessary, ask for the exact credential provisioning method.

Ask-ahead checklist (must be answered before making changes)
----------------------------------------------------------
Before editing any `*.tf` file, ask the user these exact questions and wait for answers:

1) target_environment: "Which environment should this change target? (e.g., kind-mgmt, CI)"
2) files_in_scope: "Which TF files/modules should I edit? Provide globs or explicit paths."
3) plan_or_apply: "Do you want a PLAN (default) or an APPLY? If APPLY, provide explicit approval and credentials method."
4) credentials: "Will you provide credentials (e.g., VAULT_TOKEN, kubeconfig) for any provider calls? If yes, how will you supply them?"
5) rollback_plan: "What rollback criteria or acceptable failure modes should I assume?"

Terraform-specific response schema (agents must use)
--------------------------------------------------
When proposing changes, respond in the JSON-friendly schema below. This must be the first message after the ask-checklist is complete.

{
  "summary": "<one-line summary>",
  "files_read": ["path/to/file.tf"],
  "files_changed": ["path/to/file.tf"],
  "plan_summary": "<short excerpt of terragrunt plan/terraform plan>",
  "commands_to_verify": ["terragrunt fmt", "terragrunt validate", "terragrunt plan -out=tfplan"],
  "risks": ["provider calls that require VAULT_TOKEN"],
  "audit_checks": [ {"name":"fmt","result":"PASS"}, {"name":"no-secrets","result":"PASS"} ]
}

Self-audit checks (run automatically on your proposed changes)
-----------------------------------------------------------
For every proposed TF change, perform and include the results of these checks in `audit_checks` above:

- fmt: run `terraform fmt` (or `terragrunt fmt`) on changed files; fail if formatting changes are required.
- validate: run `terraform validate` (or `terragrunt validate`) in the root where the change is proposed; include errors.
- plan: run `terragrunt plan -out=tfplan` (or `terraform plan`) and include a concise plan summary; ensure the plan matches the minimal change intent.
- no_secrets: scan diffs for likely secrets (PEM headers, `root_token`, `unseal_key`, long base64 blobs). Fail if found.
- provider_pinned: if adding or changing providers, ensure a provider version is pinned in the provider configuration and document the reason.
- variables_at_root: ensure newly-introduced configuration uses variables passed from the root; if a value is required at module level, prefer object/map variable inputs.

- provider_latest: ensure provider versions referenced are the most recent stable releases when possible; if a pin is present, include the reason and a suggested update path.
- null_resource_usage: flag any use of `null_resource` and require the agent to provide a justification and an alternative Terraform-native solution (for example: `kubernetes_job`, `helm_release`, `local_file` + `kubernetes_manifest`, or a module). Do not use `null_resource` to wrap long-running shell scripts without explicit user approval.

 - null_resource_usage: flag any use of `null_resource` and require the agent to provide a justification and an alternative Terraform-native solution (for example: `helm_release`, provider-specific resources, `local_file` + external tooling, or a module). Do not use `null_resource` to wrap long-running shell scripts without explicit user approval.

Implementation & style rules
---------------------------
- Prefer adding variables to `variables.tf` with sensible defaults only when safe — otherwise require the user to supply values via root-level var files or Terragrunt.
- Use `locals` sparingly for computed values; do not bake environment-specific values into modules.
- Avoid adding lifecycle rules (prevent_destroy, ignore_changes) unless the user explicitly requests them and documents justification.
- When creating or updating modules, add or update `README.md` in the module directory with the module's inputs/outputs summary.

Additional checks and behaviors
------------------------------
- If any `null_resource` is present in the proposed changes, the agent must:
  1) Explain why no native Terraform resource could be used.
  2) Provide a Terraform-native alternative (helm_release, provider-specific resources, or module) and a migration plan.
  3) If the user approves `null_resource`, include a short runbook describing how to re-run or recover if the script fails.


Examples of unacceptable changes (do not do these)
-------------------------------------------------
- Hard-coding secrets or tokens into TF files.
- Adding a provider without a version pin.
- Adding complex optional parameters to modules without user request.

If you cannot comply
--------------------
If any of the checklist items are unanswered or you cannot run the self-audit (tooling missing), ask the user clearly which item to resolve and do not make changes.

Prompt templates (use these to request edits)
-------------------------------------------
- Minimal change request:

  "Task: <short description>. Files: <files>. Constraints: minimal, no-secrets, variables at root. Output: JSON response_schema."

- Debug infra failure:

  "Task: Investigate <terraform/terragrunt error>. Provide plan, root cause, and two remediation options (minimal & robust). Run validate and plan and include outputs in plan_summary."

References
----------
- HashiCorp opinionated best-practices: https://www.hashicorp.com/en/resources/opinionated-terraform-best-practices-and-anti-patterns

---
These path-specific instructions will be applied for any Copilot request that edits `*.tf` files in the repository. Follow them strictly; ask before acting on anything outside code changes.
