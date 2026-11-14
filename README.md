# dxcaptcha_flutter

顶象无感验证码（DingXiang Captcha）Flutter 插件，支持 **iOS / Android / Web**，
提供 **嵌入组件** 与 **全屏弹窗** 两种接入方式，三端共用一套 Dart API。

- 统一的 `DxCaptcha` 组件，直接放进 Widget 树即可渲染验证码
- `DxCaptcha.show(context)` 一行代码弹出验证，返回结构化结果
- `DxCaptchaController` 管理状态、失败重试、读取 token
- 事件归一化：iOS / Android / Web 的事件名差异由插件内部抹平
- 内置加载/错误占位、中文/英文界面、私有化部署参数透传

## 平台支持

| 能力 | iOS | Android | Web | 桌面端 |
| --- | --- | --- | --- | --- |
| 嵌入组件 | ✅ | ✅ | ✅ | 占位提示 |
| 弹窗模式 | ✅ | ✅ | ✅ | 占位提示 |
| 中文 / 英文 | ✅ | ✅ | ✅ | — |
| 私有化 apiServer | ✅ | ✅ | ✅ | — |

- iOS：`dx-captcha.xcframework` v5.4.18r（已随插件内置）
- Android：需自行下载 `dx-captcha-*.aar` 放入插件 `android/libs/`
- Web：自动从顶象 CDN 加载 v5 JS SDK，无需手动引入

## 环境要求

| 项目 | 版本 |
| --- | --- |
| Flutter | >= 3.27（示例工程用 FVM 固定在 3.35.7） |
| Dart | >= 3.9 |
| iOS | >= 15.0（Xcode 27 起模拟器最低 15.0） |
| Android | minSdk 24，compileSdk 36 |

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
出现空白（验证码区域全白），把 `DXCaptcha.bundle` 额外加入 Runner target 的
**Copy Bundle Resources**。

### Android

顶象不提供公开的 Maven 仓库，需要从控制台下载 aar：

1. 登录顶象控制台 → 无感验证 → SDK 下载
2. 把 `dx-captcha-without-risk-vX.X.X.aar`（推荐，不含设备指纹）放到
   `dxcaptcha_flutter/android/libs/` 目录
3. 重新构建，Gradle 会通过 `fileTree` 自动引入

```
dxcaptcha_flutter/
└── android/libs/
    ├── README.md
    └── dx-captcha-without-risk-v5.4.27.aar   ← 放这里
```

插件已内置：

- `INTERNET` / `ACCESS_NETWORK_STATE` 权限
- 顶象官方混淆规则（`android/consumer-rules.pro`）
- 对 SDK 的反射调用封装，未放入 aar 时不会编译失败，而是在 Dart 侧返回
  `sdk_unavailable` 的可读错误

> 若你的 aar 包名与方法签名与默认候选不同，只需调整
> `android/src/main/kotlin/.../DxCaptchaSdkBridge.kt` 顶部的 `packageCandidates`。

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

DxCaptcha(
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
final DxCaptchaResult? result = await DxCaptcha.show(
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

DxCaptcha(
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
  timeout: const Duration(minutes: 1),
);
```

## API

### DxCaptchaConfig

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `appId` | `String` | 必填，顶象控制台应用管理获取 |
| `apiServer` | `String?` | 私有化部署域名，SaaS 留空 |
| `language` | `DxCaptchaLanguage?` | `zh` / `en` |
| `style` | `DxCaptchaStyle` | 仅 Web 生效：`embed` / `inline` / `popup` / `oneclick` |
| `width` | `int?` | 验证码控件宽度（像素） |
| `bgColor` | `String?` | 控件背景色，如 `#FFFFFF` |
| `customStyle` | `Map` | 对应 SDK `customStyle` |
| `customLanguage` | `Map` | 对应 SDK `customLanguage` |
| `timeout` | `Duration?` | 请求超时，默认 6 秒 |
| `showVoice` | `bool?` | 是否展示语音验证入口 |
| `privacy` | `DxCaptchaPrivacy` | 隐私采集白名单：`minimal` / `full` |
| `enableCache` | `bool` | 无感验证结果缓存（iOS 忽略） |
| `extra` | `Map` | 透传参数，如私有化 `keyURL`、`ua_js`、`scriptUrl` |

### DxCaptchaResult

| 成员 | 说明 |
| --- | --- |
| `type` | `DxCaptchaEventType`，归一化后的事件类型 |
| `token` | 验证通过凭证，仅 `success` 时有值 |
| `message` | 失败原因 |
| `isSuccess` | `type == success && token != null` |
| `isFailure` | 是否验证失败 |
| `rawEvent` | 原生层原始事件名，便于排查 |
| `raw` | 原生层完整负载 |

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
aar 未放入 `android/libs/`，或放入后没有重新执行 `flutter clean`。

**token 以 `sl` 开头**
这是前端网络不通时的降级 token，说明设备无法直连 `apiServer`，需要检查网络或
私有化域名配置。

**iOS 链接报 `Undefined symbol: _OBJC_CLASS_$_DXCaptchaViewV5`**
见上文「符号链接插件的路径修正」。

## License

MIT
