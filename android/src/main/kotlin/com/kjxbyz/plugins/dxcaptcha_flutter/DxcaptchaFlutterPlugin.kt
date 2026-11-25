package com.kjxbyz.plugins.dxcaptcha_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * 顶象无感验证码 Flutter 插件 Android 端入口。
 *
 * 只负责注册 PlatformView 工厂，实际的验证码生命周期由
 * [DxCaptchaPlatformView] 管理。
 */
class DxcaptchaFlutterPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            DX_CAPTCHA_VIEW_TYPE,
            DxCaptchaViewFactory(binding.binaryMessenger),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // 视图资源由各自的 PlatformView.dispose() 释放，这里无需额外处理。
    }
}
