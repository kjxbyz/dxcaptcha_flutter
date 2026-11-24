# ChangeLog

## next

* 新增 `DxCaptcha` 嵌入组件与 `DxCaptcha.show()` 弹窗模式，三端共用一套 API
* 新增 `DxCaptchaController`，支持状态读取、失败重载与 `waitForResult`
* iOS：内置 `dx-captcha.xcframework` v5.4.18r 与 `DXCaptcha.bundle`，
  通过 PlatformView 承载 `DXCaptchaViewV5`
* Android：通过反射桥接 `DXCaptchaView`，兼容不同 aar 包名，
  未集成 aar 时返回可读错误而非编译失败
* Web：自动加载顶象 v5 JS SDK（`_dx.Captcha`），支持自定义 CDN
* 事件归一化：`DXCaptchaEventVerifySuccess`、`pass-by-server` 等写法统一映射
* 补齐文档、示例工程、单元测试与混淆规则
* 文档拆分：`README.md` 为英文版（默认），`README_ZH.md` 为中文版

## 0.0.1+1

* refactor: moved to monorepo.

## 0.0.1

* chore: 0.0.1.
