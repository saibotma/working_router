---
name: git
description:
  Use when working with git, including branches, worktrees, commits, merges,
  pushes, and history management.
---

- Never use `git -C` when a simple `git` also works, because you are already in
  the correct directory
- `main` is reserved for the main checkout of the repository. Never check it out
  in a linked worktree, because that blocks the main checkout from switching to
  it.
- Create and enter worktrees only with T3 Code's tools: move the current thread
  into a new worktree with `t3_worktree_handoff`, and start a new thread in one
  with `t3_thread_launch` and `workspaceStrategy`. Never manage worktrees with
  `git worktree` or an agent's own worktree tools, such as Claude Code's
  `EnterWorktree`. T3 Code does not know about such a worktree: no thread is
  bound to it, and the project's setup does not run in it.
- When committing a squash merge, use a normal commit message that summarizes
  the squashed commits. Do not mention that the commit is a squash.
- Prefer a separate follow-up commit for review fixes or later changes. Amend
  only when the change is truly forgotten content from the original commit, not
  when it is a distinct fix discovered afterward.
- Before merging another branch into a local branch that may already exist
  remotely, fetch and update the local target branch from its remote counterpart
  first. This avoids creating a local merge on stale branch state and then
  discovering non-fast-forward push conflicts afterward.
