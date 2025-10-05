# =============================================================================
# Middleware Submodule Outputs
# =============================================================================

output "headers" {
  description = "Created headers middleware names"
  value       = [for k, v in kubectl_manifest.headers : k]
}

output "rate_limit" {
  description = "Created rate limit middleware names"
  value       = [for k, v in kubectl_manifest.rate_limit : k]
}

output "retry" {
  description = "Created retry middleware names"
  value       = [for k, v in kubectl_manifest.retry : k]
}

output "circuit_breaker" {
  description = "Created circuit breaker middleware names"
  value       = [for k, v in kubectl_manifest.circuit_breaker : k]
}

output "basic_auth" {
  description = "Created basic auth middleware names"
  value       = [for k, v in kubectl_manifest.basic_auth : k]
}

output "forward_auth" {
  description = "Created forward auth middleware names"
  value       = [for k, v in kubectl_manifest.forward_auth : k]
}

output "ip_whitelist" {
  description = "Created IP whitelist middleware names"
  value       = [for k, v in kubectl_manifest.ip_whitelist : k]
}

output "redirect" {
  description = "Created redirect middleware names"
  value       = [for k, v in kubectl_manifest.redirect : k]
}

output "strip_prefix" {
  description = "Created strip prefix middleware names"
  value       = [for k, v in kubectl_manifest.strip_prefix : k]
}

output "compress" {
  description = "Created compress middleware names"
  value       = [for k, v in kubectl_manifest.compress : k]
}

output "chain" {
  description = "Created chain middleware names"
  value       = [for k, v in kubectl_manifest.chain : k]
}

output "all_middlewares" {
  description = "All created middleware names"
  value = concat(
    [for k, v in kubectl_manifest.headers : k],
    [for k, v in kubectl_manifest.rate_limit : k],
    [for k, v in kubectl_manifest.retry : k],
    [for k, v in kubectl_manifest.circuit_breaker : k],
    [for k, v in kubectl_manifest.basic_auth : k],
    [for k, v in kubectl_manifest.forward_auth : k],
    [for k, v in kubectl_manifest.ip_whitelist : k],
    [for k, v in kubectl_manifest.redirect : k],
    [for k, v in kubectl_manifest.strip_prefix : k],
    [for k, v in kubectl_manifest.compress : k],
    [for k, v in kubectl_manifest.chain : k]
  )
}
