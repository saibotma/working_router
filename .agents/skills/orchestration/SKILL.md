---
name: orchestration
description:
  Use when orchestrating other agents, including delegating tasks, answering a
  delegated agent's questions, and reporting delegated work to the user.
---

# Orchestration

A delegated agent cannot tell your answers to its questions from the user's, so
it may record them as the user's decisions, for example as settled points in a
PR description. Only the user's own decisions settle a point, so keep the two
apart:

- When you answer a delegated agent's question yourself, say in the answer that
  it is your decision, not the user's, such as "Orchestrator decision, not the
  user's".
- When you pass on a decision of the user, quote the user's words and name where
  they wrote them, such as your T3 Code thread ID, so the delegated agent and
  its reviewers can check the source. Leave how to record the decision to the
  skills, such as `pr-description`; never tell the delegated agent to ask the
  user to confirm it again.
- When reporting to the user, keep the user's decisions apart from your own.

## Briefs

A delegated agent follows its brief over its skills, so a brief can drop steps
that the skills require without anyone deciding to.

- Do not narrow in a brief what a task needs before it counts as done, such as
  by listing only tests and a green pipeline. Name the skills that define done
  instead, such as `prepare-pr` and `verification`.
- When a delegated agent asks to skip a step that a skill requires, such as a
  check from `verification` or its evidence, answer with that skill's rule. Only
  the user can waive it, so ask the user instead of deciding yourself.
- When you pass a delegated agent a device, choose it as `simulators` describes,
  such as from a Simlock pool. When its devices fail, ask the user instead of
  pointing it to a device that `simulators` would not let it choose itself, such
  as a local simulator.
