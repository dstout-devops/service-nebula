// Vault initialization and unseal implemented as in-cluster Kubernetes Job
// This replaces local-exec provisioners with a namespaced ServiceAccount + Role
// and a single Job which runs the init/unseal logic inside the cluster.

// Service account used by the Job
resource "kubernetes_service_account" "vault_init" {
  metadata {
    name      = "vault-init-sa"
    namespace = var.namespace
    labels = {
      app = "vault-init"
    }
  }
}

// Minimal Role granting access required by the init job: pods exec, pods get/list, secrets create/patch
resource "kubernetes_role" "vault_init" {
  metadata {
    name      = "vault-init-role"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec"]
    verbs      = ["get", "list", "create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create", "patch", "update"]
  }
}

resource "kubernetes_role_binding" "vault_init" {
  metadata {
    name      = "vault-init-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_init.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_init.metadata[0].name
    namespace = var.namespace
  }
}

// One idempotent Job that performs wait -> init -> unseal -> HA join (when is_ha)
resource "kubernetes_job" "vault_init_job" {
  metadata {
    name      = "vault-init-job"
    namespace = var.namespace
    labels = {
      app = "vault-init"
    }
  }

  spec {
    backoff_limit             = 0
    ttl_seconds_after_finished = 300

    template {
      metadata {
        labels = {
          app = "vault-init"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.vault_init.metadata[0].name
        restart_policy       = "Never"

        container {
          name  = "vault-init"
          image = "bitnami/kubectl:1.27.4"
          image_pull_policy = "IfNotPresent"
          command = ["/bin/sh", "-c"]
          args = [<<-EOF
            set -euo pipefail

            echo "Preparing in-cluster kubeconfig using serviceaccount token"
            TOKEN_FILE=/var/run/secrets/kubernetes.io/serviceaccount/token
            CA_FILE=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            KUBE_HOST=${"${"}KUBERNETES_SERVICE_HOST${"}"}
            KUBE_PORT=${"${"}KUBERNETES_SERVICE_PORT${"}"}

            cat > /tmp/kubeconfig <<-KCFG
            apiVersion: v1
            kind: Config
            clusters:
            - cluster:
                certificate-authority: ${CA_FILE}
                server: https://${KUBE_HOST}:${KUBE_PORT}
              name: in-cluster
            contexts:
            - context:
                cluster: in-cluster
                user: sa
              name: in-cluster
            current-context: in-cluster
            users:
            - name: sa
              user:
                token: "$(cat ${TOKEN_FILE})"
            KCFG

            export KUBECONFIG=/tmp/kubeconfig

            echo "⏳ Waiting for Vault pod(s) to be running in namespace ${var.namespace}..."
            RETRY=0
            MAX_RETRIES=60
            while [ $RETRY -lt $MAX_RETRIES ]; do
              POD_COUNT=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault,app.kubernetes.io/instance=vault --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
              if [ "$POD_COUNT" -gt 0 ]; then
                echo "✅ Vault pod(s) are running (found $POD_COUNT)"
                break
              fi
              echo "  Waiting for Vault pods... ($RETRY/$MAX_RETRIES)"
              sleep 5
              RETRY=$((RETRY + 1))
            done
            if [ $RETRY -ge $MAX_RETRIES ]; then
              echo "❌ Timeout waiting for Vault pods"
              kubectl get pods -n ${var.namespace} || true
              exit 1
            fi

            # Determine vault address
            if [ "${var.is_tls_enabled}" = "true" ]; then
              VAULT_ADDR='https://${var.service_name}.${var.namespace}.svc.cluster.local:8200'
              export VAULT_SKIP_VERIFY=1
            else
              VAULT_ADDR='http://${var.service_name}.${var.namespace}.svc.cluster.local:8200'
            fi
            export VAULT_ADDR

            POD_NAME=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

            # Initialize if necessary
            if kubectl exec -n ${var.namespace} $POD_NAME -- sh -c "vault status 2>&1" | grep -q "Initialized.*false"; then
              echo "🔐 Initializing Vault..."
              KEY_SHARES=$( [ "${var.is_ha}" = "true" ] && echo 5 || echo 1 )
              KEY_THRESHOLD=$( [ "${var.is_ha}" = "true" ] && echo 3 || echo 1 )

              kubectl exec -n ${var.namespace} $POD_NAME -- sh -c "vault operator init -key-shares=$KEY_SHARES -key-threshold=$KEY_THRESHOLD -format=json" > /tmp/vault-init-keys.json
              ROOT_TOKEN=$(cat /tmp/vault-init-keys.json | jq -r '.root_token')

              echo "Creating kubernetes secret ${var.unseal_keys_secret_name}"
              kubectl create secret generic ${var.unseal_keys_secret_name} -n ${var.namespace} --from-literal=root-token="$ROOT_TOKEN" --dry-run=client -o yaml | kubectl apply -f -

              for i in $(seq 0 $(($KEY_SHARES - 1))); do
                UNSEAL_KEY=$(cat /tmp/vault-init-keys.json | jq -r ".unseal_keys_b64[$i]")
                # store base64-encoded under /data/unseal-key-i to match existing code expectations
                kubectl patch secret ${var.unseal_keys_secret_name} -n ${var.namespace} --type=json -p="[{\"op\": \"add\", \"path\": \"/data/unseal-key-$i\", \"value\": \"$(echo -n $UNSEAL_KEY | base64 -w 0)\"}]" || true
              done

              echo "✅ Vault initialized and credentials stored"
            else
              echo "ℹ️ Vault already initialized"
            fi

            # Load unseal keys from secret
            if kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} &>/dev/null; then
              VAULT_ROOT_TOKEN=$(kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} -o jsonpath='{.data.root-token}' | base64 -d || true)
              export VAULT_ROOT_TOKEN
              for i in 0 1 2 3 4; do
                KEY=$(kubectl get secret ${var.unseal_keys_secret_name} -n ${var.namespace} -o jsonpath="{.data.unseal-key-$i}" 2>/dev/null | base64 -d || echo "")
                if [ -n "$KEY" ]; then
                  eval "export VAULT_UNSEAL_KEY_$i='$KEY'"
                fi
              done
            fi

            # Unseal master pod or first pod
            if [ "${var.is_ha}" = "true" ]; then
              echo "🔓 HA mode - unsealing vault-0"
              kubectl exec -n ${var.namespace} vault-0 -- sh -c "vault operator unseal '$VAULT_UNSEAL_KEY_0' > /dev/null || true; vault operator unseal '$VAULT_UNSEAL_KEY_1' > /dev/null || true; vault operator unseal '$VAULT_UNSEAL_KEY_2' || true"
            else
              POD_NAME=$(kubectl get pods -n ${var.namespace} -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
              kubectl exec -n ${var.namespace} $POD_NAME -- vault operator unseal $VAULT_UNSEAL_KEY_0 || true
            fi

            # For HA: join peers and unseal them
            if [ "${var.is_ha}" = "true" ]; then
              for i in 1 2; do
                echo "Configuring vault-$i"
                STATUS=$(kubectl exec -n ${var.namespace} vault-$i -- sh -c "vault status -format=json" 2>/dev/null || echo '{"initialized":false}')
                if echo "$STATUS" | jq -e '.initialized == false' > /dev/null; then
                  LEADER_ADDR="${var.vault_protocol}://vault-0.${var.internal_service_name}:8200"
                  if [ "${var.is_tls_enabled}" = "true" ]; then
                    kubectl exec -n ${var.namespace} vault-$i -- sh -c "vault operator raft join -leader-ca-cert=\"\$(cat ${var.userconfig_path}/vault.ca)\" -leader-client-cert=\"\$(cat ${var.userconfig_path}/vault.crt)\" -leader-client-key=\"\$(cat ${var.userconfig_path}/vault.key)\" $LEADER_ADDR"
                  else
                    kubectl exec -n ${var.namespace} vault-$i -- vault operator raft join $LEADER_ADDR || true
                  fi
                  kubectl exec -n ${var.namespace} vault-$i -- sh -c "vault operator unseal '$VAULT_UNSEAL_KEY_0' > /dev/null || true; vault operator unseal '$VAULT_UNSEAL_KEY_1' > /dev/null || true; vault operator unseal '$VAULT_UNSEAL_KEY_2' || true"
                fi
              done
            fi

            echo "✅ Vault init/unseal job complete"
          EOF]

          // pass a minimal set of env vars for templating
          env {
            name  = "KUBERNETES_SERVICE_HOST"
            value = "${"${"}KUBERNETES_SERVICE_HOST${"}"}"
          }
        }
      }
    }
  }
}
