# ChangeLog

## 0.0.2-dev.1

* 移除 Web 平台支持
* 新增粤语界面语言（`DxCaptchaLanguage.yue`），示例语言切换改为 中文 / 粤语 / English 三选

## 0.0.2-dev.0

* 新增 `DxCaptcha` 嵌入组件与 `DxCaptcha.show()` 弹窗模式，三端共用一套 API
* 新增 `DxCaptchaController`，支持状态读取、失败重载与 `waitForResult`
* iOS：内置 `dx-captcha.xcframework` v5.4.18r 与 `DXCaptcha.bundle`，
  通过 PlatformView 承载 `DXCaptchaViewV5`
* Android：通过反射桥接 `DXCaptchaViewV5`（按官方 v5 文档对齐
  `init(appId)` / `startToLoad(listener, vararg)` / `setAllowPrivacyList` 签名），
  兼容不同 aar 包名，未集成 aar 时返回可读错误而非编译失败
* Android：内置官方 `dx-captcha-without-risk-v5.4.27r.aar`，默认按官方「最小化使用」
  运行（`enableRiskSdk: false`）：自动传入 `DXKeyRiskEnable=false` 与
  `wait_for_const_id_sdk=false` 并跳过 `setAllowPrivacyList`，无需集成风控 SDK；
  设为 `true` 时须自行提供 `dx-risk-*.aar`（字节码确认 DXRisk 调用受
  `DXKeyRiskEnable` 开关保护）。Gradle 配置期自动解包本地 aar
  （classes.jar / assets / jni / libs），规避 AGP 对库模块直接依赖本地 aar 的限制；
  补充 `packaging.jniLibs.keepDebugSymbols` 保留风控 so
* 事件归一化：补充 Android `onCaptchaJsLoaded` / `onCaptchaJsLoadFail` 映射；
  `DXCaptchaEventVerifySuccess`、`pass-by-server` 等写法统一映射

## 0.0.1+1

* refactor: moved to monorepo.

## 0.0.1

* chore: 0.0.1.
