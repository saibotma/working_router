# Sizing Changes

Plan a change as one or more PRs, each a coherent behavior that a reviewer can
understand on its own. Small PRs are easier to judge, revert, and merge.

These are guidelines, not limits. Split only when the parts are easier to
understand, review, or revert separately; never split just to meet a number, and
keep one PR when splitting would scatter a change that belongs together.

## Size

As a rough orientation, aim for at most about 400 review-relevant changed lines.
Generated files, lockfiles, snapshots, and purely mechanical output do not
count; state them separately in the description. Above about 1000
review-relevant lines, check whether the change has parts that stand on their
own.

## Splitting

Good places to split, when they make the change easier to follow:

- refactoring and behavior changes;
- generated and handwritten changes;
- schema preparation, data migration, and cleanup;
- a server capability and its use in the client;
- mechanical renames and content changes.

When you split, this order usually works:

1. introduce or clarify a tested abstraction;
2. add the new behavior behind the existing contract;
3. connect it to callers or the UI;
4. migrate consumers or data;
5. remove the old path.

A split PR may depend on an earlier one. Each step needs an understandable goal,
but not every intermediate step has to deliver customer value.

## Keeping `main` Releasable

Merge each step into `main` once its intermediate state is safe, because `main`
must stay releasable after every merge. An unfinished feature may land on `main`
only while it stays inactive for users and existing workflows, for example as a
capability that nothing uses yet or a backward-compatible preparation step, and
it must not cause side effects such as background jobs, events, or changed write
paths. Each step must also stay backward compatible with deployed clients and
existing data and be tested and revertible on its own.

When a step cannot land safely on `main`, use the first option that works:

1. Make it safe, for example through an abstraction or a backward-compatible
   preparation step.
2. Stack PRs: the next PR targets the previous PR's branch and merges after it.
3. As an exception, collect reviewed PRs in a short-lived feature branch based
   on `main`. Integrate `main` regularly, and keep the final PR into `main` an
   integration check of conflict resolutions and new changes, not a second full
   review.
