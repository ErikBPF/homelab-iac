# OpenCode routing through LiteLLM

**Status:** Proposed

## Decision

New sessions start with `litellm/glm-5`. GLM plans, architects, orchestrates, and reviews. Architect owns code review. General and Explore use `litellm/mimo` for implementation, debugging, and exploration. This division is guidance, not mechanical tool denial.

Existing sessions remain intact and switch models explicitly when resumed. Direct OpenCode Go remains an emergency fallback; OpenAI OAuth remains a manual subscription path.

## Catalog contract

OpenCode exposes agent-capable conversational routes only; embedding routes stay in LiteLLM. Logical aliases remain stable while LiteLLM owns exact upstream versions. Metadata must match the reviewed upstream catalog, including prices, cached-read benchmarks, context/output limits, reasoning, tools, and modalities.

All current Zen free models may be exposed as manual, visibly non-confidential routes. Legacy ambiguous aliases are removed; virtual-key allowlists are reminted during the Terraform cutover.

## Cache policy

No response or semantic cache for coding agents. Use upstream prompt-prefix caching and observe cache-read counters. Replaying full cached responses risks stale code and tool decisions.

## Acceptance

- Resolved OpenCode config parses.
- New primary responses record `litellm/glm-5`.
- Architect review records `litellm/glm-5`.
- General/Explore responses record `litellm/mimo`.
- LiteLLM traces attribute calls to the OpenCode consumer.
- Direct-provider fallback is selectable but never default.
