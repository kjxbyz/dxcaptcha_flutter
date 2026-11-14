# 放置顶象 Android SDK

把从顶象控制台下载的 aar 放到本目录（`android/libs/`），文件名保持原样即可被自动识别：

- `dx-captcha-without-risk-vX.X.X.aar` —— 不含设备指纹，推荐
- `dx-captcha-vX.X.X.aar` —— 含设备指纹，需要同时放入 `dx-risk-*.aar`

本目录下的 `*.aar` / `*.jar` 会通过 `fileTree` 自动参与编译，无需修改 Gradle 配置。
