# dxcaptcha_flutter

[English](README.md) | **简体中文**

顶象无感验证码（DingXiang Captcha）Flutter 插件，支持 **iOS / Android / Web**，
提供 **嵌入组件** 与 **全屏弹窗** 两种接入方式，三端共用一套 Dart API。

- 统一的 `DxCaptcha` 组件，直接放进 Widget 树即可渲染验证码
- `DxCaptcha.show(context)` 一行代码弹出验证，返回结构化结果
- `DxCaptchaController` 管理状态、失败重试、读取 token
- 事件归一化：iOS / Android / Web 的事件名差异由插件内部抹平
- 内置加载/错误占位、中文/英文界面、私有化部署参数透传

## 平台支持

| 能力             | iOS | Android | Web | 桌面端   |
|------------------|-----|---------|-----|----------|
| 嵌入组件         | ✅  | ✅      | ✅  | 占位提示 |
| 弹窗模式         | ✅  | ✅      | ✅  | 占位提示 |
| 中文 / 英文      | ✅  | ✅      | ✅  | —        |
| 私有化 apiServer | ✅  | ✅      | ✅  | —        |

- iOS：`dx-captcha.xcframework` v5.4.18r（已随插件内置）
- Android：`dx-captcha-without-risk-v5.4.27r.aar`（已随插件内置，默认最小化模式不集成风控）
- Web：自动从顶象 CDN 加载 v5 JS SDK，无需手动引入

## 环境要求

| 项目    | 版本                                    |
|---------|-----------------------------------------|
| Flutter | >= 3.27（示例工程用 FVM 固定在 3.35.7） |
| Dart    | >= 3.9                                  |
| iOS     | >= 15.0（Xcode 27 起模拟器最低 15.0）   |
| Android | minSdk 24，compileSdk 36                |

项目已附带 `.fvmrc`，推荐直接使用 FVM：

```bash
fvm install          # 安装 .fvmrc 指定的版本
fvm flutter pub get
```

## 安装

```yaml
dependencies:
  dxcaptcha_flutter:
    path: ../dxcaptcha_flutter   # 或发布后的版本号
```

### iOS

SDK 与资源包已在仓库内，无需额外操作：

```
ios/Frameworks/dx-captcha.xcframework   # 验证码核心框架
ios/Frameworks/DXCaptcha.bundle         # 验证码前端资源（缺失会白屏）
```

`ios/dxcaptcha_flutter.podspec` 已完成以下配置：

- `vendored_frameworks` 引入 xcframework
- `resources` 打包 `DXCaptcha.bundle`
- 链接 `WebKit / UIKit / z / resolv / c++`
- 最低部署版本 15.0

> **符号链接插件的路径修正**
> Flutter 通过 `.symlinks/plugins/<name>` 符号链接引入本地插件，CocoaPods 在解析
> `vendored_frameworks` 时会重复叠加链接层级，导致框架指向不存在的目录并报
> `Undefined symbol: _OBJC_CLASS_$_DXCaptchaViewV5`。
> 示例工程在 `example/ios/Podfile` 中覆盖了路径解析函数来规避：
>
> ```ruby
> def flutter_relative_path_from_podfile(path)
>   File.realpath(path)
> end
> ```
>
> 宿主工程若遇到同样的链接错误，把这段加到自己的 Podfile 中，然后重新
> `pod install` 即可。

使用 `use_frameworks!` 时资源会打包进 `dxcaptcha_flutter.framework`，若真机验证
出现空白（验证码区域全白），把 `DXCaptcha.bundle` 额外加入 Runner target 的 **Copy Bundle Resources**。

### Android

验证码 SDK 已随插件内置，默认按官方文档「最小化使用」运行（**不集成设备指纹/风控 SDK**）：

```
dxcaptcha_flutter/
└── android/libs/
    ├── README.md
    └── dx-captcha-without-risk-v5.4.27r.aar   # 验证码 SDK
```

