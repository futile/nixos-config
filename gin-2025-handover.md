# GIN-2025 Handover

This handover captures context gathered for the request to re-run the analysis behind `GIN-2025` and prepare an `ADDR`/CR-style cleanup ticket. It is intended for another AI agent to continue from here.

## Initial Prompt

> take a look at https://jira.cfdata.org/browse/GIN-2025 - this requires a) re-running the analysis, and b) writing an ADDR ticket that will fix this. search for ADDR tickets written by me and see if you can find a previous one that I created which had similar operations. regarding a): see if you can find how/where I can re-run the analysis

Additional user hint during investigation:

> /Users/frath/repos/gfi-1617-fix-egress-pools-data might also be relevant for the analysis

## Current State

No files were modified before this handover except this handover file. Most investigation was done through Jira, GitLab, and local read-only inspection of `/Users/frath/repos/gfi-1617-fix-egress-pools-data`.

## Key Jira Tickets

- `GIN-2025`: Fix superfluous IP leases held by our Egress API.
- `GFI-1604`: Original analysis ticket, linked from `GIN-2025`.
- `ADDR-5920`: Closest ADDR-side precedent for lease mismatch cleanup.
- `CR-1375877`: Prior CR by Felix for atomic lease reassignment using Addressing bulk lease endpoint.
- `CR-1390157`: Follow-up CR by Felix for removing one wrongly assigned IPv6 from a lease.
- `CR-1071210`: ADDR example CR using `PUT /v1/leases/groups/<group>/bulk`.

## Findings From GIN-2025 And GFI-1604

`GIN-2025` summary:

- Title: `Fix superfluous IP leases held by our Egress API`
- Status at lookup time: `Needs Triage`
- Assignee/reporter: Felix Rath
- Link: `https://jira.cfdata.org/browse/GIN-2025`
- Follow-up from `GFI-1604`
- Description says `GFI-1604` found around 17 IP leases assigned to the API service that are not used in pools. These are low-criticality “memory leaks” but should be cleaned up. It also calls out one broken IP in the `nist` pool that may need deletion after checking.

`GFI-1604` comments contained the key previous analysis output:

```text
Only in pools but no existing active lease (but within our lease groups, i.e., excluding BYOIPs):

set() // empty set, aka none

Actively leased, but not in any pool:

#unused cidrs: 58
#leases with unused cidrs: 17
```

Interpretation from the comment:

- The impactful case, pool CIDRs without active leases, was empty.
- The lower-impact case is active leases not used in pools. These are dead/stale IP reservations and should be cleaned up intentionally via Addressing/CR.

Another `GFI-1604` comment found invalid geolocation issues:

```text
Leased CIDRs with invalid geolocations:

| Pool | IP version | CIDR                    | Problem             |
|------|------------|-------------------------|---------------------|
| nist | ipv4       | 104.30.132.114/32       | geolocation is null |
| nist | ipv6       | 2a09:bac0:1000:275::/64 | geolocation is null |

Total: 2 CIDRs with invalid geolocations (across 1 pool(s))
```

The affected pair was linked to Toolbox pool `59e40b00-6a91-4a97-b140-e62645f64bfe` and had status `updatingdisabled` in `den03` / `den-a`.

## Relevant GitLab MR And Scripts

`GFI-1604` points to:

- GitLab MR: `https://gitlab.cfdata.org/cloudflare/dlp/dolphin/-/merge_requests/2166`
- MR title: `Draft: GFI-1108(egress_pools): add script to find mismatched pool/leased cidrs`
- Source branch: `frath/GFI-1108-add-script-lease-mismatches`
- Project: `cloudflare/dlp/dolphin`
- State at lookup time: open draft

The MR adds these scripts:

- `scripts/find-mismatching-leased-ips-egress-pool-cidrs.py`
- `scripts/find-mismatching-geolocations-egress-pool-cidrs.py`

The lease mismatch script fetches/uses:

```text
https://dolphin-admin.cfdata.org/v1/admin/egress_pools
https://addr.cfdata.org/v1/leases/groups/d752c3d263fa4f4dbcde99918bbdde7a/leases
https://addr.cfdata.org/v1/leases/groups/d752c3d263fa4f4dbcde99918bbdde7a/cidrs
https://addr.cfdata.org/v1/leases/groups/f3fe5407562646ad95f6390289c11490/leases
https://addr.cfdata.org/v1/leases/groups/f3fe5407562646ad95f6390289c11490/cidrs
```

Lease group IDs:

