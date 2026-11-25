# dxcaptcha_flutter

**English** | [简体中文](README_ZH.md)

A Flutter plugin for DingXiang (顶象) CAPTCHA, supporting **iOS / Android**.
It ships both an **embedded widget** and a **full-screen dialog**, sharing a single
Dart API across both platforms.

- `DxCaptcha` — a single widget you can drop into your tree to render the CAPTCHA
- `DxCaptcha.show(context)` — one line to present the CAPTCHA in a dialog, returning a
  structured result
- `DxCaptchaController` — state tracking, retry after failure, token access
- Normalized events — platform-specific event name differences are handled inside the plugin
- Built-in loading/error placeholders, Chinese/English UI, and private-deployment passthrough

## Platform support

| Capability          | iOS | Android |
| ------------------- | :-: | :-----: |
| Embedded widget     | ✅  |   ✅    |
| Dialog mode         | ✅  |   ✅    |
| Chinese / English   | ✅  |   ✅    |
| Private `apiServer` | ✅  |   ✅    |

- iOS: `dx-captcha.xcframework` v5.4.18r (bundled with the plugin)
- Android: `dx-captcha-without-risk-v5.4.27r.aar` bundled; minimal mode by default (no risk SDK)

## Requirements

| Item    | Version                                                 |
|---------|---------------------------------------------------------|
| Flutter | >= 3.35.0                                               |
| Dart    | >= 3.9                                                  |
| iOS     | >= 15.0 (Xcode 27 requires 15.0 even for the simulator) |
| Android | minSdk 24, compileSdk 36                                |

A `.fvmrc` is included, so using FVM is recommended:

```bash
fvm install # install the version pinned in .fvmrc
fvm flutter pub get
```

## Installation

```yaml
dependencies:
  dxcaptcha_flutter:
    path: ../dxcaptcha_flutter # or the published version
```

### iOS

The SDK and its resource bundle are already in the repository — no extra steps:

```
ios/Frameworks/dx-captcha.xcframework   # CAPTCHA core framework
ios/Frameworks/DXCaptcha.bundle         # CAPTCHA front-end assets (missing => blank view)
```

`ios/dxcaptcha_flutter.podspec` already takes care of:

- `vendored_frameworks` for the xcframework
- `resources` for `DXCaptcha.bundle`
- linking `WebKit / UIKit / z / resolv / c++`
- a minimum deployment target of 15.0

When `use_frameworks!` is enabled the assets are bundled inside `dxcaptcha_flutter.framework`.
If the CAPTCHA area renders blank on a real device, add `DXCaptcha.bundle` to the Runner
target's **Copy Bundle Resources** as well.

### Android

The CAPTCHA SDK ships with the plugin, running in the official "minimal usage" mode by
default (**no device fingerprint / risk SDK integrated**):

```
dxcaptcha_flutter/
└── android/libs/
    ├── README.md
    └── dx-captcha-without-risk-v5.4.27r.aar   # CAPTCHA SDK
```

> **About "without-risk" and the risk SDK**
> Verified by decompiling: "without-risk" only means the risk SDK is not packaged inside
> and must be provided by the integrator. When `DXKeyRiskEnable` defaults to true, the
> bytecode of `startToLoad`, `setAllowPrivacyList` and the token path call
> `com.dx.mobile.risk.DXRisk` directly — without that class they throw
> `NoClassDefFoundError`.
> The plugin follows the official minimal-usage config and disables risk by default:
> with `enableRiskSdk: false` it passes `DXKeyRiskEnable=false` (do not load the
> fingerprint SDK) and `wait_for_const_id_sdk=false` (tell the server not to wait for the
> fingerprint), and skips `setAllowPrivacyList` (also omitted in the official minimal
> example). No risk-related dependency is needed in this mode. The trade-off is losing
> the security hardening provided by device fingerprinting.

To enable risk hardening:

1. Set `DxCaptchaConfig(enableRiskSdk: true)` on the Dart side
2. Put `dx-risk-v*.aar` from the official demo package (version-matched) into `android/libs/`
3. Run `flutter clean && flutter build`; collection scope is controlled by `privacy`
   (`minimal` maps to `PrivacyFlag.DEFALUT=0`), and declare the risk SDK in your privacy
   policy per DingXiang's compliance guide

To switch versions, replace the aars under `android/libs/` and run
`flutter clean && flutter build` — Gradle unpacks them into classes.jar / assets / jniLibs
at configuration time (AGP forbids library modules from depending on local aar files
directly; see `android/build.gradle.kts`). The fingerprinted `dx-captcha-v*.aar` (which
bundles dx-risk itself) works the same way — keep `enableRiskSdk: true` in that case.

The plugin already includes:

- `INTERNET` / `ACCESS_NETWORK_STATE` permissions
- DingXiang's official ProGuard rules (`android/consumer-rules.pro`)
- A reflection bridge aligned with the official docs: `DXCaptchaViewV5.init(appId)` +
  `startToLoad(listener, "success", "fail")`; when `enableRiskSdk: true`,
  `setAllowPrivacyList` is called before init (`PrivacyFlag.DEFALUT=0` / `ALL=-1`)
- Builds fine even without the aar — the Dart side just receives a readable
  `sdk_unavailable` error

> If your aar uses a different package/class name than the default candidates, adjust
> `packageCandidates` / `viewClassCandidates` at the top of
> `android/src/main/kotlin/com/kjxbyz/plugins/dxcaptcha_flutter/DxCaptchaSdkBridge.kt`.

## Quick start

### Embedded mode