> **关于 "without-risk" 与风控 SDK**
> 实测反编译确认：`dx-captcha-without-risk` 的 "without-risk" 只是「不打包风控 SDK，
> 由接入方自行提供」——`DXKeyRiskEnable` 默认为 true 时，`startToLoad` 内部、
> `setAllowPrivacyList` 与 token 获取链路在字节码层都会调用 `com.dx.mobile.risk.DXRisk`，
> 缺少该类时抛 `NoClassDefFoundError`。
> 插件按官方「最小化使用」配置默认关闭风控：`enableRiskSdk: false` 时自动传入
> `DXKeyRiskEnable=false`（不加载设备指纹 SDK）与 `wait_for_const_id_sdk=false`
> （通知服务端不等待设备指纹），并跳过 `setAllowPrivacyList` 调用（官方最小化示例
> 同样省略），此时无需任何 risk 相关依赖。代价是失去设备指纹的安全增强能力。

需要风控增强时：

1. Dart 侧设置 `DxCaptchaConfig(enableRiskSdk: true)`
2. 把官方 DEMO 包内的 `dx-risk-v*.aar`（与验证码 SDK 版本配对）放入 `android/libs/`
3. `flutter clean && flutter build`；采集范围由 `privacy` 控制
   （`minimal` 对应 `PrivacyFlag.DEFALUT=0`），隐私政策按顶象合规指南声明

如需更换版本，替换 `android/libs/` 下的 aar 后重新 `flutter clean && flutter build`
即可——Gradle 会在配置期自动把 aar 解包为 classes.jar / assets / jniLibs 注入插件
（AGP 禁止库模块直接依赖本地 aar，解包逻辑见 `android/build.gradle.kts`）；
含指纹的 `dx-captcha-v*.aar`（自带 dx-risk）同样适用，此时保持 `enableRiskSdk: true`。

插件已内置：

- `INTERNET` / `ACCESS_NETWORK_STATE` 权限
- 顶象官方混淆规则（`android/consumer-rules.pro`）
- 按官方文档对齐的反射桥接：`DXCaptchaViewV5.init(appId)` +
  `startToLoad(listener, "success", "fail")`；`enableRiskSdk: true` 时初始化前
  自动调用 `setAllowPrivacyList`（`PrivacyFlag.DEFALUT=0` / `ALL=-1`）
- 未放入 aar 时不会编译失败，而是在 Dart 侧返回 `sdk_unavailable` 的可读错误

> 若你的 aar 包名/类名与默认候选不同，只需调整
> `android/src/main/kotlin/com/kjxbyz/plugins/dxcaptcha_flutter/DxCaptchaSdkBridge.kt`
> 顶部的 `packageCandidates` / `viewClassCandidates`。

### Web

无需配置，插件会在首次使用时动态插入：

```html

<script src="https://cdn.dingxiang-inc.com/ctu-group/captcha-ui/v5/index.js"></script>
```

如需自定义 CDN（例如内网代理），通过 `config.extra['scriptUrl']` 指定。

## 快速开始

### 嵌入模式

```dart
import 'package:dxcaptcha_flutter/dxcaptcha_flutter.dart';

DxCaptcha
(
config: const DxCaptchaConfig(
appId: 'your-app-id',
language: DxCaptchaLanguage.zh,
),
onSuccess: (DxCaptchaResult result) {
// 后端二次校验使用该 token
print('token: ${result.token}');
},
onFail: (DxCaptchaResult result) {
print('失败: ${result.message}');
},
)
```

组件默认按 `362 : 335` 的宽高比布局，可用 `width` / `height` / `aspectRatio` 覆盖。

### 弹窗模式

```dart

final DxCaptchaResult? result = await
DxCaptcha.show
(
context,
config: const DxCaptchaConfig(appId: 'your-app-id'),
title: '安全验证',
description: '请完成滑动验证以继续',
timeout: const Duration(minutes: 2),
);

if (result == null) {
// 用户主动关闭
} else if (result.isSuccess) {
await login(result.token!);
} else {
// result.message 为失败原因，弹窗内已提供「重试」
}
```

### 控制器：状态与重试

```dart

final DxCaptchaController controller = DxCaptchaController();

DxCaptcha
(
config: config,
controller: controller,
onSuccess: (result) => print(result.token),
);

// 读取状态
if (controller.isVerified) { ... }

// 验证失败后重新加载
await controller.reload();

// 等待下一次验证结果（成功或失败都会返回）
final result = await controller.waitForResult(
timeout: const Duration(minutes
:
1
)
,
);
```

## API

### DxCaptchaConfig

