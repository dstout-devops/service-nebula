#!/usr/bin/env bash
set -euo pipefail

mkdir -p certs

# Root CA
step certificate create "service-nebula Root CA" \
  certs/root_ca.crt certs/root_ca.key \
  --profile root-ca \
  --no-password \
  --insecure \
  --force

step certificate create na-control-plane \
  certs/kubelet-na.crt certs/kubelet-na.key \
  --ca certs/root_ca.crt --ca-key certs/root_ca.key \
  --profile leaf \
  --san na-control-plane \
  --san na-worker \
  --san na-worker2 \
  --san 127.0.0.1 \
  --no-password \
  --insecure \
  --force

step certificate create eu-control-plane \
  certs/kubelet-eu.crt certs/kubelet-eu.key \
  --ca certs/root_ca.crt --ca-key certs/root_ca.key \
  --profile leaf \
  --san eu-control-plane \
  --san eu-worker \
  --san eu-worker2 \
  --san 127.0.0.1 \
  --no-password \
  --insecure \
  --force