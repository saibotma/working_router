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
returns. In a harness without device tools, run `simlock instructions` when
[Simlock](https://github.com/callstackincubator/simlock) is installed and follow
its rules.

## Choosing a device

- Open a device from a Simlock pool when `device_list` lists a host of kind
  `simlock`. Simlock leases each device to one thread, while the machine's local
  simulators are shared with the user and every other thread, so another agent
  can drive, reinstall, or erase the same one.
- Use a local device only when the user asks for one, no Simlock host is
  available, or the task needs a tool that cannot reach a leased device. Tell
  the user which device you use and why.
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
- Get the device's id from `session --json` of that `agent-device` call. It
  lists the sessions of every thread, so use the one whose name ends with the
  `session` that `device_open` returned: `device_udid` for an iOS simulator and
  `id`, the emulator serial, for an Android emulator. Name the device in every
  command, and never act on all devices, such as with
  `xcrun simctl shutdown all` or `adb kill-server`, because the user's and other
  threads' devices are listed beside it.
- A leased iOS simulator is in Xcode's device set when its session has no
  `ios_simulator_device_set`, so tools find it by its UDID. Otherwise it lives
  in Simlock's own device set, which tools such as `flutter attach` and
  `xcodebuild -destination id=<udid>` do not read: build for any simulator, for
  example with `xcodebuild -destination 'generic/platform=iOS Simulator'`,
  install the `.app` with `agent-device`, and go without hot reload. When the
  Simlock host runs on this machine, tell the user that step 3 of
  [Setting up Simlock](references/setting-up-simlock.md) enables hot reload.
- A leased Android emulator is attached to Simlock's own adb server, on port
  5038 unless the host changed it. Set `ANDROID_ADB_SERVER_PORT` to that port
  for tools that use adb, such as `adb logcat` and `flutter attach`.
- A freshly booted leased Android emulator can show dialogs such as "System UI
  isn't responding". Press "Wait" with `agent-device` until the app is visible
  before judging the app.
- The lease ends at the host's lease limit, even while the device is in use, and
  Simlock wipes the device. When `agent-device` reports that the device or lease
  is gone, open a device again and install the app again; do not rely on earlier
  app state.

## Closing devices

- Close every device you opened with `device_close` before reporting completion.
  Pass `shutdown: true` for leased devices, which returns them to the pool, and
  for local devices that you booted.
- Keep a device open only when the user wants to keep using it, and tell them
  that a leased device stays leased until they close it or its lease limit ends
  it.

## When opening fails

- Report the error that `device_open` returns instead of silently switching to a
  local device.
- When the Simlock host runs on this machine, `simlock status --json` lists its
  capabilities: `agent-device`, `stream`, and `input` must be `available`.
  `simlock doctor` and `simlock daemon logs` show more. Ask the user before
  changing Simlock's configuration or installing tools, because both change the
  machine for every project.
  [Setting up Simlock](references/setting-up-simlock.md) lists the steps that
  devices need.
