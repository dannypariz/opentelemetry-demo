#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="otel-demo"
DEPLOYMENT="checkout"

echo "=== Pre-Demo Readiness Check ==="
echo ""

# Pod running?
echo -n "Checkout pod status    ... "
RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=checkout \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$RUNNING" -ge 1 ]; then
  echo "OK ($RUNNING running)"
else
  echo "FAIL — no running pods"
  exit 1
fi

# Current image
echo -n "Checkout image         ... "
IMAGE=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="checkout")].image}' 2>/dev/null || echo "unknown")
echo "${IMAGE##*/}"  # print only tag portion

# CHECKOUT_BUG_ENABLED
echo -n "CHECKOUT_BUG_ENABLED   ... "
BUG=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="checkout")].env[?(@.name=="CHECKOUT_BUG_ENABLED")].value}' 2>/dev/null || echo "")
echo "${BUG:-not set}"

# SERVICE_VERSION
echo -n "SERVICE_VERSION        ... "
VER=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="checkout")].env[?(@.name=="SERVICE_VERSION")].value}' 2>/dev/null || echo "")
echo "${VER:-not set}"

echo ""
echo "=== Status ==="
if [ "${BUG}" = "true" ]; then
  echo "Ready: bug is ACTIVE. Latency spike will occur on checkout."
elif [ "${BUG}" = "false" ]; then
  echo "NOT ready: bug is FIXED. Run: ./deploy.sh --enable-bug"
else
  echo "NOT ready: CHECKOUT_BUG_ENABLED not set. Run: ./deploy.sh --enable-bug"
fi
