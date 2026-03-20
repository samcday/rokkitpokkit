# AGENTS

## Kubernetes / Infra Ownership

- The manifests in `infra/k8s` are **not** applied directly from this repository.
- They are reconciled by **Flux** running in the **hub-cluster**.
- The Flux configuration that wires this up lives in `github.com/samcday/infra`.

## What This Means For Changes

- Treat `infra/k8s` in this repo as desired state that Flux will apply.
- Do not rely on `kubectl apply -k infra/k8s` from this repo as the normal deployment path.
- To change runtime behavior, update manifests here and ensure corresponding Flux config in `samcday/infra` points to/syncs this state.

## Reconciling

- Reconciliation should be triggered/observed through Flux in the hub-cluster, not by manual apply from this repo.
- If asked to "reconcile", use Flux against the hub-cluster resources defined in `samcday/infra`.

## Agent Guidance

- Prefer explaining this deployment flow when Kubernetes apply/reconcile requests come up.
- If manual `kubectl apply` fails (for example missing namespaces or cluster-local prerequisites), treat that as expected unless the user explicitly wants a direct apply workflow.
