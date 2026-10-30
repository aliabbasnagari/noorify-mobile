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

- **Android** release builds are signed with your upload keystore when one is configured (see [Android release signing](#android-release-signing)); otherwise they fall back to the debug key, which installs fine but can't be published to the Play Store.
- **iOS** has no signing certificates configured in CI, so the IPA is unsigned. Distributing a signed build needs an Apple Developer certificate and provisioning profile added as repository secrets.
- **macOS** builds are unsigned and not notarized.
- **Linux** playback uses libmpv (through `just_audio_media_kit`), which is not bundled in the AppImage or tarball. Install it first (`sudo apt install libmpv2`, or `libmpv-dev` to build). Windows bundles its own mpv library.
- **Web** is only compile-checked in CI. Playback, the local database and downloads are not supported there yet.

### Continuous integration

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs `flutter analyze`, `flutter test` and a web build on every pull request and on pushes to `master`. The release pipeline also runs `flutter analyze` before building.

### Android release signing

The release build signs with `android/key.properties` when that file exists, and falls back to the debug key when it doesn't. The file and any `*.jks` / `*.keystore` are git-ignored.

1. **Create an upload keystore** (once). `keytool` ships with Android Studio's JDK (`<Android Studio>\jbr\bin\keytool.exe`):

   ```powershell
   keytool -genkeypair -v -keystore $HOME\noorify-upload-keystore.jks `
     -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

   Pick a strong password. For a PKCS12 keystore the key password is the store password, so use the same value for both below. **Back up the file and the password** somewhere safe (a password manager); losing them means you can't update the app.

2. **Local release builds.** Copy the keystore to `android/app/upload-keystore.jks` and create `android/key.properties`:

   ```properties
   storeFile=upload-keystore.jks
   storePassword=<password>
   keyAlias=upload
   keyPassword=<password>
   ```

   `storeFile` is relative to `android/app`; an absolute path also works. Then `flutter build apk --release` or `flutter build appbundle --release`.

3. **CI release builds.** Add four repository secrets (Settings → Secrets and variables → Actions):

   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | the keystore, base64-encoded: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\noorify-upload-keystore.jks")) \| Set-Clipboard` |
   | `ANDROID_KEYSTORE_PASSWORD` | the store password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | the key password (same as the store password for PKCS12) |

   With the secrets present, the tag pipeline signs both `noorify-<tag>-android.apk` and `noorify-<tag>-android.aab`. Without them it still builds, with a warning, using the debug key.

4. **Play Store.** Upload the `.aab`. Enrol in Play App Signing when asked: Google then holds the app signing key and your keystore is only the upload key, which Play support can reset if you ever lose it.

### Building locally

```sh
flutter build apk --release                  # Android (APK)
flutter build appbundle --release            # Android (App Bundle for the Play Store)
flutter build ios --release --no-codesign    # iOS (macOS host)
flutter build macos --release                # macOS (macOS host)
flutter build windows --release              # Windows (Windows host)
flutter build linux --release                # Linux (Linux host; needs GTK, libsecret, jsoncpp, libmpv dev packages)
```
