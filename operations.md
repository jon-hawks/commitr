# Operations notes

## Google Cloud cleanup — 2026-10-20

Status: completed and verified on 2026-10-20. All seven actions were approved.
Five APIs were disabled; the main BigQuery API was retained because GKE depends
on it. The original application pod remained running with zero restarts.

The owner approved actions A1–A7 from the cleanup review. The intended deployment
is one GKE cluster (`default`) in `us-central1-a`, with one node pool (`main`) and
one Spot `e2-medium` node in project `default-4`. Preserve that topology.

The registry had **1,155 image manifests** accumulated since 2023, although its
reported shared-layer storage was only about 90.8 MB. The cleanup deleted
**1,152 old manifests**, retaining the current image and two rollback images.
Kubernetes had ten old application ReplicaSets; eight were removed by reducing
`spec.revisionHistoryLimit` to two. The deployment manifest now records that limit.

The three protected image digests are:

| Purpose | Commit tag | Digest |
| --- | --- | --- |
| Current at cleanup | `494811f65f3262ef86ca6f1da63dfbb1203a00da` | `sha256:56485d213f63cf8616a0ce61e0a511d2685da31124fbaf971b01726cf1639b47` |
| Previous revision | `ba5e686316c4fb506cb6e63405544672c9c8c57c` | `sha256:fdf44bd663a3bdda576722c5c583edc1aa13e363cf6d6251f0f555a7652f4455` |
| Second previous revision | `821f584712b7b0db5f80a07412f306e0b2960fa0` | `sha256:cc3d69689a87d91b73960a3df75914550626ea2cd6c6b046e68478722ef5a857` |

Images live under `us-central1-docker.pkg.dev/default-4/default/default`.
These are historical cleanup references, not permanent deployment pins.

Other completed changes:

- Restricted GitHub federation to repository ID `599022694` and owner ID
  `17555162`; removed the wildcard pool-wide impersonation grant and retained
  the repository-specific grant.
- Removed `default-allow-rdp`, `default-allow-internal`, `default-allow-ssh`, and
  `default-allow-icmp`. Direct Internet SSH/ping to the node is no longer allowed.
  Preserved all four GKE-managed firewall rules.
- Deleted four unused `container-analysis-{notes,occurrences}-{v1,v1beta1}`
  Pub/Sub topics after confirming they had no subscribers.
- Converted the default VPC to custom subnet mode and deleted 44 unused regional
  subnets. Only `us-central1/default` remains, with the GKE Pod/Service ranges.
  Auto-to-custom conversion cannot be reversed.
- Disabled `bigquerymigration.googleapis.com`, `bigquerystorage.googleapis.com`,
  `dns.googleapis.com`, `gkebackup.googleapis.com`, and
  `networkconnectivity.googleapis.com`.
- **Kept `bigquery.googleapis.com`: Google rejected disabling it because
  `container.googleapis.com` depends on it. Never force-disable this dependency
  while keeping GKE.**

Final checks confirmed one Ready node, one available application replica, the
same pod with zero restarts, three retained images, three application ReplicaSets,
one subnet, four required routes, and four GKE-managed firewall rules.
GitHub authentication was checked by inspecting its configuration; no deployment
workflow was triggered as an end-to-end authentication test.

Detailed inventory, approved target lists, and execution evidence are stored on
the administration VM at:

```text
~/Downloads/conall.hawks/gcp-audit-2026-10-20/
```

## Follow-up: automate artifact cleanup

**Open task:** add a cleanup mechanism to the deployment pipeline, or a carefully
configured Artifact Registry cleanup policy, so old images do not accumulate
again. This cleanup does not install an automatic registry deletion policy.

Requirements for that follow-up:

- Run cleanup only after a successful rollout; retain the deployed digest and at
  least two known-good rollback versions.
- Resolve live workloads and retained ReplicaSets to digests before deletion.
  “Keep the newest three uploads” is insufficient: newer builds may never have
  been deployed successfully.
- Protect manifests referenced by image indexes, plus any explicitly pinned
  release artifacts. Restrict cleanup to this application's repository/package.
- Start with a dry run and review its exact candidates. Use an age grace period
  and prevent concurrent deployments from racing cleanup.
- Record what was deleted and retained. Keep `revisionHistoryLimit: 2` in the
  Kubernetes manifest so revision retention remains consistent.
- Keep GKE-owned resources and IAM service agents outside artifact cleanup.

The workflow variable names have been aligned. Automatic artifact cleanup
remains a separate open task. Do not trigger the Git-writing application merely
to test cleanup.

References: [Artifact Registry cleanup policies](https://docs.cloud.google.com/artifact-registry/docs/repositories/cleanup-policy)
and [Kubernetes deployment history](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#clean-up-policy).
