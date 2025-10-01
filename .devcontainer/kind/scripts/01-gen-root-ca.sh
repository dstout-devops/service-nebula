#!/usr/bin/env bash
set -euo pipefail

mkdir -p certs

# Root CA
step certificate create "service-nebula Root CA" \
  certs/root-ca.crt certs/root-ca.key \
  --profile root-ca \
  --no-password \
  --insecure \
  --force

step certificate create "service-nebula Intermediate CA" \
  certs/int-ca.crt certs/int-ca.key \
  --profile intermediate-ca \
  --ca certs/root-ca.crt \
  --ca-key certs/root-ca.key \
  --no-password \
  --insecure \
  --force

step certificate create mgmt-control-plane \
  certs/kubelet-mgmt.crt certs/kubelet-mgmt.key \
  --ca certs/int-ca.crt --ca-key certs/int-ca.key \
  --profile leaf \
  --san mgmt-control-plane \
  --san mgmt-worker \
  --san mgmt-worker2 \
  --san mgmt-worker3 \
  --san 127.0.0.1 \
  --san 0.0.0.0 \
  --no-password \
  --insecure \
  --force
