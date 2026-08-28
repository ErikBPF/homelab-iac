# Production Spark Connect stability, placement, and partition control

**Status:** Proposed after live production inspection; no GitOps or AKS change
applied — 2026-08-20.

## Goal

Keep the persistent Spark Connect driver on the general `data-jobs` pool, reserve
the dedicated large node for its executor, remove observed executor memory-limit
pressure, and reduce wasteful task partitioning without hiding genuine parallel
work. Add the minimum health, history, and pressure signals needed to operate the
cluster safely.

This record coordinates the change. Implementation belongs in the Argo CD source
repository reported by production, `nstechhub/dataplatform-gitops`, under
`charts/data-jobs/persistent-cluster/spark-connect`; any AKS node-pool change
belongs in its owning platform IaC repository.

## Trigger and verified production state

Read-only inspection used `az aks command invoke` against
`aks-dataplatform-eus-prd` in `rg-dataplatform-eus-prd`.

- `SparkConnect/dataplatform-spark` runs Spark `4.1.3` with one server and one
  executor. Both currently select `node-group=data-jobs-big`.
- The dedicated `Standard_D32pds_v6` node is a single-node, non-autoscaled pool
  tainted `dedicated=spark-connect:NoSchedule`.
- The server reserves 4 CPU and 20 GiB but uses about 5.9 GiB. Observed driver
  heap peaked near 4.2 GiB and CPU remained below one core during inspection.
- The executor reserves 26 CPU and 96 GiB: 88 GiB heap plus 8 GiB overhead. Even
  with zero running Spark jobs it retained about 95.9 GiB because the JVM starts
  with matching `-Xms` and `-Xmx` values.
- Executor cgroup `memory.events max` reached 7,847 while `oom` and `oom_kill`
  remained zero. This is memory-limit pressure, not proof of a heap leak.
- The two `data-jobs` nodes each expose about 7.8 CPU and 26.2 GiB allocatable.
  At inspection time, a 2 CPU / 12 GiB server fit on either node by requests.
- AQE and shuffle coalescing are enabled, but
  `spark.sql.adaptive.coalescePartitions.parallelismFirst=true`, shuffle
  partitions remain at 200, and file partition count has no maximum.
- Since the 07:31 server restart, 923 stages completed: 317 used 105–200 tasks,
  295 used at least 100 tasks while processing less than 1 MiB per task, and no
  stage spilled. The largest observed stage processed about 44.7 GiB.
- All Spark jobs use the FAIR scheduler's default pool. The YuniKorn queue limits
  applications to 11 but declares no resource ceiling that blocks the proposed
  driver/executor split.
- The server pod has no startup, readiness, or liveness probe. No Spark
  `ServiceMonitor`, `PodMonitor`, or PDB was found.

## Decisions

### D1 — split driver and executor placement

Target the server at `node-group=data-jobs`. Remove its dedicated-large-node
toleration. Keep the executor selector and toleration unchanged so only the
executor can consume `data-jobs-big`.

Target server resources:

- 2 CPU request/limit;
- 8 GiB Spark driver heap;
- 4 GiB driver overhead;
- 12 GiB pod memory request/limit.

Target executor resources:

- 26 CPU request/limit;
- retain the 88 GiB heap;
- raise executor overhead from 8 GiB to 16 GiB;
- raise pod memory request/limit from 96 GiB to 104 GiB.

