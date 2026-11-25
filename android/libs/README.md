# 顶象 Android SDK（已内置）

当前目录内置官方验证码 SDK `dx-captcha-without-risk-v5.4.27r.aar`（来源为顶象文档中心
公开下载地址）。

## 关于设备指纹（风控）SDK

插件默认按官方文档「最小化使用」运行：**不集成风控 SDK**，Dart 侧
`DxCaptchaConfig(enableRiskSdk: false)`（默认值）会让桥接自动传入：

```java
config.put("DXKeyRiskEnable", false);      // 不加载设备指纹SDK
config.put("wait_for_const_id_sdk", false); // 通知服务端不等待设备指纹
```

并跳过 `setAllowPrivacyList` 调用（官方最小化示例同样省略；且字节码层面该方法
无条件调用 `DXRisk.setAllowPrivacyList`，缺少 dx-risk 类时会抛 `NoClassDefFoundError`）。
此模式下**无需也不应**在 `libs/` 放入 `dx-risk-*.aar`。

> 注意：`dx-captcha-without-risk` 的 "without-risk" 仅指「不打包风控 SDK」，但
> `DXKeyRiskEnable` 默认为 true 时 `startToLoad` 内部仍会调用 `DXRisk`（字节码已确认
> 该调用受开关保护，`DXKeyRiskEnable=false` 时跳过）。插件已默认置 false，无需手动处理。

## 需要风控增强时

1. Dart 侧设置 `DxCaptchaConfig(enableRiskSdk: true)`
2. 把 `dx-risk-v*.aar`（官方 DEMO 包内提供，需与验证码 SDK 版本配对）放入本目录
3. `flutter clean && flutter build`
4. 隐私政策中按顶象合规指南声明风控 SDK 相关内容（采集范围由
   `DxCaptchaConfig.privacy` 控制，`minimal` 对应 `PrivacyFlag.DEFALUT=0`）

## 更换 / 升级 SDK 版本

1. 删除本目录下旧的 `dx-captcha-*.aar`
2. 放入新 aar（文件名保持官方原样）
3. 重新执行 `flutter clean && flutter build`（解包目录在 `build/` 下，clean 会重建）

## 注意

- 常规 `*.jar` 仍按 `fileTree` 直接引入，不受解包流程影响
- `.so` 同时兼容 aar 的 `jni/<abi>/` 与 `libs/<abi>/` 两种布局；`lib*Risk*.so`
  / `lib*Captcha*.so` 已按官方要求配置 keepDebugSymbols（doNotStrip）
- 反射桥接的候选包名/类名见
  `android/src/main/kotlin/com/kjxbyz/plugins/dxcaptcha_flutter/DxCaptchaSdkBridge.kt`
  顶部的 `packageCandidates` / `viewClassCandidates` / `privacyClassCandidates`