- IPv4 Gateway Dedicated Egress lease group: `d752c3d263fa4f4dbcde99918bbdde7a`
- IPv6 Gateway Dedicated Egress lease group: `f3fe5407562646ad95f6390289c11490`

The script compares Dolphin egress pool CIDRs against active Addressing leases and prints:

- CIDRs only in pools but missing active leases.
- Active leased CIDRs that are not in any pool.
- Lease IDs and full lease objects for unused CIDRs.
- Summary counts.

The geolocation script reads/fetches `egress_pools.json` from Dolphin Admin and reports leased/BYOIP CIDRs whose geolocation object is missing or incomplete.

## Local Repo Found Relevant

The user pointed to:

```text
/Users/frath/repos/gfi-1617-fix-egress-pools-data
```

This repo is relevant for the broader egress pool analysis pipeline, especially broken colo analysis and migration history. It is not the exact lease mismatch script location, but it contains runbooks, cached production data, and related lessons.

Important files:

- `/Users/frath/repos/gfi-1617-fix-egress-pools-data/AGENTS.md`
- `/Users/frath/repos/gfi-1617-fix-egress-pools-data/README.md`
- `/Users/frath/repos/gfi-1617-fix-egress-pools-data/docs/analyze-broken-egress-pools.md`
- `/Users/frath/repos/gfi-1617-fix-egress-pools-data/docs/security-scoreboard-incident.md`
- `/Users/frath/repos/gfi-1617-fix-egress-pools-data/scripts/analyze-broken-egress-pools.sh`
- `/Users/frath/repos/gfi-1617-fix-egress-pools-data/egress_pools.json`

The repo’s `AGENTS.md` says the analysis pipeline is:

```text
analyze-broken-egress-pools.sh    (1. Analyze)
        ↓
  [Review recommendations]         (2. Human review)
        ↓
batch-migrate.sh                   (3. Migrate — DESTRUCTIVE)
        ↓
  [Re-fetch egress_pools.json]     (4. Refresh data)
        ↓
migration-geo-diff.py              (5. Verify)
```

Safety from that repo:

- `analyze-broken-egress-pools.sh` without `--no-fetch` is read-only but fetches production APIs.
- `analyze-broken-egress-pools.sh --no-fetch` is fully local/cached.
- `migrate-egress-ip.script.rs` and `batch-migrate.sh` without `--dry-run` are destructive and require explicit approval.

Commands to rerun the broader GFI-1617-style analysis:

```bash
cloudflared access login https://dolphin-admin.cfdata.org
cd /Users/frath/repos/gfi-1617-fix-egress-pools-data
./scripts/analyze-broken-egress-pools.sh
```

Cached/local-only iteration:

```bash
cd /Users/frath/repos/gfi-1617-fix-egress-pools-data
./scripts/analyze-broken-egress-pools.sh --no-fetch
```

That script fetches:

```text
https://dolphin-admin.cfdata.org/v1/admin/egress_pools
https://zinc-access.cfdata.org/api/v1/colos?all=true
https://toolbox-v2.cloudflareaccess.org/api/gateway/<account_id>/rules
```

Output files include:

- `egress_pools.json`
- `colos.json`
- `egress_analysis.db`
- `egress_analysis_<TIMESTAMP>.md`
- `egress_analysis_detail_<TIMESTAMP>.md`
- `migration_recommendations_<TIMESTAMP>.json`
- `broken-ips-member-policies/<account_id>.json`

Important: this analysis focuses on broken egress pool IP assignments to bad colos. For `GIN-2025`, the exact stale-lease analysis still appears to be the Dolphin MR script from MR 2166.

## Previous ADDR/CR Precedent Details

`ADDR-5920` is the key precedent. It concerned leases assigned to the wrong account and led to `CR-1375877` and `CR-1390157`.

Key ADDR guidance from `ADDR-5920` comment by David Cruz:

- Gateway team should prepare the CR because Gateway owns context, blast radius, rollback, and validation.
- Use Addressing API bulk endpoint: `https://addr.cfdata.org/api-docs?type=internal#tag/Address-Leasing/operation/bulkUpdateLeases`
- Example CR: `CR-1071210`
- Addressing can execute through Access for any lease group in emergencies or coordinated custom changes.
- CR steps should include exact operations and validation.

`CR-1071210` example used:

```bash
cloudflared access curl \
https://addr.cfdata.org/v1/leases/groups/<group_id>/bulk -XPUT \
-d '{
  "operations": [
    {
      "kind": "expire",
      "id": "<old lease id>"
    },
    {
      "kind": "create",
      "body": {
        "owner_type": "account_id",
        "owner_id": "<new owner id>",
        "cidrs": [
          "<cidr>"
        ]
      }
    }
  ]
}'
```

