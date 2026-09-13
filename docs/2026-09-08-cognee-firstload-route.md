# Temporary Cognee BGE-M3 route — closed

**Status:** Superseded. The September 8 first-load override expired on
September 9, 2026 at 00:00 UTC. This is a historical closeout, not a runnable
deployment or rollback procedure.

The pilot temporarily redirected two `bge-m3` deployments from Kepler port
8085 to Apollo port 18081. Its unpublished apply helper expected the old
Kepler upstream, and its restore helper would write that upstream back. Those
assumptions no longer match the declared control plane.

[PR #113](https://github.com/ErikBPF/homelab-iac/pull/113), merged as
`16449ba51c4a4e0ca97aff5255c9c8ec1920866a`, moved the production retrieval
declarations to Orion:

- `bge-m3`: `http://100.72.85.73:8085/v1`.
- `bge-reranker-v2-m3`: `http://100.72.85.73:8087`.

The current source is
[`models.json`](../components/litellm/environments/home/production/models.json),
owned by the adjacent production `terragrunt.hcl`. Future changes must use
that unit's reviewed plan/apply workflow. Do not run the expired pilot's
apply, restore, or rollback scheduler against current deployments.

The obsolete `temporary-cognee-embedding-route.py`,
`schedule-cognee-route-rollback`, and pilot-only test remain unpublished;
their original copies are preserved in local stash
`8b38d67509b8614323e780211e520bbfd0b9a421`. Reintroducing them would add a
second route owner and permit restoration of a retired endpoint.

Verification: `bash tests/infra-ssot-contract.sh s05` checks the current
production declarations and consumer allowlists offline. This closeout does
not establish live endpoint health, remove remote snapshots or transient
timers, or prove Cognee retrieval value and populated-dataset recovery.
Those require separate current evidence; historical pilot results do not
close them.
