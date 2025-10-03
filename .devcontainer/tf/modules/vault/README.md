# Vault Module - HashiCorp Official Pattern

This module implements HashiCorp's recommended Vault deployment patterns for Kubernetes, following the official documentation:
https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm/examples/ha-tls

## 🎯 Deployment Modes

The module supports four deployment modes that follow HashiCorp's recommended learning path:

### 1. **standalone** - Basic Integrated Storage
**Phase 2**: Starting point for production-like deployments
- Single Vault pod
- File-based storage
- No TLS
- Perfect for development and testing

### 2. **standalone-tls** - Add Security
**Phase 3**: Add TLS encryption
- Single Vault pod
- File-based storage  
- TLS enabled
- Learn TLS configuration

### 3. **ha-raft** - High Availability
**Phase 4**: Production HA without TLS (for testing)
- 3 Vault pods
- Raft consensus storage
- Auto-join cluster
- No TLS (test HA features first)

### 4. **ha-raft-tls** - Production Ready ⭐
**Phase 4 Complete**: Full production setup
- 3 Vault pods
- Raft consensus storage
- TLS enabled
- Auto-unseal support ready
- **Recommended for production**

## 📋 Quick Start

### Example 1: Standalone (Development)
```hcl
module "vault" {
  source = "./modules/vault"
  
  cluster_name    = "mgmt"
  namespace       = "vault"
  deployment_mode = "standalone"
  
  providers = {
    helm       = helm.mgmt
    kubernetes = kubernetes.mgmt
  }
}
```

### Example 2: HA with TLS (Production)
```hcl
module "vault" {
  source = "./modules/vault"
  
  cluster_name    = "mgmt"
  namespace       = "vault"
  deployment_mode = "ha-raft-tls"
  ha_replicas     = 3
  enable_tls      = true
  
  providers = {
    helm       = helm.mgmt
    kubernetes = kubernetes.mgmt
  }
}
```

## 🔧 Features

### Automated TLS Certificate Generation
- Generates CA and server certificates automatically
- Includes proper SANs for all Vault pods
- Creates Kubernetes secret for easy rotation
- Follows HashiCorp TLS best practices

### Automated Initialization
- Automatically initializes Vault
- Unseals all pods (HA mode)
- Joins Raft cluster members
- Saves credentials securely

### Production Ready
- Persistent storage with PVCs
- Resource requests and limits
- Health checks and readiness probes
- Service registration for HA

## 📊 Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `deployment_mode` | string | `"standalone"` | Vault deployment mode |
| `ha_replicas` | number | `3` | Number of HA replicas |
| `enable_tls` | bool | `false` | Enable TLS |
| `vault_version` | string | `"0.28.1"` | Helm chart version |
| `vault_image_tag` | string | `"1.18.3"` | Vault image tag |
| `storage_size` | string | `"10Gi"` | Storage size |
| `enable_ui` | bool | `true` | Enable Vault UI |

## 🚀 Outputs

| Output | Description |
|--------|-------------|
| `vault_addr` | Vault server address |
| `namespace` | Vault namespace |
| `is_ha_mode` | Whether HA is enabled |
| `is_tls_enabled` | Whether TLS is enabled |
| `deployment_mode` | Current deployment mode |

## 🔐 Post-Deployment

### Access Vault

After deployment, credentials are saved to `/tmp/vault-credentials`:

```bash
# Source the credentials
source /tmp/vault-credentials

# Set Vault address
export VAULT_ADDR="http://vault.vault.svc.cluster.local:8200"

# Login with root token
vault login $VAULT_ROOT_TOKEN

# Check status
vault status
```

### For TLS-enabled deployments:

```bash
export VAULT_ADDR="https://vault.vault.svc.cluster.local:8200"
export VAULT_SKIP_VERIFY=1  # For dev; use proper CA in production
```

## 🎓 Progressive Learning Path

Follow HashiCorp's recommended path:

1. **Start with** `standalone`
   - Learn basic Vault operations
   - Understand storage concepts
   - Practice init/unseal process

2. **Add** `standalone-tls`
   - Learn TLS configuration
   - Understand certificate management
   - Practice secure communication

3. **Move to** `ha-raft`
   - Learn HA concepts
   - Understand Raft consensus
   - Practice cluster operations

4. **Final** `ha-raft-tls`
   - Combine all learnings
   - Production-ready setup
   - Full security + HA

## ⚠️ Security Notes

### Development vs Production

**Development (Current Setup)**:
- Auto-initialization enabled
- Credentials saved to filesystem
- Single unseal key
- Skip TLS verification

**Production (Recommended)**:
- Manual initialization
- Key shares distributed to operators
- Multiple unseal keys (5/3 threshold)
- Proper CA certificate distribution
- Auto-unseal with cloud KMS
- Vault Enterprise with HSM

## 📚 References

- [HashiCorp Vault on Kubernetes](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Helm Chart Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/helm)
- [HA with Integrated Storage](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/helm/examples/ha-tls)
- [Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)
