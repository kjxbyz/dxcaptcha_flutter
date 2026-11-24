# dxcaptcha_flutter

**English** | [简体中文](README_ZH.md)

A Flutter plugin for DingXiang (顶象) CAPTCHA, supporting **iOS / Android / Web**.
It ships both an **embedded widget** and a **full-screen dialog**, sharing a single Dart API across
all platforms.

- `DxCaptcha` — a single widget you can drop into your tree to render the CAPTCHA
- `DxCaptcha.show(context)` — one line to present the CAPTCHA in a dialog, returning a structured
  result
- `DxCaptchaController` — state tracking, retry after failure, token access
- Normalized events — platform-specific event name differences are handled inside the plugin
- Built-in loading/error placeholders, Chinese/English UI, and private-deployment passthrough

## Platform support

| Capability          | iOS | Android | Web | Desktop     |
|---------------------|-----|---------|-----|-------------|
| Embedded widget     | ✅  | ✅      | ✅  | Placeholder |
| Dialog mode         | ✅  | ✅      | ✅  | Placeholder |
| Chinese / English   | ✅  | ✅      | ✅  | —           |
| Private `apiServer` | ✅  | ✅      | ✅  | —           |

- iOS: `dx-captcha.xcframework` v5.4.18r (bundled with the plugin)
- Android: download `dx-captcha-*.aar` yourself and put it in `android/libs/`
- Web: the v5 JS SDK is loaded automatically from the DingXiang CDN — no manual `<script>` needed

## Requirements

| Item    | Version                                                 |
|---------|---------------------------------------------------------|
| Flutter | >= 3.27 (the example app is pinned to 3.35.7 via FVM)   |
| Dart    | >= 3.9                                                  |
| iOS     | >= 15.0 (Xcode 27 requires 15.0 even for the simulator) |
| Android | minSdk 24, compileSdk 36                                |

A `.fvmrc` is included, so using FVM is recommended:

```bash
fvm install          # install the version pinned in .fvmrc
fvm flutter pub get
```

## Installation

```yaml
dependencies:
  dxcaptcha_flutter:
    path: ../dxcaptcha_flutter   # or the published version
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

> **Path fix for symlinked plugins**
> Flutter pulls local plugins in through the `.symlinks/plugins/<name>` symlink, and
> CocoaPods over-counts the link depth when resolving `vendored_frameworks`. The
> framework then points at a directory that does not exist and the build fails with
> `Undefined symbol: _OBJC_CLASS_$_DXCaptchaViewV5`.
> The example app overrides the path resolver in `example/ios/Podfile` to work around it:
>
> ```ruby
> def flutter_relative_path_from_podfile(path)
>   File.realpath(path)
> end
> ```
>
> If your host app hits the same linker error, add this snippet to your own Podfile and
> run `pod install` again.

When `use_frameworks!` is enabled the assets are bundled inside `dxcaptcha_flutter.framework`.
If the CAPTCHA area renders blank on a real device, add `DXCaptcha.bundle` to the Runner
target's **Copy Bundle Resources** as well.

### Android

DingXiang does not publish to a public Maven repository, so download the aar from the console:

1. Sign in to the DingXiang console → 无感验证 (frictionless CAPTCHA) → SDK download
2. Put `dx-captcha-without-risk-vX.X.X.aar` (recommended, no device fingerprinting) into
   `dxcaptcha_flutter/android/libs/`
3. Rebuild — Gradle picks it up automatically through `fileTree`

```
dxcaptcha_flutter/
└── android/libs/
    ├── README.md
    └── dx-captcha-without-risk-v5.4.27.aar   ← put it here
```

The plugin already includes:

- `INTERNET` / `ACCESS_NETWORK_STATE` permissions
- DingXiang's official ProGuard rules (`android/consumer-rules.pro`)
- A reflection-based wrapper around the SDK, so the build does not break when the aar is
  absent — instead the Dart side receives a readable `sdk_unavailable` error

> If your aar uses a different package name or method signature than the default
> candidates, just adjust `packageCandidates` at the top of
> `android/src/main/kotlin/.../DxCaptchaSdkBridge.kt`.

### Web

Nothing to configure — the plugin injects this on first use:

```html
<script src="https://cdn.dingxiang-inc.com/ctu-group/captcha-ui/v5/index.js"></script>
```

To use a custom CDN (for example an intranet proxy), set `config.extra['scriptUrl']`.

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

| Parameter        | Type                 | Description                                                       |
|------------------|----------------------|-------------------------------------------------------------------|
| `appId`          | `String`             | Required; from App Management in the DingXiang console            |
| `apiServer`      | `String?`            | Private deployment domain; leave empty for SaaS                   |
| `language`       | `DxCaptchaLanguage?` | `zh` / `en`                                                       |
| `style`          | `DxCaptchaStyle`     | Web only: `embed` / `inline` / `popup` / `oneclick`               |
| `width`          | `int?`               | Widget width in pixels                                            |
| `bgColor`        | `String?`            | Widget background color, e.g. `#FFFFFF`                           |
| `customStyle`    | `Map`                | Maps to the SDK's `customStyle`                                   |
| `customLanguage` | `Map`                | Maps to the SDK's `customLanguage`                                |
| `timeout`        | `Duration?`          | Request timeout, 6 seconds by default                             |
| `showVoice`      | `bool?`              | Whether to expose the voice verification entry                    |
| `privacy`        | `DxCaptchaPrivacy`   | Data collection whitelist: `minimal` / `full`                     |
| `enableCache`    | `bool`               | Cache frictionless results (ignored on iOS)                       |
| `extra`          | `Map`                | Passthrough params such as private `keyURL`, `ua_js`, `scriptUrl` |

### DxCaptchaResult

| Member      | Description                                         |
|-------------|-----------------------------------------------------|
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
fvm flutter run           # pick an iOS / Android device
fvm flutter run -d chrome # Web
```

The example includes an appId field, a Chinese/English switch, embedded/dialog switching,
an event log, and token display.

## Troubleshooting

**Blank CAPTCHA area / load failure**
Check that the appId is correct and that DingXiang endpoints are reachable. On iOS, make
sure `DXCaptcha.bundle` is packaged. For private deployments, always provide the full
`apiServer` including `https://`.

**Android reports `sdk_unavailable`**
The aar is not in `android/libs/`, or it was added without running `flutter clean` afterwards.

**Token starts with `sl`**
That is the degraded token issued when the front end cannot reach the network, meaning the
device cannot connect to `apiServer` directly. Check connectivity or the private domain
configuration.

**iOS linker error `Undefined symbol: _OBJC_CLASS_$_DXCaptchaViewV5`**
See "Path fix for symlinked plugins" above.

## License

MIT
