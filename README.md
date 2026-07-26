# VibeMaestro — Model Gateway

A single Cloudflare Worker that proxies LLM chat completions for a multi-user product with **per-user spend caps**, **tiered model routing**, and a **free-tier fallback** that costs ~$0. It is the economic engine of [VibeMaestro](https://vibemaestro.app), extracted here as a clean, self-contained reference.

> Sanitized public reference. No API keys, account ids, or private infrastructure are included — everything sensitive is an environment binding.

## What it does

`POST /v1/chat/completions` (OpenAI-shaped) with a session cookie or `Authorization: Bearer <sid>`:

1. **Authenticates** the session against the [auth-gate](../vibemaestro-auth-gate) (`GATE_URL/verify`).
2. **Loads the user's tier + preferences** from D1.
3. **Routes to a model**:
   - **Free tier** → Cloudflare **Workers AI** free-neuron model (`env.AI.run(...)`), ~$0, fully self-contained. Optionally a metered DeepSeek path if `free_deepseek` is set.
   - **Paid tier** → routes through **Cloudflare AI Gateway** with `cf-aig-metadata {user_id}` so the gateway enforces a **per-user daily spend cap**. Default provider is DeepSeek; users can select Claude, or **bring their own key** via an `x-anthropic-key` header.
4. **Degrades gracefully**: a `429` (cap hit) transparently downgrades to the free model instead of erroring.

Other routes: `GET /health`, `GET /v1/usage` (per-user spend), `GET /_diag`.

## Why AI Gateway

The gateway does the hard part of multi-tenant cost control for you:

- **Per-user partitioned caps** — each user gets their own daily budget bucket (partitioned by `metadata.user_id`).
- **A global safety cap** — a platform-wide circuit breaker.
- **Request logging** — token/cost telemetry per call.

The worker just tags each upstream request with the user id; the gateway enforces the limits.

## Model routing model

`users.model_pref` (`deepseek` | `claude`) + `users.model_unlocks` (JSON array of premium model ids) decide which model a paid user gets. Premium models are gated: a user can only select a model that is in their `model_unlocks`. Free users are pinned to the free-neuron model unless `free_deepseek` is enabled.

## Deploy

```bash
npm i -g wrangler
# uses the SAME D1 database as the auth-gate:
wrangler d1 execute vibemaestro --file=schema.sql

wrangler secret put CF_ACCOUNT_ID
wrangler secret put DEEPSEEK_API_KEY     # optional (paid DeepSeek default)
wrangler secret put VM_ANTHROPIC_KEY     # optional (platform Claude)

# set your AI Gateway slug + gate url in wrangler.toml [vars], then:
wrangler deploy
```

Create the AI Gateway in the Cloudflare dashboard (enable logging + spend limits: a per-user rule partitioned by `metadata.user_id`, plus a global safety rule).

## Bindings

| Binding | Type | Purpose |
|---|---|---|
| `DB` | D1 | users, usage_log (shared with auth-gate) |
| `AI` | Workers AI | free-tier model fallback |
| `GATE_URL` | var | auth-gate base url for session `/verify` |
| `AIG_SLUG`, `CF_ACCOUNT_ID` | var/secret | AI Gateway routing |
| `DEEPSEEK_API_KEY` | secret | paid DeepSeek default (optional) |
| `VM_ANTHROPIC_KEY` | secret | platform Claude (optional; BYO supported) |
| `PAID_DAILY_CAP_USD` | var | per-user in-worker soft cap |

## Pairs with

[`vibemaestro-auth-gate`](../vibemaestro-auth-gate) — this gateway calls its `/verify` to authenticate every request.

## License

MIT — see [LICENSE](./LICENSE).
