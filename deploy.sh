#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="otel-demo"
DEPLOYMENT="checkout"
SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "local")

usage() {
  echo "Usage: $0 [--enable-bug | --fix | --status]"
  echo ""
  echo "  --enable-bug   Set CHECKOUT_BUG_ENABLED=true  (demo reset — re-enables the N+1 latency spike)"
  echo "  --fix          Set CHECKOUT_BUG_ENABLED=false  (simulate the fix locally, skips GitHub)"
  echo "  --status       Show current env var values on the running deployment"
  exit 1
}

patch_deployment() {
  local bug_enabled="$1"
  local version="$2"
  kubectl patch deployment "$DEPLOYMENT" \
    -n "$NAMESPACE" \
    --type=strategic \
    -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"checkout\",\"env\":[{\"name\":\"CHECKOUT_BUG_ENABLED\",\"value\":\"${bug_enabled}\"},{\"name\":\"SERVICE_VERSION\",\"value\":\"${version}\"}]}]}}}}"
}

case "${1:-}" in
  --enable-bug|--reset)
    echo "Enabling N+1 bug on checkout deployment..."
    patch_deployment "true" "${SHA}-buggy"
    echo "Waiting for rollout..."
    kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=3m
    echo ""
    echo "Done. Bug is ACTIVE — CHECKOUT_BUG_ENABLED=true"
    echo "Latency will spike within ~30s once traffic hits checkout."
    ;;
  --fix)
    echo "Fixing N+1 bug on checkout deployment..."
    patch_deployment "false" "${SHA}-fix"
    echo "Waiting for rollout..."
    kubectl rollout status deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=3m
    echo ""
    echo "Done. Bug is FIXED — CHECKOUT_BUG_ENABLED=false"
    ;;
  --status)
    BUG=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[?(@.name=="checkout")].env[?(@.name=="CHECKOUT_BUG_ENABLED")].value}' 2>/dev/null || echo "not set")
    VER=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
      -o jsonpath='{.spec.template.spec.containers[?(@.name=="checkout")].env[?(@.name=="SERVICE_VERSION")].value}' 2>/dev/null || echo "not set")
    echo "CHECKOUT_BUG_ENABLED : ${BUG:-not set}"
    echo "SERVICE_VERSION      : ${VER:-not set}"
    ;;
  *)
    usage
    ;;
esac
