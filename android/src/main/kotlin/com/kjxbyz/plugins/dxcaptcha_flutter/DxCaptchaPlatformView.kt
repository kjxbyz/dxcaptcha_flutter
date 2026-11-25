package com.kjxbyz.plugins.dxcaptcha_flutter

import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

internal const val DX_CAPTCHA_VIEW_TYPE = "dxcaptcha_flutter/view"
internal const val DX_CAPTCHA_CHANNEL_PREFIX = "dxcaptcha_flutter/view_"

/**
 * 承载顶象验证码 SDK 视图的 PlatformView。
 *
 * Flutter 侧通过 `dxcaptcha_flutter/view_<viewId>` 通道下发 reload / dispose，
 * 原生侧通过 `onEvent` / `onError` 回传验证事件。
 */
class DxCaptchaPlatformView(
    private val context: Context,
    viewId: Int,
    private val config: Map<String, Any?>,
    messenger: BinaryMessenger,
) : PlatformView {
    private companion object {
        const val TAG = "DxCaptchaView"
    }

    private val container =
        FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setBackgroundColor(Color.TRANSPARENT)
        }

    private val channel = MethodChannel(messenger, "$DX_CAPTCHA_CHANNEL_PREFIX$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())

    private var sdkView: View? = null
    private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "reload" -> {
                    createCaptcha()
                    result.success(null)
                }

                "dispose" -> {
                    dispose()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // 等 Flutter 首次布局完成后再创建 SDK 视图，避免以 0 尺寸渲染。
        container.post { createCaptcha() }
    }

    override fun getView(): View = container

    private fun createCaptcha() {
        if (disposed) {
            return
        }
        removeSdkView()

        if (!DxCaptchaSdkBridge.isAvailable) {
            sendError(
                "sdk_unavailable",
                "未找到顶象验证码 SDK，请把 dx-captcha-*.aar 放入插件 android/libs 目录后重新构建",
            )
            return
        }

        try {
            val view = DxCaptchaSdkBridge.createView(context, config)
            container.addView(
                view,
                FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT,
                ),
            )
            sdkView = view
            DxCaptchaSdkBridge.load(view) { event, payload -> dispatchEvent(event, payload) }
        } catch (error: DxCaptchaSdkException) {
            Log.e(TAG, "初始化失败: ${error.message}", error)
            sendError(error.code, error.message)
        } catch (error: Throwable) {
            Log.e(TAG, "初始化失败", error)
            sendError("init_failed", "验证码初始化失败：${error.message}")
        }
    }

    private fun removeSdkView() {
        sdkView?.let { view ->
            runCatching {
                (view.parent as? ViewGroup)?.removeView(view)
            }
            runCatching {
                view.javaClass.getMethod("destroy").invoke(view)
            }
        }
        sdkView = null
        container.removeAllViews()
    }

    private fun dispatchEvent(event: String, payload: Map<String, Any?>) {
        if (disposed) {
            return
        }
        val arguments = HashMap<String, Any?>(payload)
        arguments["event"] = event
        mainHandler.post {
            if (!disposed) {
                channel.invokeMethod("onEvent", arguments)
            }
        }
    }

    private fun sendError(code: String, message: String) {
        if (disposed) {
            return
        }
        mainHandler.post {
            if (!disposed) {
                channel.invokeMethod("onError", mapOf("code" to code, "message" to message))
            }
        }
    }

    override fun dispose() {
        if (disposed) {
            return
        }
        disposed = true
        channel.setMethodCallHandler(null)
        removeSdkView()
    }
}

/**
 * 创建 [DxCaptchaPlatformView] 的工厂。
 */
class DxCaptchaViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val config = (args as? Map<String, Any?>) ?: emptyMap()
        return DxCaptchaPlatformView(context, viewId, config, messenger)
    }
}
