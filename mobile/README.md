# Tink Mobile — v0.1.0-beta.2

Native Android and iOS clients for the [Tink self-hosted notification gateway](https://github.com/mrasong/tink). The original macOS client, Go server, and dashboard are unchanged.

## Download

The preview is released from the mobile development branch under [Releases](https://github.com/xcouturecc/tink/releases), tagged `mobile-v0.1.0-beta.2`.

- `Tink-Android-v0.1.0-beta.2-debug.apk`: Android 8+ **debug-signed** test APK; install on your Android device after allowing this source to install apps.
- `Tink-iOS-v0.1.0-beta.2-unsigned.ipa`: **unsigned**, iPhone/iPad device build for local re-signing. **Not installable as-is.** An Apple-signed developer/distribution certificate **and matching provisioning profile** are required to produce an installable build; simply using an arbitrary self-issued certificate is insufficient under standard iOS installation rules. Use an authorized local signing tool, or build via Xcode with your own team and device provisioning.

**Keep your certificate private.** Do not upload a .p12, password, provisioning profile, or APNs private key to a public repository. This workflow creates unsigned iOS packages and does not require Apple credentials.

## Capabilities

| Platform | Implemented | Missing |
| --- | --- | --- |
| iOS 17+ (SwiftUI) | Register a device, SSE reception while app is foregrounded, automatic reconnection, offline replay, local message history, Keychain token storage, test notification | APNs/background delivery, signed IPA, device testing |
| Android 8+ (Kotlin + Compose) | Register a device, SSE reception while app is foregrounded, automatic reconnection, offline replay, local message history, Keystore token storage, test notification | FCM/OEM background push, device testing, release signing |

**Critical:** this version does not deliver reliable push notifications when the app is backgrounded, suspended, locked, or terminated. This is an early functional preview, not a replacement for Bark or a production alerting system.

## Android development

Open `mobile/android` in Android Studio with JDK 17 and SDK 35, sync Gradle and run `app`. The workflow uses Gradle 8.12 to build the debug APK.

## iOS development / local signing

1. Install Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Run `cd mobile/ios && xcodegen generate`.
3. Open `TinkMobile.xcodeproj` in Xcode.
4. Select a suitable Apple development team and configure the bundle ID and provisioning for your iPhone.
5. Build and run the application from Xcode; or re-sign the **unsigned IPA** locally using your valid certificate and provisioning profile.

CI also compiles for the iOS Simulator, but the downloadable IPA contains the **iphoneos** build, not a simulator app.

## Existing server API

- `POST /api/v1/devices`: register a phone UUID against a Bearer key.
- `GET /api/v1/events`: foreground SSE with `X-Device-ID` and `Last-Event-ID` replay.
- `POST /api/v1/messages`: send a test notification.

Use a trusted **HTTPS** Tink server endpoint with your own Bearer token. The server retains notifications for up to 7 days and replays up to 200 messages; the phone stores up to 250 local messages. Saving a new connection configuration clears the local history and replay cursor.

## Publishing

`.github/workflows/mobile.yml` builds both platforms on pushes to `feat/mobile-clients` and provides artifacts. Commits containing `[mobile-release]` on that branch, when both builds succeed, publish APK and unsigned IPA to a **GitHub prerelease**. Use a new `MOBILE_VERSION` value for subsequent releases; the action does not overwrite existing release tags.

## License

Based on [mrasong/tink](https://github.com/mrasong/tink), under the MIT license. Preserve the repository's original `LICENSE`.

## Branding in beta.2

The Android launcher/adaptive icon and iOS app icon now reuse the official upstream Tink artwork. Mobile screens include the original Tink logo, refreshed native cards, server connection indicators and improved empty-state message views. Android notifications now use a dedicated monochrome bell status-bar icon. The iOS icon is generated as an opaque 1024x1024 RGB PNG during Xcode builds, using the bundled upstream artwork without storing a signing certificate in CI.

This is a visual refinement only; APNs/FCM lock-screen delivery remains a separate future feature.
