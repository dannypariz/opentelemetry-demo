# Grafana Assistant Demo Prompts

## The Story

Checkout p99 latency spikes above 400ms → Grafana alert fires → Grafana Assistant investigates
→ traces reveal N+1 bug → finds the commit → creates a fix PR → merge deploys in ~30s → latency recovers.

Before starting: `./demo-check.sh` to confirm bug is active.

---

## Prompt 1 — Spot the problem

> "There's an alert firing for high checkout latency. Can you investigate what's happening?"

**What to expect:** Assistant queries spanmetrics, confirms p99 > 400ms on `CheckoutService/PlaceOrder`, shows the spike timeline and when it started.

---

## Prompt 2 — Find root cause in traces

> "Dig into the checkout service traces for PlaceOrder. What's making it slow?"

**What to expect:** Finds traces with repeated `GetProduct` calls, each taking ~280ms. Identifies the N+1 pattern — one serial database/RPC call per cart item instead of batching.

---

## Prompt 3 — Link to the code

> "Which part of the checkout code is causing this? Can you find the commit or line that introduced these slow calls?"

**What to expect:** Points to `prepOrderItems` in `src/checkout/main.go`. The culprit is `CHECKOUT_BUG_ENABLED=true` which triggers a 280ms `time.Sleep` per cart item. Links to the GitHub commit.

---

## Prompt 4 — Create the fix PR

> "Create a GitHub pull request to fix this. The fix is to change CHECKOUT_BUG_ENABLED to \"false\" in k8s/checkout-config.yaml"

**What to expect:** Assistant uses GitHub MCP to:
1. Create a branch `fix/checkout-latency`
2. Edit `k8s/checkout-config.yaml`: `CHECKOUT_BUG_ENABLED: "false"`
3. Open a PR with title "fix: disable checkout N+1 latency bug"

Merge the PR — `deploy-on-merge.yml` runs automatically, patches the deployment in ~30s, and posts a Grafana annotation.

---

## Prompt 5 — Before/after comparison

> "Show me the checkout latency before and after the fix. Compare p99 between the two versions."

**What to expect:** PromQL grouped by `service_version` shows the split at the deployment timestamp:

```promql
histogram_quantile(0.99,
  sum by (le, service_version) (
    rate(traces_spanmetrics_latency_bucket{
      job="otel-demo/checkout",
      span_name="oteldemo.CheckoutService/PlaceOrder"
    }[5m])
  )
)
```

`*-buggy` version: ~1.5s p99 (with 5-6 items in cart at 280ms each)  
`*-fix` version: ~50ms p99 (back to normal)

---

## Demo reset

To run the demo again:

```bash
./deploy.sh --enable-bug
```

Waits for rollout, then latency spikes again within ~30s.
