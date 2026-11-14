package com.pcxx.dxcaptcha_flutter

import android.content.Context
import android.util.Log
import android.view.View
import java.lang.reflect.Method
import java.lang.reflect.Modifier
import java.lang.reflect.Proxy

/**
 * 顶象验证码 SDK 抛出的可读异常。
 */
internal class DxCaptchaSdkException(val code: String, override val message: String) :
    Exception(message)

/**
 * 对顶象 Android SDK 的反射封装。
 *
 * 采用反射而不是直接依赖 SDK 类型，原因有两点：
 * 1. 不同版本的 aar 把 `DXCaptchaView` 放在不同的包下（com.dingxiang.mobile.captcha /
 *    com.dx.mobile.captcha），直接 import 会让插件绑定到某一个具体版本；
 * 2. 未放入 aar 时插件依然可以编译，错误以 [DxCaptchaSdkException] 的形式在 Dart 侧
 *    显示为可读提示，而不是整个工程编译失败。
 *
 * 若你的 aar 版本 API 有差异，只需要调整本文件的候选包名与方法名即可。
 */
internal object DxCaptchaSdkBridge {
    private const val TAG = "DxCaptchaSdk"

    /** 不同版本 SDK 的包名候选，按顺序探测。 */
    private val packageCandidates =
        listOf(
            "com.dingxiang.mobile.captcha",
            "com.dx.mobile.captcha",
        )

    private class SdkClasses(
        val viewClass: Class<*>,
        val listenerClass: Class<*>?,
        val privacyClass: Class<*>?,
    )

    private val sdk: SdkClasses? by lazy { resolve() }

    /** SDK 是否可用。 */
    val isAvailable: Boolean
        get() = sdk != null

    private fun resolve(): SdkClasses? {
        for (pkg in packageCandidates) {
            try {
                val viewClass = Class.forName("$pkg.DXCaptchaView")
                val listenerClass =
                    runCatching { Class.forName("$pkg.DXCaptchaListener") }.getOrNull()
                val privacyClass =
                    runCatching { Class.forName("$pkg.PrivacyFlag") }.getOrNull()
                Log.i(TAG, "已找到顶象 SDK: $pkg")
                return SdkClasses(viewClass, listenerClass, privacyClass)
            } catch (_: ClassNotFoundException) {
                // 继续尝试下一个包名。
            }
        }
        Log.w(TAG, "未找到顶象验证码 SDK，请把 dx-captcha-*.aar 放入 android/libs")
        return null
    }

    /**
     * 创建并初始化验证码视图。
     *
     * @param config Dart 层透传的配置，键名与顶象文档保持一致。
     */
    fun createView(context: Context, config: Map<String, Any?>): View {
        val classes = sdk ?: throw DxCaptchaSdkException(
            "sdk_unavailable",
            "未找到顶象验证码 SDK，请把 dx-captcha-*.aar 放入插件 android/libs 目录后重新构建",
        )

        val appId = config["appId"] as? String
        if (appId.isNullOrEmpty()) {
            throw DxCaptchaSdkException("init_failed", "appId 不能为空")
        }

        val view =
            try {
                val ctor = classes.viewClass.getConstructor(Context::class.java)
                ctor.newInstance(context) as View
            } catch (error: Throwable) {
                throw DxCaptchaSdkException(
                    "init_failed",
                    "创建 DXCaptchaView 失败：${error.message}",
                )
            }

        applyPrivacy(classes, view, config)
        applyInit(classes, view, appId, config)
        return view
    }

    /**
     * 开始加载验证码，事件通过 [onEvent] 回调。
     *
     * 回调参数为 SDK 原始事件名（success / fail / ...）与事件负载。
     */
    fun load(view: View, onEvent: (String, Map<String, Any?>) -> Unit) {
        val classes = sdk ?: return
        val listenerClass = classes.listenerClass

        if (listenerClass != null) {
            val method = findMethod(view, "startToLoad", listenerClass)
            if (method != null) {
                val listener =
                    Proxy.newProxyInstance(
                        listenerClass.classLoader,
                        arrayOf(listenerClass),
                    ) { proxy, call, args ->
                        when (call.name) {
                            "handleEvent" -> {
                                val event = args?.getOrNull(1) as? String
                                val payload =
                                    (args?.getOrNull(2) as? Map<*, *>)?.let { toPlainMap(it) }
                                        ?: emptyMap()
                                if (!event.isNullOrEmpty()) {
                                    onEvent(event, payload)
                                }
                                null
                            }

                            "toString" -> "DxCaptchaListenerProxy"
                            "hashCode" -> System.identityHashCode(proxy)
                            "equals" -> proxy === args?.getOrNull(0)
                            else -> null
                        }
                    }
                try {
                    method.invoke(view, listener)
                    return
                } catch (error: Throwable) {
                    Log.w(TAG, "startToLoad(listener) 调用失败", error)
                }
            }
        }

        // 兜底：部分版本只提供无参 startToLoad()。
        val fallback = findMethod(view, "startToLoad")
        if (fallback != null) {
            fallback.invoke(view)
        } else {
            throw DxCaptchaSdkException(
                "init_failed",
                "SDK 未提供 startToLoad 方法，请确认 aar 版本",
            )
        }
    }

