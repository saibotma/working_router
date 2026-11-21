---
name: github
description:
  Use when working with GitHub, including the gh CLI, issues, pull requests,
  Actions workflows and their secrets and variables, and other repository
  metadata. It is the forge skill for GitHub that the PR workflow skills name.
metadata:
  tags: github
---

# GitHub

On GitHub, a PR is a pull request, addressed by its number.

- When a task needs `gh` and it is missing or not authenticated, prompt the user
  to install it and log in before continuing.
- Read PR state with `gh pr view <number> --json <fields>`, and load lists from
  the API with full pagination, `gh api --paginate <endpoint>`.

## Merge Options

The merge methods and head-branch deletion are repository settings and rules of
the base branch, not options of a PR. The base branch allows a method when
`gh api repos/{owner}/{repo}` turns on `allow_squash_merge` or
`allow_merge_commit`, and every `pull_request` rule in
`gh api repos/{owner}/{repo}/rules/branches/<base>` lists it, as `squash` or
`merge`, in `parameters.allowed_merge_methods`. A `required_linear_history` rule
there, or `required_linear_history.enabled` in
`gh api repos/{owner}/{repo}/branches/<base>/protection`, blocks merge commits.
Report a method that a merge needs but the base branch blocks, or a
`delete_branch_on_merge` that is off, instead of changing repository settings or
rules.

## Merge

Squash by default, with
`gh pr merge <number> --squash --match-head-commit <revision>`. Use a merge
commit, with `--merge` instead of `--squash`, when the base branch allows it and
there is a reason for one: the user asks for it, or the PR brings a long-running
branch into another or syncs one with its base, whose individual commits should
stay. The command refuses when the head has moved past the revision you checked.
Do not pass `--auto`, `--admin`, or `--delete-branch`; the repository setting
deletes the head branch. On a branch with a merge queue, the queue merges with
its `merge_queue` rule's `parameters.merge_method`, whatever method you pass, so
report a method that differs from the chosen one instead of running the command.
Otherwise the command queues the PR, so report it as queued, not merged.

## Labels

Before any `gh issue` or `gh pr` call that adds or removes labels, first verify
the exact label names with `gh label list`. Replace one label of a set with, for
example,
`gh pr edit <number> --add-label "risk: red" --remove-label "risk: green,risk: yellow"`.

## Reviewers

A requested reviewer drops out of `reviewRequests` once they submit a review,
and anyone with read access can submit a review without a request. So the PR's
current reviewers are its `reviewRequests` together with the users whose latest
`review_requested` or `review_request_removed` event in
`repos/{owner}/{repo}/issues/<number>/timeline` is a request. When the timeline
does not show such a request, the user is not a current reviewer. The PR's
approval state is `reviewDecision`. GitHub does not let anyone request a review
from the PR's author, so assign the authenticated user, the `login` from
`gh api user`, with `gh pr edit <number> --add-reviewer <login>`, or with
`gh pr edit <number> --add-assignee @me` when they authored the PR.

## Feedback

Feedback comes in three kinds, and a pass loads all of them:

- Review comments on lines of the diff, from
  `repos/{owner}/{repo}/pulls/<number>/comments`. Comments that reply to the
  same first comment form a discussion; reply in it by posting to
  `repos/{owner}/{repo}/pulls/<number>/comments/<first comment id>/replies`.
  Read whether a discussion is resolved from the GraphQL `reviewThreads` of the
  PR.
- Review bodies, from `repos/{owner}/{repo}/pulls/<number>/reviews`. They take
  no replies; answer one in a conversation comment that links it.
- Conversation comments, from `repos/{owner}/{repo}/issues/<number>/comments`.
  They have no discussions; reply in a new conversation comment that links the
  comment.

Reactions on a review comment are under
`repos/{owner}/{repo}/pulls/comments/<id>/reactions`, and on a conversation
comment under `repos/{owner}/{repo}/issues/comments/<id>/reactions`. GitHub only
offers `+1`, `-1`, `laugh`, `confused`, `heart`, `hooray`, `rocket`, and `eyes`;
the approval reaction is `+1`. Read the reactions on review bodies, with their
authors, from the GraphQL `reactions` of the PR's `reviews`, and add one with
the `addReaction` mutation.

## CI

CI runs as checks, mostly from GitHub Actions workflow runs. Read the checks of
the PR's source revision with
`gh pr checks <number> --json name,state,bucket,link,workflow`, and only the
required ones with `--required`. A required check that has not reported yet is
missing, not green. Read the failed steps of a run with
`gh run view <run id> --log-failed`, and find comparable target branch runs with
`gh run list --branch <target> --workflow <workflow>`.

## Secrets and Variables

GitHub Actions masks every occurrence of a secret's value in logs, so a short or
common value stored as a secret, such as `2` or a user name, makes logs
unreadable.

- Store credentials as secrets, and everything else that configures a workflow
  as variables: hosts, ports, the user names of SSH targets, `known_hosts` lines
  with public host keys, the IDs and audiences of OIDC identities, feature IDs,
  and flags.
- Store both parts of a login as secrets, such as an access key ID together with
  its secret key, or a basic auth user name together with its password.
- Scope a deployment's secrets and variables to its environment, with a branch
  or tag policy, not to the repository: repository secrets reach every workflow
  run on any branch, including pull requests from the repository's own branches.

## Diff Links

Link a file in the PR's diff as `<PR URL>/files#diff-<hash>`. The anchor is the
SHA-256 of the file's repository-relative path, from
`printf '%s' <path> | shasum -a 256`.

## Uploads

Attach screenshots and recordings with `gh` 2.99.0 or later, which uploads them
with `--attach` on `gh pr create`, `gh pr edit`, and `gh pr comment`: an image
as `--attach '<file>#<alt text>'`, and a recording as `--attach '<file>'`,
because a video cannot have alt text. Reference each file by its local path in
the body, such as `![Login error](./login.png)`, so `gh` replaces the path with
the uploaded asset; without a reference, `gh` appends the attachment to the
body. When `gh` is older, prompt the user to update it before continuing.
