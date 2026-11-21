---
name: verification
description:
  Use before implementing a change, to plan its checks and capture what it
  changes, and after implementing it, before reporting it done or publishing a
  PR/MR, to check by using the running product that it works and to capture
  evidence for the PR description. Also use to reproduce a bug before fixing it.
---

# Verification

Before applying this skill, read its skill extension,
`.agents/skill-extensions/verification/SKILL.md`, if it exists. It adds this
project's facts and rules to this skill. If it does not exist, continue without
searching for it.

Use the product the way its users do and check that the change works, so that a
human does not have to. Verification adds to tests and does not replace them:
tests keep a behavior proven on every later change, while verification shows
that the running product works as a whole, on a real platform, and how it looks.

## Planning Checks

List the checks before you change the code, so that you can capture the states
the change replaces, as [Evidence](#evidence) describes: for each behavior the
request or issue changes, who does it, such as the account or role when the
product has several, on which surface and platform, in which
[UI setup](#ui-setups), in which state, and the expected result. Add one check
of the flow around the change, so that a break next to it shows up.

Cover each check with the first of these that fits:

1. **A test**, when a test can reasonably assert it. Write it as the `testing`
   skill describes, and do not verify it again by hand.
2. **Verification**, when it needs the running product: a real platform, a flow
   across components, or how something looks.
3. **A human**, only for taste, such as whether a new screen looks right, or for
   a check you cannot run. `pr-description` sorts these into items.

## Environment

The extension's sections say how this project runs: `Environment` names the
instances and how to start them, `Accounts and data` how to sign in and create
data, `Isolation` how to keep your instances apart from other threads',
`Safety rules` what is allowed on each instance, `Doctor` the check that an
instance is usable, and `UI setups` how this project's setups differ from
[UI Setups](#ui-setups).

- Run each check on an instance of your own: one that you start in your own
  worktree, or a deployed one that the extension's `Environment` section says
  you can create for yourself and delete again, such as a preview deployment per
  branch. There you can create exactly the data a check needs, reach every
  state, and leave nothing behind for others. Use a shared deployed instance
  only for a check that none of your own instances can run, such as one that
  needs a service only that instance reaches, and only when its safety rules
  allow the check and it leaves the instance clean.
- Create the data each check needs yourself, through the product or its API
  rather than by writing to storage directly, so that the data is valid, unless
  the extension says otherwise.
- Never drive an instance that another thread uses, such as a server in another
  worktree or a device you did not open. Give your instances their own ports,
  data directories, and databases.
- Run the doctor check before the first check and again after anything
  surprising, so that an environment failure is not mistaken for a product bug.
- When the environment fails, such as a build, a device, a server, or signing
  in, stop and report what failed with its error output. Do not repair the
  environment, such as by installing or updating tools or changing system
  settings, and do not change the product to work around it. The affected checks
  are inconclusive. Changing the display or text size of your own device or tab
  for a [UI setup](#ui-setups) is part of a check, not a repair.
- When something missing blocks a check, such as a way to run a component
  locally or to reach a state, name it under **Limitations and follow-up** in
  the PR description instead of building a workaround.

When the extension or one of its sections is missing, verify anyway. Work out
what it would say from the project's documentation, scripts, and run
configurations, such as its README, `AGENTS.md` files, and compose files. The
rules above still apply, and until the extension covers it, these as well:

- Run only instances that you start in your own worktree, never a deployed one.
- Before you start an instance, read its configuration for services that reach
  beyond this machine, such as ones that send messages, take payments, or write
  to shared storage. When starting the instance or its background jobs would use
  them, do not start it; otherwise leave out the checks that would. The checks
  you leave out are inconclusive.
- Name under **Limitations and follow-up** that the extension or section is
  missing, with the facts you had to work out, so that someone can add them.

## Surfaces

- **Mobile apps:** on a simulator or emulator, as the `simulators` skill
  describes.
- **Web:** in T3 Code's browser preview through the `preview_*` tools. Verifying
  with this skill is a request for browser work, so use them without asking.
  Open your own tab with the `incognito` profile, never the user's profile, and
  close it when you are done. The incognito tabs of all threads share one cookie
  jar and share storage per origin, so serve the app on a port no other thread
  uses. A port of its own does not keep cookies apart: when the app or its API
  keeps the session in cookies, another thread's sign-in or sign-out can change
  your session. On a shared deployed instance, sign in only when the extension's
  `Isolation` section shows that it cannot, such as because the session cookies
  are set per host or per session; otherwise the checks that sign in are
  inconclusive. On your own instances, sign in, and confirm the signed-in
  account before and after each check that depends on it; when the account
  changed or the session ended, the check is inconclusive, so run it once more.
  Size the tab with `preview_resize` for each width the change affects and for
  the [UI setups](#ui-setups). With Flutter web, start the app with
  `fvm flutter run -d web-server`. Its accessibility tree stays empty until the
  app turns on semantics, so start it with the entry file that the extension's
  `Environment` section names, such as one that calls
  `SemanticsBinding.instance.ensureSemantics()` before it runs the app. Without
  such an entry file, drive the app by coordinates from screenshots, and name
  the missing entry file under **Limitations and follow-up**.
- **APIs:** send real requests to the running instance, and keep the request and
  the response.
- **CLIs, jobs, and scripts:** run them as a user or the scheduler would, and
  keep the output, the exit code, and the side effects.
- **Messages,** such as emails and push notifications: capture them where the
  extension says they arrive, and never send them to real people.

## UI Setups

Check a change to UI in two setups, unless the extension's `UI setups` section
changes them, such as for an app that caps its text size or runs only on
tablets:

- **Default:** a common phone, or the widths the change targets, such as a
  desktop browser, at the default text size. Run every check here.
- **Narrow with large text:** a window 320 wide, in points on iOS, dp on
  Android, and CSS pixels on the web, with text about 1.5 times the default
  size. Users reach it on current phones by enlarging the display and the text,
  and it puts about as much pressure on a layout as twice the default text on a
  common phone. On iOS, use Display Zoom and the text size AX1; on Android, a
  display size that makes the screen 320 dp wide and the font scale 1.5; on the
  web, a tab 320 pixels wide, which is what browser zoom does to a page, and the
  browser's font size at 150%. `simulators` says how to set them on a device.
  The browser preview has no font size setting, so after each page load, set the
  font size of the page's root element to 1.5 times its computed size with
  `preview_evaluate`, which is what the browser setting does. It stands in for
  that setting and does not count as changing the product. When the app sets the
  root font size in pixels, the browser setting has no effect, so leave the font
  size and say so in the check. Media queries in `em` or `rem` still use the
  browser's default size, not the page's, so when the app's breakpoints use
  them, the page may show another layout than the browser setting would; say so
  in the check.

In the narrow setup with large text, open each screen and state that the change
adds or changes, check that nothing in it overlaps, is cut off, or cannot be
reached, such as behind the keyboard, and capture it. Run flows and other
behavior only in the default setup.

- A break in what the change adds or changes is a defect, as [Judging](#judging)
  describes. When the layout needs a choice in this setup, such as wrapping or
  truncating a title, or stacking buttons that sit side by side by default, make
  it, and `pr-description` shows it for a human to judge.
- A break in what the change does not touch is not part of the change. Name it
  under **Limitations and follow-up** in the PR description instead of fixing
  it.

## Proof Standards

- Use the path a user takes, not internal setters, test-only endpoints, or
  shortcuts that skip what the change affects.
- Check the result, not a status message: reopen saved data, read back written
  values, and check side effects such as rows, files, or sent messages next to
  what is visible.
- Do not force a state by changing the product or its data behind its back.
  Inspecting state may confirm what you observed, but not create it. A state you
  cannot reach is inconclusive.
- Use mocks only where a production boundary already separates an external
  system.
- Do not trust a dry run or test mode by its name; observe what it skips.
- For a bug fix, reproduce the bug before you change the code, then show that it
  is gone. Without a reproduction, do not claim that the fix works.

## Judging

Each check passes, fails, or is inconclusive, with what you observed. Keep the
checks with their results, observations, and captures as the verification
record, which `pr-description` and its reviewer use.

- A failure caused by the change is a defect. When a test can reasonably
  reproduce it, write the failing test first, then fix the defect and run the
  check again.
- An inconclusive check states what could not be observed and why. It goes to a
  human, as `pr-description` describes.
- When nothing could be verified, such as because the product did not start,
  every planned check that needs the running product is inconclusive. List each
  one with what blocked it, and name the blocker under **Limitations and
  follow-up**. A single "not verified" line does not replace them.

## Evidence

Capture what a human would otherwise have to check or try, and what shows them
the change:

- screenshots of each changed state, and short recordings of flows and
  animations;
- for changed existing UI and for bug fixes, the same state before the change,
  captured before you change the code, so that the human can compare, in the
  default setup unless the change fixes a break in the narrow setup with large
  text;
- for other surfaces, the request and response, the command output, or the
  rendered message.

Caption each capture with what it shows: the state, the account or role when the
product has several, the platform, and the size and text size, such as
`iPhone, 320×693, AX1`. Leave out unchanged screens and captures that show the
same thing as another. Before you share or upload a capture, remove secrets,
such as passwords, tokens, cookies, and authorization headers, and data of real
people from it. `pr-description` says where each capture goes in the
description; upload them as the forge skill's `Uploads` describes.

Evidence holds for the revision it was captured on. When a later change, such as
a review fix or an addressed comment, affects a verified behavior, run its
checks again and replace their evidence.

## Cleanup

Stop what you started and nothing else: close devices as `simulators` describes
and preview tabs you opened, sign out, stop servers, delete deployed instances
you created unless the extension says to keep them, remove data you created on
shared instances, and delete local captures once they are uploaded.
