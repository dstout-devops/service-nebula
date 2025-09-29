apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: vault-issuer
spec:
  vault:
    server: "__VAULT_SERVER__"
    path: "__VAULT_SIGN_PATH__"
    # either inline caBundle or secretRef — we’ll use secretRef
    caBundleSecretRef:
      name: __VAULT_CA_SECRET__
      key: __VAULT_CA_KEY__
    auth:
      kubernetes:
        role: __VAULT_KUBE_ROLE__
        mountPath: /v1/auth/kubernetes
        serviceAccountRef:
          name: __VAULT_SA__
