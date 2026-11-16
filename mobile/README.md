# Tink Mobile — first development milestone

Native mobile client foundations for the existing Tink self-hosted notification gateway.

| Client | Stack | Implemented | Still missing |
| --- | --- | --- | --- |
| iOS 17+ | SwiftUI / URLSession | Device registration, foreground SSE, offline replay, local notifications, local message history, Keychain bearer auth, test push | APNs, background push, production signing |
| Android 8+ | Kotlin / Jetpack Compose / OkHttp | Device registration, foreground SSE, offline replay, local notifications, local message history, Android Keystore bearer auth, test push | FCM/OEM push, reliable background delivery, production signing |

The original macOS client, Go backend and Svelte dashboard are unchanged.

## Android quick start

1. Open mobile/android in Android Studio with JDK 17 and Android SDK 35.
2. Allow Gradle sync, then build/run the app module on an Android 8+ device.
3. Enter your own Tink HTTPS server root URL and Bearer Secret Key, then tap 保存并连接.
4. Grant notification permission (Android 13+) and tap 发送测试通知.

CLI: from mobile/android run gradle :app:assembleDebug (Gradle 8.12, SDK 35).

Successful GitHub Actions builds upload a debug APK artifact named tink-android-debug.

## iOS quick start

1. Install XcodeGen and Xcode 16+.
2. From mobile/ios run xcodegen generate.
3. Open TinkMobile.xcodeproj, select your Apple development team and run on iOS 17+.
4. Enter your own Tink HTTPS server root URL and Bearer Secret Key, then tap 保存并连接.

CI compiles an unsigned iOS Simulator build only. Installing on an iPhone requires valid development signing. No signed IPA or TestFlight release is available yet.

## Existing API endpoints

- POST /api/v1/devices registers a persistent device UUID (scoped to the bearer key).
- GET /api/v1/events subscribes to SSE using X-Device-ID and Last-Event-ID.
- POST /api/v1/messages sends a test notification to the newly registered device.

Message history is local (max 250), with server-side offline replay limited to 200 messages and retention of 7 days. The server does not provide an arbitrary history listing API. Editing and saving connection credentials resets local history and replay cursor.

## Critical background limitation

SSE is not a replacement for platform push notifications. These clients **stop listening when backgrounded**; they do not reliably display notifications while locked or terminated. Do not depend on this milestone for critical alerts.

Next milestone: server-side device push subscriptions and APNs, FCM/Android OEM provider dispatch, deduplication/retry observability, tests and signed releases. iOS APNs requires Apple developer push credentials, while FCM requires Firebase configuration; neither should be checked into source control.

## Security / license

HTTPS is required and Android cleartext is disabled. Place a self-hosted Tink server behind a trusted HTTPS reverse proxy. Bearer secrets are stored via Keychain or Android Keystore, and must never be committed. Original project: https://github.com/mrasong/tink, licensed under MIT. Keep the root LICENSE intact and preserve original attribution.