```dart
import 'package:dxcaptcha_flutter/dxcaptcha_flutter.dart';

DxCaptcha(
  config: const DxCaptchaConfig(
    appId: 'your-app-id',
    language: DxCaptchaLanguage.zh,
  ),
  onSuccess: (DxCaptchaResult result) {
    // Send this token to your backend for server-side verification
    print('token: ${result.token}');
  },
  onFail: (DxCaptchaResult result) {
    print('failed: ${result.message}');
  },
)
```

The widget lays out at a default `362 : 335` aspect ratio; override it with
`width` / `height` / `aspectRatio`.

### Dialog mode

```dart
final DxCaptchaResult? result = await DxCaptcha.show(
  context,
  config: const DxCaptchaConfig(appId: 'your-app-id'),
  title: 'Security check',
  description: 'Slide to verify to continue',
  timeout: const Duration(minutes: 2),
);

if (result == null) {
  // The user dismissed the dialog
} else if (result.isSuccess) {
  await login(result.token!);
} else {
  // result.message holds the failure reason; the dialog already offers "Retry"
}
```

### Controller: state and retry

```dart
final DxCaptchaController controller = DxCaptchaController();

DxCaptcha(
  config: config,
  controller: controller,
  onSuccess: (result) => print(result.token),
);

// Read the state
if (controller.isVerified) { ... }

// Reload after a failed verification
await controller.reload();

// Await the next result (resolves on both success and failure)
final result = await controller.waitForResult(
  timeout: const Duration(minutes: 1),
);
```

## API

### DxCaptchaConfig

| Parameter        | Type                 | Description                                                      |
| ---------------- | -------------------- | ---------------------------------------------------------------- |
| `appId`          | `String`             | Required; from App Management in the DingXiang console           |
| `apiServer`      | `String?`            | Private deployment domain; leave empty for SaaS                  |
| `language`       | `DxCaptchaLanguage?` | `zh` / `en`                                                      |
| `width`          | `int?`               | Widget width in pixels                                           |
| `bgColor`        | `String?`            | Widget background color, e.g. `#FFFFFF`                          |
| `customStyle`    | `Map`                | Maps to the SDK's `customStyle`                                  |
| `customLanguage` | `Map`                | Maps to the SDK's `customLanguage`                               |
| `timeout`        | `Duration?`          | Request timeout, 6 seconds by default                            |
| `showVoice`      | `bool?`              | Whether to expose the voice verification entry                   |
| `privacy`        | `DxCaptchaPrivacy`   | Data collection whitelist: `minimal` / `full`                    |
| `enableCache`    | `bool`               | Cache frictionless results (ignored on iOS)                      |
| `enableRiskSdk`  | `bool`               | Load the fingerprint (risk) SDK; default `false` (minimal usage) |
| `extra`          | `Map`                | Passthrough params such as private `keyURL`, `ua_js`             |

### DxCaptchaResult

| Member      | Description                                         |
| ----------- | --------------------------------------------------- |
| `type`      | `DxCaptchaEventType` — the normalized event type    |
| `token`     | Verification credential; only set on `success`      |
| `message`   | Failure reason                                      |
| `isSuccess` | `type == success && token != null`                  |
| `isFailure` | Whether the verification failed                     |
| `rawEvent`  | Raw event name from the native layer, for debugging |
| `raw`       | Full payload from the native layer                  |

### Event types

`render` · `ready` · `loadFail` · `dragStart` · `dragging` · `dragEnd` ·
`verify` · `verifyDone` · `verifySuccess` · `verifyFail` · `passByServer` ·
`success` · `fail` · `tapLogo` · `loadTooMuch` · `unknown`

The plugin normalizes variants such as `success`, `DXCaptchaEventVerifySuccess`
and `pass-by-server` into the same enum.

## Example app

```bash
cd example
fvm flutter run # pick an iOS / Android device
```

The example includes an appId field, a Chinese/English switch, embedded/dialog switching,
an event log, and token display.

## Troubleshooting

**Blank CAPTCHA area / load failure**
Check that the appId is correct and that DingXiang endpoints are reachable. On iOS, make
sure `DXCaptcha.bundle` is packaged. For private deployments, always provide the full
`apiServer` including `https://`.

**Android reports `sdk_unavailable`**
The aar ships with the plugin, so this should not happen normally; if you removed the aar
from `android/libs/` or swapped versions, run `flutter clean` before rebuilding.

**Token starts with `sl`**
That is the degraded token issued when the front end cannot reach the network, meaning the
device cannot connect to `apiServer` directly. Check connectivity or the private domain
configuration.

**iOS shows a blank (white) CAPTCHA area**
The DingXiang SDK loads `DXCaptcha.bundle` from the app bundle root
(`[NSBundle mainBundle]`). If the bundle is missing the WKWebView loads an empty page and
the area stays white. Verify the bundle exists in the built app:

```bash
ls build/ios/iphoneos/Runner.app/DXCaptcha.bundle
```

If it is missing (e.g. it ended up inside `Frameworks/dxcaptcha_flutter.framework/`), the
plugin podspec must declare `static_framework = true` (already set) — then re-run
`pod install` and rebuild. The plugin also reports `sdk_resource_missing` when the bundle
is absent, so check the error log for a faster diagnosis.

Another common trigger of the `load_fail` event is a missing `protocol` config: it is
required for iOS SDK versions below v5.4.21 (the bundled SDK is v5.4.18r); without it the
SDK may request resources over `http`, which gets blocked by ATS. The plugin injects
`https:` by default; override it via `extra: {'protocol': 'https:'}` if needed.

**iOS linker error `Undefined symbol: _OBJC_CLASS_$_DXCaptchaViewV5`**
See "Path issue with symlinked plugins" above.

## License

MIT
