# Vault PKI + cert-manager Integration - Implementation Summary

## Overview

This implementation configures **cert-manager** to use **Vault's PKI secrets engine** as a certificate authority, following the official HashiCorp and cert-manager documentation.

### Documentation References
- HashiCorp: https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
- cert-manager: https://cert-manager.io/docs/configuration/vault/

## Architecture

### Correct Approach: Vault PKI Issuer
```
cert-manager → Vault Issuer → Vault PKI API → Vault PKI Secrets Engine → Issues Certificate
```

**Key Points:**
- cert-manager connects to Vault's PKI API (NOT using CA certificate/key directly)
- Vault PKI engine dynamically issues certificates via API calls
- Kubernetes auth allows cert-manager ServiceAccount to authenticate to Vault
- No CA private keys are exposed to cert-manager
- Certificates are issued and renewed automatically

### Why Not CA Issuer?
The previous approach (using CA Issuer with Vault's CA cert/key) was incorrect:
- ❌ Exposes CA private key to cert-manager
- ❌ Static CA cert management
- ❌ No integration with Vault's audit/policy system
- ❌ Not the documented pattern

## Implementation Components

### 1. Vault Module: PKI Configuration
**File:** `modules/vault/vault-pki-for-cert-manager.tf`

**Resources Created:**
- `vault_auth_backend.kubernetes` - Enables Kubernetes authentication
- `vault_kubernetes_auth_backend_config.kubernetes` - Configures K8s auth to use cluster's API
- `vault_mount.pki` - Mounts PKI secrets engine at `/pki`
- `vault_pki_secret_backend_config_urls.pki` - Configures PKI issuing/CRL endpoints
- `vault_pki_secret_backend_intermediate_set_signed.pki` - Imports intermediate CA into PKI
- `vault_pki_secret_backend_role.cert_manager` - Creates PKI role for cert-manager
- `vault_policy.cert_manager` - Policy allowing cert-manager to use PKI
- `vault_kubernetes_auth_backend_role.cert_manager` - K8s auth role binding SA to policy

**Configuration:**
```terraform
cert_manager_integration = {
  enabled                  = true
  pki_mount_path           = "pki"
  pki_role_name            = "cert-manager"
  pki_max_ttl_seconds      = 31536000  # 1 year
  cert_max_ttl_seconds     = 259200    # 72 hours
  cert_default_ttl_seconds = 86400     # 24 hours
  policy_name              = "cert-manager"
  auth_role_name           = "cert-manager"
  service_account_names    = ["vault-issuer"]
  service_account_namespaces = ["vault"]
  token_ttl_seconds        = 1200      # 20 minutes
  token_max_ttl_seconds    = 3600      # 1 hour
  token_audiences          = ["vault://vault/vault-issuer"]
  allowed_domains          = ["svc.cluster.local", "vault.svc.cluster.local"]
  allow_glob_domains       = false
  allow_any_name           = false
}
```

### 2. cert-manager Module: Vault Issuer
**Files:**
- `modules/cert-manager/vault-issuer.tf` - Creates Issuer and RBAC
- `modules/cert-manager/vault-injector-certificate.tf` - Creates Certificate for injector

**Resources Created:**
- `kubernetes_service_account.vault_issuer` - ServiceAccount for Vault auth
- `kubernetes_role.vault_issuer` - Role allowing token creation
- `kubernetes_role_binding.vault_issuer` - Binds role to cert-manager SA
- `kubectl_manifest.vault_issuer` - Vault Issuer resource
- `kubectl_manifest.vault_injector_certificate` - Certificate for Vault injector webhook

**Vault Issuer Spec:**
```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-issuer
  namespace: vault
spec:
  vault:
    server: http://vault.vault.svc.cluster.local:8200
    path: pki/sign/cert-manager
    caBundle: <base64-encoded-root-ca>
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
        serviceAccountRef:
          name: vault-issuer
          audiences: ["vault://vault/vault-issuer"]
```

### 3. Main Configuration
**File:** `main.tf`

**Deployment Order:**
1. **Vault** deployed first with PKI integration enabled
2. **cert-manager Vault Issuer** deployed second (separate module call)
   - Creates ServiceAccount and RBAC
   - Creates Vault Issuer
   - Creates Certificate for Vault injector

**Why Two cert-manager Module Calls?**
- First call: Deploys cert-manager components (controller, webhook, cainjector)
- Second call: Configures Vault Issuer and creates certificates (requires Vault to be running)

## Prerequisites for Deployment

### Vault Must Be:
1. ✅ Deployed with TLS enabled
2. ✅ Initialized and unsealed
3. ✅ Root token available (for Terraform vault provider)

### Environment Variables Required:
```bash
export VAULT_ADDR="https://vault.vault.svc.cluster.local:8200"
export VAULT_TOKEN="<root-token>"
export VAULT_SKIP_VERIFY=true  # Only for dev/self-signed certs
```

## Deployment Workflow

### Step 1: Deploy Vault
```bash
cd /workspaces/service-nebula/.devcontainer/tf
tofu apply -target=module.mgmt_vault
```

### Step 2: Initialize and Unseal Vault
```bash
# Wait for Vault pods to be running
kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=300s

# Get root token from output or init process
export VAULT_TOKEN="<root-token-from-init>"
export VAULT_ADDR="https://vault.vault.svc.cluster.local:8200"
```

### Step 3: Deploy cert-manager with Vault Issuer
```bash
# Now that Vault is running, deploy cert-manager Vault integration
tofu apply -target=module.mgmt_cert_manager_vault_issuer
```

### Step 4: Verify
```bash
# Check Issuer status
kubectl get issuer vault-issuer -n vault
kubectl describe issuer vault-issuer -n vault

# Check Certificate status
kubectl get certificate vault-injector-tls -n vault
kubectl describe certificate vault-injector-tls -n vault

# Check the secret was created
kubectl get secret injector-tls -n vault
```

## How It Works

### Certificate Issuance Flow:

1. **Request**: User creates a Certificate resource referencing the Vault Issuer
2. **Auth**: cert-manager creates a token for the `vault-issuer` ServiceAccount
3. **Login**: cert-manager authenticates to Vault using Kubernetes auth
4. **Sign**: cert-manager calls Vault PKI API: `POST /v1/pki/sign/cert-manager`
5. **Store**: Vault returns signed certificate, cert-manager stores in Secret
6. **Renew**: cert-manager automatically renews before expiry

### Security Model:

- **No CA Private Keys in K8s**: Only Vault has access to CA keys
- **Policy-Based Access**: Vault policy controls what cert-manager can do
- **Audit Trail**: All certificate operations logged in Vault audit logs
- **Time-Limited Tokens**: cert-manager tokens expire after 20 minutes
- **Audience Validation**: Tokens are scoped to specific Issuer

## Configuration Variables

### Vault Module: `cert_manager_integration`
- `enabled`: Enable/disable PKI integration (bool)
- `pki_mount_path`: Where to mount PKI engine (string)
- `pki_role_name`: Name of PKI role for cert-manager (string)
- `pki_max_ttl_seconds`: Max TTL for PKI mount (number)
- `cert_max_ttl_seconds`: Max TTL for issued certs (number)
- `cert_default_ttl_seconds`: Default TTL for certs (number)
- `policy_name`: Name of Vault policy (string)
- `auth_role_name`: Name of K8s auth role (string)
- `service_account_names`: Allowed ServiceAccount names (list)
- `service_account_namespaces`: Allowed namespaces (list)
- `token_ttl_seconds`: Token TTL (number)
- `token_max_ttl_seconds`: Token max TTL (number)
- `token_audiences`: Token audiences (list)
- `allowed_domains`: Domains allowed in certs (list)
- `allow_glob_domains`: Allow glob patterns (bool)
- `allow_any_name`: Allow any CN (bool)

### cert-manager Module: `vault_issuer`
- `enabled`: Enable Vault Issuer (bool)
- `name`: Name of Issuer resource (string)
- `vault_server`: Vault server URL (string)
- `vault_ca_bundle`: Base64-encoded CA bundle (string)
- `pki_path`: PKI signing path (string)
- `auth.role`: Vault auth role (string)
- `auth.mount_path`: Auth mount path (string)
- `auth.sa_name`: ServiceAccount name (string)
- `auth.sa_namespace`: ServiceAccount namespace (string)
- `auth.audiences`: Token audiences (list)

### cert-manager Module: `vault_injector_tls`
- `enabled`: Enable injector certificate (bool)
- `namespace`: Certificate namespace (string)
- `service_name`: Service name for DNS (string)
- `secret_name`: Secret name for cert (string)
- `duration`: Certificate duration (string)
- `renew_before`: Renewal time (string)
- `dns_names`: DNS SANs (list)

## Files Changed

### New Files:
- `modules/vault/vault-pki-for-cert-manager.tf` - Vault PKI configuration
- `modules/cert-manager/vault-issuer.tf` - Vault Issuer and RBAC
- `modules/cert-manager/vault-injector-certificate.tf` - Injector certificate

### Modified Files:
- `modules/vault/variables.tf` - Added `cert_manager_integration` variable
- `modules/vault/outputs.tf` - Added PKI integration outputs
- `modules/vault/providers.tf` - Added vault provider
- `modules/vault/root-ca.tf` - Removed old CA secret for cert-manager
- `modules/cert-manager/variables.tf` - Changed to `vault_issuer` and `vault_injector_tls`
- `modules/cert-manager/main.tf` - Added kubectl provider
- `main.tf` - Updated Vault and cert-manager module calls
- `providers.tf` - Added kubectl and vault providers

### Deleted Files:
- `modules/cert-manager/vault-injector-tls.tf` - Old CA Issuer approach
- `modules/cert-manager/vault-ca-integration.tf` - Old approach

## Testing

### Test 1: Verify Issuer is Ready
```bash
kubectl get issuer vault-issuer -n vault -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True
```

### Test 2: Verify Certificate Issued
```bash
kubectl get certificate vault-injector-tls -n vault -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True
```

### Test 3: Check Secret Contents
```bash
kubectl get secret injector-tls -n vault -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
# Should show certificate with correct DNS names and issuer
```

### Test 4: Create Test Certificate
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-certificate
  namespace: vault
spec:
  secretName: test-tls
  issuerRef:
    name: vault-issuer
    kind: Issuer
  commonName: test.vault.svc.cluster.local
  dnsNames:
    - test.vault.svc.cluster.local
```

## Troubleshooting

### Issue: Issuer Not Ready
**Check:**
```bash
kubectl describe issuer vault-issuer -n vault
```
**Common causes:**
- Vault not initialized/unsealed
- Kubernetes auth not configured in Vault
- PKI secrets engine not mounted
- Network connectivity to Vault

### Issue: Certificate Not Issued
**Check:**
```bash
kubectl describe certificate <cert-name> -n <namespace>
kubectl logs -n cert-manager deployment/cert-manager
```
**Common causes:**
- Issuer not ready
- ServiceAccount missing RBAC permissions
- Vault role/policy misconfigured
- DNS names not allowed by PKI role

### Issue: Vault Provider Errors
**Check:**
- `VAULT_ADDR` environment variable set
- `VAULT_TOKEN` environment variable set
- Vault is accessible from Terraform
- Vault is unsealed

## Next Steps

1. **Apply Configuration**: Run `tofu plan` and `tofu apply`
2. **Initialize Vault**: Unseal and configure root token
3. **Deploy Issuer**: Apply cert-manager Vault integration
4. **Test**: Create test certificate to verify
5. **Update Injector**: Restart Vault injector to use new TLS secret

## Benefits of This Approach

✅ **Security**: No CA private keys exposed outside Vault
✅ **Automation**: Certificates issued and renewed automatically
✅ **Audit**: All certificate operations logged in Vault
✅ **Policy Control**: Fine-grained access control via Vault policies
✅ **Scalability**: Vault PKI can handle high certificate volume
✅ **Integration**: Works with existing Vault infrastructure
✅ **Standard Pattern**: Follows HashiCorp/cert-manager documentation
