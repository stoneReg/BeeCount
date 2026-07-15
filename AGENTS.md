# AGENTS.md

## Cursor Cloud specific instructions

BeeCount is an offline-first Flutter (Dart) personal-finance app targeting Android & iOS
only (no `web/` or `linux/` desktop targets). It needs **no backend services**: data lives in
a local SQLite DB (Drift). Cloud sync / AI are optional runtime integrations configured in-app.

Standard dev/lint/test/build commands are documented in
[`docs/contributing/CONTRIBUTING_EN.md`](docs/contributing/CONTRIBUTING_EN.md) ("Common Commands").
Notes below only cover non-obvious, cloud-VM-specific caveats.

### Toolchain locations (baked into the VM snapshot)
- Flutter 3.27.3 (Dart 3.6.1) at `/opt/flutter`; on `PATH` via `~/.bashrc`.
- Android SDK at `/opt/android-sdk` (`ANDROID_SDK_ROOT`/`ANDROID_HOME` exported in `~/.bashrc`):
  platform-tools, build-tools 35.0.0, platforms android-35/36, emulator, and the
  `system-images;android-35;google_apis;x86_64` image. An AVD named `beecount_dev` is pre-created.
- Gradle/Android builds work with the VM's default JDK 21 (CI uses JDK 17, but 21 builds fine).

### Code generation is mandatory
`dart run build_runner build --delete-conflicting-outputs` MUST run after `flutter pub get`
before `flutter analyze` / `flutter test` / building — it generates the Drift DB and other
`*.g.dart`/`*.freezed.dart` files, without which the app does not compile. The update script
handles this. Re-run it manually if you change DB tables or annotated models (hot reload does
NOT regenerate them).

### Tests
- `flutter test` needs the native `libsqlite3` shared library (installed in the snapshot); the
  Drift/SQLite tests fail with `Failed to load dynamic library 'libsqlite3.so'` without it.
- Known **pre-existing** failure (not an environment issue): `test/services/billing/bill_creation_service_test.dart`
  → "AI 账户名完全相等 → 命中(限同账本币种)" throws `DuplicateNameException` because
  `LocalAccountRepository.createAccount` enforces globally-unique account names while the test
  expects same-name-per-currency. Everything else passes (~385 tests).
- `flutter analyze` exits 0 (only pre-existing info/warning lints).

### Running the app (no KVM in this VM)
There is no `/dev/kvm`, so the Android emulator must run **software-rendered** and is slow:
```
emulator -avd beecount_dev -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -no-accel -no-snapshot -memory 3072
```
First boot can take ~5 minutes; Flutter debug (JIT) first-run is heavy. Gotchas:
- Under load the emulator throws cosmetic **"System UI isn't responding"** ANR dialogs that cover
  the app (the app itself is fine). Suppress them with
  `adb shell settings put global hide_error_dialogs 1` then restart SystemUI
  (`adb shell kill $(adb shell pidof com.android.systemui)`). Also set the three
  `*_animation_scale`/`animator_duration_scale` globals to 0 to reduce load.
- Modal bottom sheets (e.g. the amount keypad) can take several seconds to render — wait before screenshotting.
- Dev-flavor debug package id is `com.tntlikely.beecount.dev.debug`; launch with
  `adb shell monkey -p com.tntlikely.beecount.dev.debug -c android.intent.category.LAUNCHER 1`.
- The emulator is headless (`-no-window`); capture UI with `adb exec-out screencap -p > out.png`.
  The device screen is 1080x2400; drive interactions with `adb shell input tap <x> <y>`
  (Flutter renders a single surface, so `uiautomator dump` does NOT expose widget text/bounds).