The split leaves roughly 15 GiB of large-node allocatable memory before daemon
overhead and removes the driver from the executor's failure and pressure domain.
Spark supports separate driver and executor selectors on Kubernetes; placement
does not require a custom transport or proxy. See the
[Spark Kubernetes guide](https://spark.apache.org/docs/latest/running-on-kubernetes.html).

### D2 — reduce initial and file partition counts

Keep AQE and its 64 MiB advisory target. Set:

```text
spark.sql.shuffle.partitions=104
spark.sql.adaptive.coalescePartitions.parallelismFirst=false
spark.sql.files.maxPartitionNum=208
```

Rationale:

- 104 shuffle partitions are four waves across 26 executor cores and halve the
  current default before AQE coalesces small shuffle output.
- `parallelismFirst=false` makes AQE respect the 64 MiB advisory size instead of
  maximizing tiny partitions.
- 208 is an eight-wave suggested ceiling for file scans. It cuts the observed
  1,721-task outlier substantially without forcing the largest scan into only
  two or four waves.
- The largest observed 44.7 GiB workload would average about 440 MiB per shuffle
  partition at 104 or 220 MiB per file partition at 208. Historical stages had
  no spill, so these are conservative initial ceilings rather than final tuning.

Spark documents 200 as the shuffle default and `maxPartitionNum` as a suggested,
not guaranteed, file-split ceiling. See the
[Spark SQL performance guide](https://spark.apache.org/docs/latest/sql-performance-tuning).

Do not add application-level `repartition()` or `coalesce()` calls globally.
Use them only where a measured stage still violates the size or task-count
guardrails after this cluster-level change.

### D3 — expose pressure and retained execution history

Use the platform's existing monitoring stack; do not introduce another metrics
system.

- Enable Spark's Prometheus servlet and add the chart-native
  `ServiceMonitor` or `PodMonitor` supported by the deployed stack.
- Alert on executor cgroup limit hits, OOM/OOM-kill, pod restart, sustained memory
  above 90%, failed executors, and Spark server unavailability.
- Record executor heap, direct/off-heap memory, GC time, active tasks, failed
  tasks, spill, and stage bytes per task.
- Enable Spark event logging to an approved durable object-store path and expose
  it through the existing or separately approved Spark History Server. Runtime
  credentials remain in the sanctioned secret store; this proposal authorizes
  no secret value in Git.
- Enable stage executor metrics in the event log so pressure evidence survives
  a driver restart. See the
  [Spark monitoring guide](https://spark.apache.org/docs/latest/monitoring.html).

Initial alert gates:

- `memory.events max` increases during a representative workload;
- `oom` or `oom_kill` is non-zero;
- executor memory remains above 90% of its limit for 10 minutes;
- driver or executor restarts unexpectedly;
- GC exceeds 5% of aggregate executor run time;
- any memory or disk spill appears after the partition change.

Tune these gates only from retained production evidence.

### D4 — add conservative server health checks

Add startup and readiness probes for the Spark Connect endpoint. Startup must
protect slow JVM initialization; readiness must remove an unusable server from
the service before clients connect.

Do not add an aggressive liveness probe that checks only whether a port is open.
Add liveness only after a cheap semantic endpoint proves that the Spark context
can accept work, and give it a high failure threshold. Kubernetes warns that an
incorrect liveness probe can create cascading restarts; see the
[probe guidance](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/).

### D5 — treat large-node redundancy as a separate cost/SLA gate

The single large node remains a production failure domain after D1. Before
changing node-pool cost or topology:

1. identify the owning AKS IaC source;
2. quantify acceptable executor replacement time;
3. confirm SKU availability across zones;
4. compare a zone-aware min-1/max-2 pool with VMSS replacement at count one;
5. require a pending-executor and node-loss drill before declaring resilience.

Do not claim driver or Spark Connect session HA. A one-pod PDB can block voluntary
maintenance but cannot preserve sessions through a node or process failure.
Kubernetes documents that PDBs protect voluntary eviction only; see the
[PDB guidance](https://kubernetes.io/docs/tasks/run-application/configure-pdb/).

### D6 — leave GC and executor rolling unchanged

Do not change the collector, heap geometry, Spark memory fractions, or executor
rolling policy now. Observed GC was low, no stage spilled, and fixed `Xms=Xmx`
explains high idle RSS. Reopen only if retained metrics show rising live-set,
major-GC pressure, or degradation across comparable workloads.

## Explicitly excluded

- Reducing or otherwise changing the Airflow Spark pool.
- Adding Spark scheduler pools or per-DAG FAIR weights without a measured
  priority/starvation problem.
- Adding more executors; the dedicated node currently fits one 26-core executor.
- Application-wide `repartition()`/`coalesce()` rewrites.
- Automatic executor rolling as a substitute for diagnosing memory pressure.
- A PDB or replica count presented as Spark Connect high availability.
- Spark or Delta version upgrades in the same rollout.

## Delivery order and gates

### Gate 0 — source and maintenance review

- Confirm `values-prd.yaml` renders the separate server/executor selectors and
  exact resource sums.
- Confirm a 2 CPU / 12 GiB server fits both `data-jobs` nodes by requests and that
  the pool can scale or reserve capacity if ordinary jobs consume that headroom.
- Capture the current CR, pod placement, cgroup events, Spark environment, and
  completed-stage baseline.
- Drain active Spark Connect sessions and verify zero running Spark jobs. The
  server restart invalidates sessions.

### Gate 1 — placement and memory rollout

- Sync only D1 first.
- Verify the server schedules on `data-jobs` and the executor on
  `data-jobs-big`.
- Run a connect/query smoke test and one representative production workload.
- Hold for one peak window. Require stable `memory.events max`, zero OOM, zero
  unexpected restart, and no workload regression above 10%.

### Gate 2 — partition canary

- Apply D2 to representative small, medium, and largest-observed workloads at
  session scope when the job factory supports it.
- Compare task count, bytes per task, duration, spill, GC, and output row/file
  correctness against the retained baseline.
- Globalize D2 only after the canaries pass. If session override is unavailable,
  use one maintenance rollout with the same comparisons and immediate rollback.

### Gate 3 — observability and health

- Land D3 metrics/event history and prove retained evidence across one planned
  restart.
- Land startup/readiness probes and run slow-start plus failed-readiness drills.
- Force-fire and resolve every new alert through the existing alert route.
- Decide D5 separately; it is not required to close D1–D4.

## Acceptance criteria

- Server runs only on `data-jobs`; executor runs only on `data-jobs-big`.
- Driver remains below 80% memory during a representative peak window.
- Executor cgroup limit-hit counter stays flat during the representative large
  workload; OOM and OOM-kill remain zero.
- Small shuffle stages coalesce materially below 104 tasks where data size
  permits; file stages remain at or below roughly 208 tasks unless Spark's
  suggested ceiling cannot be honored.
- No new spill; executor GC stays below 5% of run time; representative workload
  duration does not regress by more than 10% without an accepted correctness or
  stability tradeoff.
- Event history survives a planned server restart and contains stage executor
  metrics.
- Startup/readiness drills produce correct service state without a restart loop.
- Runbook records exact rollback, owner, maintenance drain, smoke query, and
  evidence locations.

## Rollback

1. Stop new Spark Connect submissions and wait for active jobs to finish.
2. Revert partition settings independently if task duration, skew, spill, or
   correctness regresses.
3. Revert server selector/resources to the previous large-node values if the
   server cannot remain scheduled or responsive on `data-jobs`.
4. Revert executor overhead and pod limit together; never leave Spark's declared
   memory sum inconsistent with Kubernetes resources.
5. Disable a faulty readiness route before removing retained metrics or event
   history.
6. Sync the prior reviewed Git revision, verify both pods become Ready, run the
   smoke query, then reopen submissions.

Rollback preserves event logs, pressure counters, and failure evidence.

## Next gate

Review the rendered `values-prd.yaml` change for D1 and D3, identify the durable
event-log destination, and schedule a drained maintenance window. Partition
settings remain a measured canary until their three workload classes pass.