    private fun applyPrivacy(
        classes: SdkClasses,
        view: View,
        config: Map<String, Any?>,
    ) {
        val privacyClass = classes.privacyClass ?: return
        val constantName = if (config["privacy"] == "full") "ALL" else "DEFAULT"
        val flag =
            runCatching { privacyClass.getField(constantName).get(null) }.getOrNull()
                ?: return

        val method =
            classes.viewClass.methods.firstOrNull { candidate ->
                candidate.name == "setAllowPrivacyList" &&
                    candidate.parameterTypes.size == 1 &&
                    candidate.parameterTypes[0] == privacyClass
            } ?: return

        try {
            val target = if (Modifier.isStatic(method.modifiers)) null else view
            method.invoke(target, flag)
        } catch (error: Throwable) {
            Log.w(TAG, "setAllowPrivacyList 调用失败", error)
        }
    }

    private fun applyInit(
        classes: SdkClasses,
        view: View,
        appId: String,
        config: Map<String, Any?>,
    ) {
        val sdkConfig = buildSdkConfig(config)
        val initWithAppId = findMethod(view, "init", String::class.java)

        if (initWithAppId != null) {
            initWithAppId.invoke(view, appId)
            if (sdkConfig.isNotEmpty()) {
                val initConfig = findMethod(view, "initConfig", Map::class.java)
                if (initConfig != null) {
                    initConfig.invoke(view, sdkConfig)
                } else {
                    Log.w(TAG, "SDK 未提供 initConfig，忽略自定义配置 $sdkConfig")
                }
            }
            return
        }

        val initWithMap =
            findMethod(view, "initConfig", Map::class.java)
                ?: findMethod(view, "init", Map::class.java)
                ?: throw DxCaptchaSdkException(
                    "init_failed",
                    "SDK 未提供 init(String) 或 initConfig(Map) 方法，请确认 aar 版本",
                )
        sdkConfig["appId"] = appId
        initWithMap.invoke(view, sdkConfig)
        Log.i(TAG, "SDK 未提供 init(String)，已改用 initConfig(Map) 完成初始化")
    }

    /** 把 Dart 配置转换成 SDK 期望的 HashMap（SDK 内部按 HashMap 强转）。 */
    private fun buildSdkConfig(config: Map<String, Any?>): HashMap<String, Any> {
        val result = HashMap<String, Any>()

        (config["appId"] as? String)?.let { result["appId"] = it }
        (config["apiServer"] as? String)?.let { result["apiServer"] = it }
        (config["language"] as? String)?.let { result["language"] = it }
        (config["cacheStorage"] as? Boolean)?.let { result["cacheStorage"] = it }
        (config["timeout"] as? Number)?.let { result["timeout"] = it.toInt() }
        (config["showVoice"] as? Boolean)?.let { result["showVoice"] = it }

        @Suppress("UNCHECKED_CAST")
        (config["customStyle"] as? Map<String, Any?>)?.let { result["customStyle"] = toPlainMap(it) }
        @Suppress("UNCHECKED_CAST")
        (config["customLanguage"] as? Map<String, Any?>)?.let { result["customLanguage"] = toPlainMap(it) }

        // bgColor 是插件提供的便捷参数，统一归一到 SDK 的 customStyle.bgColor。
        (config["bgColor"] as? String)?.let { bg ->
            @Suppress("UNCHECKED_CAST")
            val style = result["customStyle"] as? HashMap<String, Any> ?: HashMap()
            if (!style.containsKey("bgColor")) {
                style["bgColor"] = bg
            }
            result["customStyle"] = style
        }

        // 透传其余参数（私有化部署的 keyURL、ua_js 等）。
        val reserved =
            setOf(
                "appId", "apiServer", "language", "cacheStorage", "timeout",
                "showVoice", "customStyle", "customLanguage", "bgColor",
                "style", "width", "privacy", "scriptUrl",
            )
        config.forEach { (key, value) ->
            if (key !in reserved && value != null) {
                result[key] = value
            }
        }

        return result
    }

    private fun toPlainMap(source: Map<*, *>): HashMap<String, Any?> {
        val map = HashMap<String, Any?>(source.size)
        source.forEach { (key, value) ->
            if (key is String) {
                map[key] = value
            }
        }
        return map
    }

    /**
     * 按名称与参数个数查找方法，兼容 SDK 把参数声明成 HashMap 等具体类型的情况。
     */
    private fun findMethod(target: Any, name: String, vararg argTypes: Class<*>): Method? =
        target.javaClass.methods.firstOrNull { method ->
            method.name == name &&
                method.parameterTypes.size == argTypes.size &&
                method.parameterTypes.zip(argTypes).all { (paramType, argType) ->
                    paramType.isAssignableFrom(argType) || argType.isAssignableFrom(paramType)
                }
        }
}
