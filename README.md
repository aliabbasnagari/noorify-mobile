# Noorify

A Subsonic / OpenSubsonic music player built with Flutter, inspired by the feature set of Symfonium.

Runs on Android, iOS, macOS, Windows and Linux.

## Development

Requirements: Flutter 3.41+ (stable) with the toolchain for your target platform.

```sh
flutter pub get
flutter run                # pick a device/desktop target
flutter test               # run the test suite
```

The Drift database code (`lib/data/local/app_database.g.dart`) is committed. If you change the schema in `app_database.dart`, regenerate it:

```sh
dart run build_runner build --delete-conflicting-outputs
```

### Project layout

| Path | Contents |
|---|---|
| `lib/subsonic/` | Subsonic / OpenSubsonic API client |
| `lib/data/local/` | Drift (SQLite) database |
| `lib/state/` | Controllers (player, session, settings, downloads, sync) |
| `lib/audio/` | ReplayGain, equalizer presets |
| `lib/smart/` | Smart-playlist filter engine |
| `lib/ui/` | Pages and widgets |
| `test/` | Unit and widget tests |
| `packaging/windows/` | Inno Setup script for the Windows installer |

## Releases

Releases are built and published by [`.github/workflows/pipeline.yml`](.github/workflows/pipeline.yml) whenever a version tag is pushed:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The pipeline:

1. **Test** — runs `flutter test`.
2. **Build** — if tests pass, builds all platforms in parallel.
3. **Release** — if every build passes, creates a GitHub Release for the tag and attaches the artifacts.

If any stage fails, nothing is published. Tags containing a hyphen (e.g. `v0.2.0-beta.1`) are marked as pre-releases. The tag (minus the leading `v`) becomes the app version name, and the workflow run number becomes the build number.

### Artifacts

| Platform | File | Notes |
|---|---|---|
| Android | `noorify-<tag>-android.apk` | Signed with the debug key (see below) |
| iOS | `noorify-<tag>-ios-unsigned.ipa` | Unsigned; re-sign or sideload to install |
| macOS | `noorify-<tag>-macos.dmg` | Not notarized; right-click → Open on first launch |
| Windows | `noorify-<tag>-windows-setup.exe` | Installer |
| Windows | `noorify-<tag>-windows-portable.zip` | Extract and run `noorify.exe` |
| Linux | `noorify-<tag>-linux-x86_64.AppImage` | `chmod +x` then run |
| Linux | `noorify-<tag>-linux-x64.tar.gz` | Extract and run `./noorify` |

### Known limitations

- **Android** release builds currently use the debug signing config (`android/app/build.gradle.kts`), so the APK installs but can't be published to the Play Store. Add a release keystore before distributing publicly.
- **iOS** has no signing certificates configured in CI, so the IPA is unsigned. Distributing a signed build needs an Apple Developer certificate and provisioning profile added as repository secrets.
- **macOS** builds are unsigned and not notarized.
- **Linux** playback uses libmpv (through `just_audio_media_kit`), which is not bundled in the AppImage or tarball. Install it first (`sudo apt install libmpv2`, or `libmpv-dev` to build). Windows bundles its own mpv library.
- **Web** is only compile-checked in CI. Playback, the local database and downloads are not supported there yet.

### Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs `flutter analyze`, `flutter test` and a web build on every pull request and on pushes to `master`. The release pipeline also runs `flutter analyze` before building.

### Building locally

```sh
flutter build apk --release                  # Android
flutter build ios --release --no-codesign    # iOS (macOS host)
flutter build macos --release                # macOS (macOS host)
flutter build windows --release              # Windows (Windows host)
flutter build linux --release                # Linux (Linux host; needs GTK, libsecret, jsoncpp, libmpv dev packages)
```