`CR-1375877` was created by Felix and included strong COFS/CR language:

- Blast radius: dedicated egress traffic for accounts whose leases are adjusted.
- Systems: egress routing / `oxy-egress-router`, Addressing API.
- Features: Dedicated egress, Gateway egress policies.
- Mitigation: bulk operations are atomic.
- Validation: verify active leases match expected config, monitor Grafana traffic dashboard.
- Rollback: pre-written reverse bulk operations.

`CR-1390157` is even closer to `GIN-2025` if the work is only removing stale CIDRs from an existing lease. It expired one active lease and recreated it without the bad CIDR.

## Recommended Next Steps For Next Agent

1. Materialize the Dolphin MR 2166 scripts locally, likely by checking out `cloudflare/dlp/dolphin` branch `frath/GFI-1108-add-script-lease-mismatches` or copying the scripts from GitLab.
2. Run `find-mismatching-leased-ips-egress-pool-cidrs.py` in a clean scratch directory so it fetches fresh `egress_pools.json`, `v4_leased_cidrs.json`, `v4_lease_group_cidrs.json`, `v6_leased_cidrs.json`, and `v6_lease_group_cidrs.json`.
3. Run `find-mismatching-geolocations-egress-pool-cidrs.py` to re-check the `nist` null-geolocation / `updatingdisabled` case.
4. Convert the latest stale-lease output into exact Addressing bulk operations.
5. Use the draft ADDR ticket below, but fill in exact lease IDs, owners, current CIDR sets, removed CIDRs, validation commands, and rollback commands.
6. Do not execute any Addressing bulk update without explicit user approval and CR process approval.

## Full Text Of Previous Assistant Reply

**Findings**
`GIN-2025` follows up `GFI-1604`, where the previous run found:

- `Only in pools but no existing active lease`: empty set
- `Actively leased, but not in any pool`: `58` unused CIDRs across `17` active leases
- Separate geolocation issue: `nist` had `104.30.132.114/32` and `2a09:bac0:1000:275::/64` with null geolocation and `updatingdisabled`

Relevant previous tickets:

- `ADDR-5920`: closest ADDR-side precedent for lease mismatch cleanup.
- `CR-1375877`: your previous CR for atomic lease reassignment using `bulkUpdateLeases`.
- `CR-1390157`: your follow-up CR for removing one wrongly assigned IPv6 from a lease.
- `CR-1071210`: ADDR’s original example CR using `PUT /v1/leases/groups/<group>/bulk`.

**Where To Rerun**
There are two relevant analyses:

1. Broken egress pool colo analysis:
`/Users/frath/repos/gfi-1617-fix-egress-pools-data/scripts/analyze-broken-egress-pools.sh`

Run from that repo:

```bash
cloudflared access login https://dolphin-admin.cfdata.org
cd /Users/frath/repos/gfi-1617-fix-egress-pools-data
./scripts/analyze-broken-egress-pools.sh
```

This is read-only against prod APIs but writes local outputs like `egress_analysis_<timestamp>.md`.

2. Lease mismatch analysis from `GFI-1604`:
This script is in Dolphin MR 2166, branch `frath/GFI-1108-add-script-lease-mismatches`, not in the local `gfi-1617` repo.

Relevant file:

```text
cloudflare/dlp/dolphin:scripts/find-mismatching-leased-ips-egress-pool-cidrs.py
```

It fetches:

```text
https://dolphin-admin.cfdata.org/v1/admin/egress_pools
https://addr.cfdata.org/v1/leases/groups/d752c3d263fa4f4dbcde99918bbdde7a/leases
https://addr.cfdata.org/v1/leases/groups/d752c3d263fa4f4dbcde99918bbdde7a/cidrs
https://addr.cfdata.org/v1/leases/groups/f3fe5407562646ad95f6390289c11490/leases
https://addr.cfdata.org/v1/leases/groups/f3fe5407562646ad95f6390289c11490/cidrs
```

Also rerun this related script for the `nist` null-geolocation case:

```text
cloudflare/dlp/dolphin:scripts/find-mismatching-geolocations-egress-pool-cidrs.py
```

**ADDR Ticket Draft**
Title:

```text
Clean up stale Gateway Dedicated Egress leases not referenced by egress pools
```

Description:

