# Setting up Simlock

Use these steps when the user asks to set up
[Simlock](https://github.com/callstackincubator/simlock) on a Mac, or when a
check in the simulators skill points to a missing step. Each step changes the
machine for every project, so show the user the steps you plan to run and run
them only after they agree.

1. Install Simlock 0.7 or newer and `agent-device` 0.21.28 or newer globally,
   such as with `npm i -g simlock agent-device`. Simlock runs `agent-device`
   from `PATH`, and opening a device fails without it. Update an installed
   Simlock with `simlock update`, which waits until no device is leased,
   installs the newest release, and restarts Simlock.
2. Turn on the capabilities that harnesses need to drive and show a device:

   ```sh
   simlock --local config set capabilities.agent-device.enabled true
   simlock --local config set capabilities.stream.enabled true
   simlock --local config set capabilities.input.enabled true
   ```

3. Keep leased iOS simulators in Xcode's own device set with
   `simlock config set drivers.ios.deviceSet default`. Otherwise Simlock keeps
   them in a device set of its own that development tools such as
   `flutter attach` and `xcodebuild -destination id=<udid>` do not read, and
   agents get no hot reload. Tell the user that leased simulators then appear in
   Xcode and in their own simulator lists, and that commands such as
   `xcrun simctl shutdown all` also stop them. Switch only while no agent uses a
   device, and remove Simlock's own simulators first, as Simlock's
   [Switch the device set](https://callstackincubator.github.io/simlock/docs/using-devices/build-and-run/#switch-the-device-set)
   describes.
4. Keep Simlock's warm pool on a machine that only runs agents. It keeps booted
   devices ready for the models agents lease, so a lease starts faster. Turn it
   off with `simlock config set warmPool.enabled false` on a machine that
   someone also works on, such as a laptop, because each warm device costs
   memory and disk while nobody uses it. Ask the user which kind of machine it
   is when you can't tell.
5. Start Simlock at login with `simlock daemon install`. Harnesses that connect
   over HTTP, such as T3 Code, can't start it themselves and find no devices
   after a reboot otherwise. The launch agent keeps the Node path from when it
   was installed, so run the command again after switching Node versions.
6. Restart Simlock with `simlock daemon stop` and `simlock daemon start` after
   changing its configuration or the Android SDK, because it reads both only at
   startup. Check with `simlock status --json` that `agent-device`, `stream`,
   and `input` are `available`, and with `simlock doctor`.
7. Connect the harness. For T3 Code, create a token with
   `simlock token create --role agent --label t3code`, turn on Settings → Labs →
   Simlock, and add a Simlock pool in Settings → Devices with the worker URL,
   `http://127.0.0.1:4701` unless Simlock's `http.port` was changed, and the
   token's `secret`. Let the user choose "Devices at once" and "Lease minutes":
   Simlock queues leases that the Mac can't run, and the lease limit ends a
   lease even while an agent uses it.
