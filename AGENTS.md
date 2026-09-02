# Feature delivery policy

## Bound one outcome before editing

Before any implementation edit, record one independently reviewable feature outcome, its acceptance criteria, affected dbt graph, required artifacts, explicit non-goals, and intended pull-request base.

Limit research and planning to evidence needed for that outcome and graph. Record adjacent discoveries as follow-ups; do not expand the current scope. If a separately deliverable prerequisite or second outcome is required, stop.

Each feature branch and opened pull request must contain exactly one behavior or data-contract outcome. An umbrella migration or cutover is not one feature merely because it deploys atomically. Exclude adjacent features, opportunistic refactors, unrelated cleanup, dependency upgrades, and broad migrations.

Keep one dbt feature's SQL, paired YAML documentation and tests, required generic or singular tests, and necessary source YAML together. Do not omit or separate these artifacts to satisfy a diff gate.

## Start from a verified base

Before the first edit, identify and verify the exact intended PR-base commit, fetching when permitted. Create the dedicated feature branch directly from that commit, not from an unverified local `main` or `trunk`. Do not implement on `main` or `trunk`.

Do not carry unrelated working-tree changes or commits onto the branch. Verify that its initial PR diff contains no pre-existing commits or file changes. On resumed work, verify that every existing branch change belongs to the recorded outcome. Stop if the base or isolation cannot be verified.

## Apply projected and actual diff gates

Measure the complete prospective PR diff from the verified base, including committed, staged, unstaged, and intended untracked files. Count every addition and deletion with rename detection disabled, and classify each changed line exactly once:

- `L`: authored semantic changes, including SQL, code, configuration, documentation, tests, generator logic, and authored or selectively modified data.
- `G`: output reproducible from a named source and command without hand-selected output edits.
- `M`: formatting, rename, reorder, or other declared transformations with no behavior or meaning change.
- `T = L + G + M`.

Count mixed or uncertain lines as `L`. Report `L`, `G`, `M`, and `T` separately. Generated or mechanical volume never changes the one-outcome rule or hides semantic scope.

Record projected counts before editing. Record actual counts before every commit and again before push or PR creation.

| Gate | Mandatory requester review | Stop |
| --- | --- | --- |
| Projected | `1,000 <= L < 1,500` or `2,000 <= T < 3,000` | `L >= 1,500` or `T >= 3,000` |
| Actual | `1,000 <= L < 1,500` or `2,000 <= T < 3,000` | `L >= 1,500` or `T >= 3,000` |

At a review threshold, pause and present the counts, affected artifacts, and one-outcome rationale for explicit confirmation. Confirmation applies only to that gate and does not authorize implementation or publication.

Stop thresholds have no standing exception. Narrow or defer the outcome without separating required atomic dbt artifacts. If no compliant atomic scope exists, report the work blocked.

## Validate and deliver

Before push or PR creation, run and report the minimum focused validation for the affected dbt graph:

1. Run `dbt parse`.
2. Use `dbt ls --select "<changed-nodes>" --output name` to verify the intended selector.
3. Run `dbt build --select "<changed-nodes>"` to build the changed nodes and execute their selected tests.

Before the first warehouse command in a stable session, confirm that the resolved target is a development database and schema. Reuse that confirmation while the session, profile, and target environment remain unchanged.

Expand validation only when the change requires it: include missing parents, include bounded descendants for interface changes, use `dbt show` or profiling for semantic assumptions not covered by tests, and inspect logs or compiled artifacts after a failure. A semantic change after successful validation requires rerunning the affected checks. Stop on a failing required check. If a prerequisite is unavailable, run the available checks and report the exact blocker without claiming success.

For explicitly authorized repository implementation, commit on the dedicated branch, push only that branch, and open one pull request against the verified base when Git, remotes, authentication, and PR tooling permit. Multiple focused commits are allowed. Report the exact blocker for any unavailable delivery step. Never merge or enable auto-merge.

Planning, review, or documentation-only work does not by itself authorize edits, commits, pushes, or pull requests.