```text
Follow-up for GIN-2025 / GFI-1604.

We found active Addressing API leases in the Gateway Dedicated Egress lease groups whose CIDRs are no longer referenced by any Dolphin egress pool. These stale leases do not appear to be carrying customer traffic, but they reserve IPs unnecessarily and cause Dolphin / Addressing data to diverge.

Previous related cleanup work:
- ADDR-5920
- CR-1375877
- CR-1390157
- CR-1071210

Please help clean up the stale leases using the Addressing API bulk lease endpoint:

https://addr.cfdata.org/api-docs?type=internal#tag/Address-Leasing/operation/bulkUpdateLeases

Affected lease groups:
- Gateway Dedicated Egress IPv4: d752c3d263fa4f4dbcde99918bbdde7a
- Gateway Dedicated Egress IPv6: f3fe5407562646ad95f6390289c11490

Before execution:
- Re-run the lease mismatch analysis from GIN-2025 / GFI-1604.
- Confirm every CIDR being removed is actively leased but not present in any Dolphin egress pool.
- Confirm no BYOIP CIDRs are included.
- Confirm current active lease IDs and CIDR sets still match the planned operations.

Requested operation:
- For any active lease where only some CIDRs are stale, atomically expire the existing lease and create a replacement lease for the same owner with only the still-valid CIDRs.
- For any active lease where all CIDRs are stale, expire the lease.
- Use one bulk request per lease group so each group update is atomic.

Validation:
- Re-run the lease mismatch analysis after execution.
- Expected result: no active leased CIDRs outside Dolphin egress pools, or only explicitly accepted exceptions.
- Confirm Dolphin egress pool data is unchanged.
- Confirm the removed CIDRs are no longer active in Addressing API leases.

Rollback:
- If any CIDR was removed incorrectly, use the same bulk endpoint to expire the replacement lease and recreate the original lease CIDR set for the same owner.
```

**Plan To Execute After Approval**
1. Clone/fetch Dolphin MR 2166 or otherwise materialize those two scripts locally.
2. Run the lease mismatch script in a fresh working directory so it fetches current data.
3. Run the geolocation script to re-check the `nist` case.
4. Transform current output into exact `bulkUpdateLeases` JSON operations.
5. Fill the ADDR ticket with exact lease IDs, owner IDs, CIDR removals, validation commands, and rollback commands.

## Draft ADDR Ticket To Continue With

Title:

```text
Clean up stale Gateway Dedicated Egress leases not referenced by egress pools
```

Description:

```text
Follow-up for GIN-2025 / GFI-1604.

We found active Addressing API leases in the Gateway Dedicated Egress lease groups whose CIDRs are no longer referenced by any Dolphin egress pool. These stale leases do not appear to be carrying customer traffic, but they reserve IPs unnecessarily and cause Dolphin / Addressing data to diverge.

Previous related cleanup work:
- ADDR-5920
- CR-1375877
- CR-1390157
- CR-1071210

Please help clean up the stale leases using the Addressing API bulk lease endpoint:

https://addr.cfdata.org/api-docs?type=internal#tag/Address-Leasing/operation/bulkUpdateLeases

Affected lease groups:
- Gateway Dedicated Egress IPv4: d752c3d263fa4f4dbcde99918bbdde7a
- Gateway Dedicated Egress IPv6: f3fe5407562646ad95f6390289c11490

Before execution:
- Re-run the lease mismatch analysis from GIN-2025 / GFI-1604.
- Confirm every CIDR being removed is actively leased but not present in any Dolphin egress pool.
- Confirm no BYOIP CIDRs are included.
- Confirm current active lease IDs and CIDR sets still match the planned operations.

Requested operation:
- For any active lease where only some CIDRs are stale, atomically expire the existing lease and create a replacement lease for the same owner with only the still-valid CIDRs.
- For any active lease where all CIDRs are stale, expire the lease.
- Use one bulk request per lease group so each group update is atomic.

Validation:
- Re-run the lease mismatch analysis after execution.
- Expected result: no active leased CIDRs outside Dolphin egress pools, or only explicitly accepted exceptions.
- Confirm Dolphin egress pool data is unchanged.
- Confirm the removed CIDRs are no longer active in Addressing API leases.

Rollback:
- If any CIDR was removed incorrectly, use the same bulk endpoint to expire the replacement lease and recreate the original lease CIDR set for the same owner.
```

## Important Cautions

- Running analysis scripts that fetch production data is read-only but may require `cloudflared` authentication.
- Do not run Addressing API `bulk` updates without explicit user approval and a CR/ADDR execution path.
- When using `cloudflared access curl`, place `--fail-with-body` after the URL; the local runbook calls this out as important.
- If a lease must be changed, prefer Addressing bulk endpoint operations to preserve atomicity.
- Any cleanup ticket/CR should include exact rollback JSON before execution.