| 参数             | 类型                 | 说明                                                   |
|------------------|----------------------|--------------------------------------------------------|
| `appId`          | `String`             | 必填，顶象控制台应用管理获取                           |
| `apiServer`      | `String?`            | 私有化部署域名，SaaS 留空                              |
| `language`       | `DxCaptchaLanguage?` | `zh` / `en`                                            |
| `style`          | `DxCaptchaStyle`     | 仅 Web 生效：`embed` / `inline` / `popup` / `oneclick` |
| `width`          | `int?`               | 验证码控件宽度（像素）                                 |
| `bgColor`        | `String?`            | 控件背景色，如 `#FFFFFF`                               |
| `customStyle`    | `Map`                | 对应 SDK `customStyle`                                 |
| `customLanguage` | `Map`                | 对应 SDK `customLanguage`                              |
| `timeout`        | `Duration?`          | 请求超时，默认 6 秒                                    |
| `showVoice`      | `bool?`              | 是否展示语音验证入口                                   |
| `privacy`        | `DxCaptchaPrivacy`   | 隐私采集白名单：`minimal` / `full`                     |
| `enableCache`    | `bool`               | 无感验证结果缓存（iOS 忽略）                           |
| `enableRiskSdk`  | `bool`               | 是否加载设备指纹（风控）SDK，默认 `false`（最小化使用） |
| `extra`          | `Map`                | 透传参数，如私有化 `keyURL`、`ua_js`、`scriptUrl`      |

### DxCaptchaResult

| 成员        | 说明                                     |
|-------------|------------------------------------------|
| `type`      | `DxCaptchaEventType`，归一化后的事件类型 |
| `token`     | 验证通过凭证，仅 `success` 时有值        |
| `message`   | 失败原因                                 |
| `isSuccess` | `type == success && token != null`       |
| `isFailure` | 是否验证失败                             |
| `rawEvent`  | 原生层原始事件名，便于排查               |
| `raw`       | 原生层完整负载                           |

### 事件类型

`render` · `ready` · `loadFail` · `dragStart` · `dragging` · `dragEnd` ·
`verify` · `verifyDone` · `verifySuccess` · `verifyFail` · `passByServer` ·
`success` · `fail` · `tapLogo` · `loadTooMuch` · `unknown`

插件会兼容 `success`、`DXCaptchaEventVerifySuccess`、`pass-by-server`
等多种写法后统一归一化。

## 示例工程

```bash
cd example
fvm flutter run           # 选择 iOS / Android 设备
fvm flutter run -d chrome # Web
```

示例包含 appId 输入、中英文切换、嵌入/弹窗切换、事件日志与 token 展示。

## 常见问题

**验证码区域空白 / 加载失败**
检查 appId 是否正确、网络是否可访问顶象服务；iOS 确认 `DXCaptcha.bundle` 已打包；
私有化部署务必填写完整的 `apiServer`（含 `https://`）。

**Android 报 `sdk_unavailable`**
插件已内置 aar，正常不会出现；若曾移除 `android/libs/` 下的 aar 或更换版本，
需重新执行 `flutter clean` 后再构建。

**token 以 `sl` 开头**
这是前端网络不通时的降级 token，说明设备无法直连 `apiServer`，需要检查网络或
私有化域名配置。

**iOS 验证码区域白屏**
顶象 SDK 通过 `[NSBundle mainBundle]`（app 包根目录）加载 `DXCaptcha.bundle`。
bundle 缺失时 WKWebView 加载空白页，表现为白屏。检查构建产物中 bundle 是否存在：

```bash
ls build/ios/iphoneos/Runner.app/DXCaptcha.bundle
```

如果 bundle 缺失（例如被打进了 `Frameworks/dxcaptcha_flutter.framework/` 内部），
需要插件 podspec 声明 `static_framework = true`（已默认设置），然后重新执行
`pod install` 并重新构建。bundle 缺失时插件会上报 `sdk_resource_missing` 错误，
可通过日志快速定位。

另一个触发 `load_fail` 的常见原因是 `protocol` 未配置：iOS SDK（v5.4.18r）低于
v5.4.21 时该参数必填，缺失时 SDK 可能按 `http` 请求资源被 ATS 拦截。插件已自动
注入默认值 `https:`，如需覆盖可通过 `extra: {'protocol': 'https:'}` 传入。

**iOS 链接报 `Undefined symbol: _OBJC_CLASS_$_DXCaptchaViewV5`**
见上文「符号链接插件的路径修正」。

## License

MIT
