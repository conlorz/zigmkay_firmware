# Durable milestone handovers

Each milestone has a prepared handover file linked from the
[central tracker](../TRACKING.md). They are currently **not produced**. These
files state required outputs and consumers; they do not certify implementation.
The [workflow](../SUBAGENT-WORKFLOW.md) defines who may write and accept them.

## Required completion fields

Fill these fields when submitting a checkpoint; never replace pending evidence
with an assumption:

- Producer task/agent, base revision, exact changed paths, implementation commit
  IDs after integration, contract revision/version, and coordinator review date.
- Required inputs actually consumed, links to accepted upstream handovers, and
  deliverables/entry points with concrete source/document/artifact paths.
- Frozen public API/wire/schema/identity decisions and instructions for consumers,
  including resource bounds, error semantics, and compatibility behavior.
- Exact check commands, results, relevant fixtures, and the revision/tree checked.
  Distinguish worker-scoped checks from coordinator integrated checks.
- Manual evidence, if applicable: environment, artifact hashes, worksheet rows,
  actual result, and pending checks. Never label compilation as hardware success.
- Remaining limitations, failures, decisions, downstream gates released, and
  dependencies still pending. State explicitly what is outside this handover.
- Ownership released or transferred, follow-up owner, and next concrete action.

Workers draft results; the coordinator finalizes commit references and accepts
the handover. Downstream agents read the accepted file and source at its stated
revision rather than reconstructing the interface from chat summaries. Reference
actual paths/commands after implementation; proposed names are not executable.

## State and amendments

Use `Not produced`, `Draft`, `Submitted`, `Accepted`, or `Superseded` for each
handover or partial section. `Accepted` requires integrated evidence and an
explicit coordinator decision. Accepted partial 07A/08A/09A sections do not
accept their parent milestone.

Record changes to accepted contracts with a dated amendment: old/new revision,
reason, affected consumers, required retests, and the new accepted state. Update
the tracker and consumer assignments together. Preserve useful historical evidence.

## Result template

```markdown
## Integrated result

State: Draft / Submitted / Accepted (choose the actual state).
Producer and reviewer: ...
Base and code commits: ...
Contract/version: ...
Accepted upstream inputs: ...
Changed paths and concrete entry points: ...

## Consumer instructions

Frozen interface, limits, identity, errors, compatibility, example usage: ...
Required integration/build steps: ...

## Verification and remaining gates

Commands and actual results at the stated revision: ...
Manual evidence: not applicable / actual worksheet / pending rows.
Limitations and decisions still pending: ...
Tracker gates released: ...
Ownership transfer and next action: ...
```

Keep results concise and link detailed specifications/worksheets instead of
copying them. Artifacts stay in build outputs; commit bounded sanitized fixtures
only when needed for reproducible tests, never personal typing logs.
