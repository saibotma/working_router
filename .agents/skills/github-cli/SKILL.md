---
name: github-cli
description:
  Use when working with GitHub via the gh CLI for issues, pull requests,
  Actions, or other repository metadata. It is the forge CLI skill for GitHub
  that the PR workflow skills name.
---

# GitHub CLI

On GitHub, a PR is a pull request, addressed by its number.

- If `gh` is missing or not authenticated, prompt the user to install it and log
  in before continuing.
- Read PR state with `gh pr view <number> --json <fields>`, and load lists from
  the API with full pagination, `gh api --paginate <endpoint>`.

## Merge Options

Squash merging and head-branch deletion are repository settings, not options of
a PR. Check `allow_squash_merge` and `delete_branch_on_merge` from
`gh api repos/{owner}/{repo}` and report either one that is off instead of
changing repository settings.

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
