---
name: simulators
description:
  Use when running, inspecting, or testing an app on an iOS Simulator or Android
  Emulator, including choosing, opening, driving, and closing a device.
metadata:
  tags: mobile
---

# Simulators

Use simulators and emulators through the agent harness's device tools, such as
T3 Code's `device_list`, `device_open`, `device_screenshot`, and `device_close`,
and drive an open device with the `agent-device` command that `device_open`
returns. Leased devices come from
[Simlock](https://github.com/callstackincubator/simlock) 0.7 or newer.

## Choosing a device

- Call `device_list` without a `hostId`, so it lists every host, and open a
  device from a Simlock pool when it lists a host of kind `simlock`. Simlock
  leases each device to one thread, while the machine's local simulators are
  shared with the user and every other thread, so another agent can drive,
  reinstall, or erase the same one.
- Use a local device only when the user asks for one, `device_list` lists no
  Simlock host, or the task needs a tool that cannot reach a leased device. A
  Simlock device that fails to open is no reason, and neither is a brief or
  another agent that names a local device. Tell the user which device you use
  and why.
- Open only a local device that `device_list` shows as not booted. A booted one
  may belong to the user or another thread. This way, you booted every local
  device you open, and it is yours to shut down.
- Take device ids from `device_list` instead of guessing them. Pick the model
  and OS version that the task needs, or a current phone of the platform when it
  needs none.

## Leased devices

- A leased device starts without the app. Build it for a simulator or emulator
  and install it with the `install` command of the `agent-device` call that
  `device_open` returns, run from the thread's working directory. This works for
  every Simlock host, including one on another machine.
- Launch and relaunch the app only with `agent-device`, such as
  `open <app> --relaunch`, because the harness requires it for every launch.
- Get the device's id from `boot --json` of that `agent-device` call, which
  answers for your leased device only: `data.id` is the UDID of an iOS simulator
  and the serial of an Android emulator. Name the device in every command, and
  never act on all devices, such as with `xcrun simctl shutdown all` or
  `adb kill-server`, because the user's and other threads' devices are listed
  beside it.
- For hot reload, when the Simlock host runs on this machine, attach the
  project's development tool to the app that `agent-device` launched instead of
  letting the tool launch it. Give the tool the exact address of the app on your
  device, because another thread may run the same app on its own device. A
  relaunch starts a new app process with the code the app was built with and
  ends the attachment, so attach again after every relaunch. With Flutter:
  1. Launch the app and read its address from the newest
     `Dart VM service is listening on` line of the device log: on iOS with
     `xcrun simctl spawn <udid> log show --last 2m --predicate 'eventMessage CONTAINS "Dart VM service is listening"'`,
     and on Android with `adb -s <serial> logcat -d`.
  2. Start `flutter attach -d <id> --debug-url <address> --pid-file <file>` in
     the background with its input kept open, such as by piping
     `tail -f /dev/null` into it, and stop both when you are done.
  3. Hot restart once with `kill -USR2 <pid>`, so the app runs your current
     code, including edits made before attaching. Then hot reload with
     `kill -USR1 <pid>` after each edit, and check attach's output for the
     result. Without the hot restart, the first hot reload of an app built with
     `flutter build ios --simulator --debug` fails with
     `Lookup failed: _location`.
     <!-- TODO(saibotma): Remove once https://github.com/flutter/flutter/issues/195792 is fixed or released. https://linear.app/appella/issue/APL-510 -->
- A leased iOS simulator is in Xcode's device set when
  `xcrun simctl list devices` lists its UDID, so tools find it by that UDID.
  Otherwise it lives in Simlock's own device set, which tools such as
  `flutter attach` and `xcodebuild -destination id=<udid>` do not read: build
  for any simulator, for example with
  `xcodebuild -destination 'generic/platform=iOS Simulator'`, install the `.app`
  with `agent-device`, and go without hot reload. When the Simlock host runs on
  this machine, tell the user that step 3 of
  [Setting up Simlock](references/setting-up-simlock.md) enables hot reload.
- A leased Android emulator is attached to Simlock's own adb server, on port
  5038 unless the host changed it. Set `ANDROID_ADB_SERVER_PORT` to that port
  for tools that use adb, such as `adb logcat` and `flutter attach`.
- A freshly booted leased Android emulator can show dialogs such as "System UI
  isn't responding". Press "Wait" with `agent-device` until the app is visible
  before judging the app.
- The lease ends at the host's lease limit, even while the device is in use, and
  Simlock deletes the device. When `agent-device` reports
  `lease ended by simlock`, close the device with `device_close` and
  `shutdown: true`, open a pool device from `device_list` again, and install the
  app again; do not rely on earlier app state.
- A restart of `agent-device` or Simlock keeps the lease and its apps. When a
  command then answers `SESSION_NOT_FOUND` or `AMBIGUOUS_MATCH`, run
  `open <app>` again, which opens it on your leased device, and never pick a
  device from the list such an error shows.

## Display and text size

Set up the narrow setup with large text that `verification` describes on the
device, and relaunch the app with `agent-device` after each change, because it
picks up a new size only then.

- **Text size:** `agent-device settings text-size accessibility-medium`, which
  is AX1 on iOS and the font scale 1.5 on Android, and
  `agent-device settings text-size large` to return to the default.
- **iOS display:** pick a phone that Display Zoom makes 320 points wide, such as
  a current base or Pro model, because Max and Air models zoom only to 375. Set
  Display Zoom to Larger Text in the Settings app with `agent-device`, under
  Appearance or Display & Brightness, and confirm the restart that it asks for.
- **Android display:** `agent-device` cannot change the display size, so set the
  density with `adb -s <serial> shell wm density <dpi>`, with `<dpi>` as half
  the short side in pixels that `wm size` reports, which makes it 320 dp, and
  return to the default with `wm density reset`.
- Confirm the width from the frame of the app's root element in
  `agent-device snapshot --json`. On iOS, the frame is in points. On Android, it
  is in pixels, so divide it by the density that `wm density` reports and
  multiply it by 160 to get dp.
- Before you close a local device, return what you changed to the default,
  because a local device keeps its settings. A leased device is wiped when it
  returns to the pool.

## Closing devices

- Close every device you opened with `device_close` as soon as you no longer
  need it, and at the latest before you report back, also when the work failed
  or stopped early. Pass `shutdown: true` for every device: it returns a leased
  device to the pool and shuts down a local one, which you booted.
- When `agent-device` reports `DEVICE_IN_USE` for a local device that you just
  opened, another session holds it, and you cannot tell whether that session is
  still in use. Close the device without `shutdown`, open another one, and tell
  the user the held device's name, id, and session, because `device_open` may
  have booted it and left it running for nobody.
- Keep a device open only when the user wants to keep using it, and tell them
  that a leased device stays leased until they close it or its lease limit ends
  it.

## When opening fails

- When a Simlock device fails to open, follow the advice of the error that
  `device_open` returns once, such as by opening another Simlock device. If that
  fails too, report the error and treat the checks that need the device as
  inconclusive instead of switching to a local device.
- When the Simlock host runs on this machine, `simlock status --json` lists its
  capabilities: `agent-device`, `stream`, and `input` must be `available`.
  `simlock doctor` and `simlock daemon logs` show more. Ask the user before
  changing Simlock's configuration or installing tools, because both change the
  machine for every project.
  [Setting up Simlock](references/setting-up-simlock.md) lists the steps that
  devices need.
