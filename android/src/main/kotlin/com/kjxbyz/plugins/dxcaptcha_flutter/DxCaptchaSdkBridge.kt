package com.kjxbyz.plugins.dxcaptcha_flutter

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
 * 对顶象 Android SDK 的反射封装，对齐官方文档
 * https://www.dingxiang-inc.com/docs/detail/captcha 的 v5 接入方式：
 *
 * ```java
 * DXCaptchaView.setAllowPrivacyList(PrivacyFlag.DEFALUT);
 * DXCaptchaViewV5 captcha = (DXCaptchaViewV5) findViewById(R.id.captcha);
 * captcha.init(appId);
 * dxCaptcha.startToLoad(listener, "success", "fail");
 * ```
 *
 * 采用反射而不是直接依赖 SDK 类型，原因有两点：
 * 1. 不同版本的 aar 把验证码类放在不同的包名/类名下（DXCaptchaViewV5 / DXCaptchaView），
 *    直接 import 会让插件绑定到某一个具体版本；
 * 2. 未放入 aar 时插件依然可以编译，错误以 [DxCaptchaSdkException] 的形式在 Dart 侧
 *    显示为可读提示，而不是整个工程编译失败。
 *
 * 若你的 aar 版本 API 有差异，只需要调整本文件顶部的候选名单即可。
 */
internal object DxCaptchaSdkBridge {
    private const val TAG = "DxCaptchaSdk"

    /** 不同版本 SDK 的包名候选，按顺序探测（v5 文档为 com.dx.mobile.captcha）。 */
    private val packageCandidates =
        listOf(
            "com.dx.mobile.captcha",
            "com.dingxiang.mobile.captcha",
        )

    /** 验证码视图类名候选：v5.x 为 DXCaptchaViewV5，旧版为 DXCaptchaView。 */
    private val viewClassCandidates =
        listOf(
            "DXCaptchaViewV5",
            "DXCaptchaView",
        )

    /**
     * PrivacyFlag 所在位置候选。实测 v5.4.27r 中该接口位于
     * `com.dx.mobile.risk.PrivacyFlag`（常量为 long：DEFAULT=0、ALL=-1），
     * 而非验证码包本身；不含指纹的 aar 中没有此类。
     */
    private val privacyClassCandidates =
        listOf(
            "com.dx.mobile.risk.PrivacyFlag",
            "com.dx.mobile.risk.dx.PrivacyFlag",
            "com.dx.mobile.captcha.PrivacyFlag",
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
            for (name in viewClassCandidates) {
                val viewClass =
                    try {
                        Class.forName("$pkg.$name")
                    } catch (_: ClassNotFoundException) {
                        continue
                    }
                val listenerClass =
                    runCatching { Class.forName("$pkg.DXCaptchaListener") }.getOrNull()
                val privacyClass =
                    privacyClassCandidates.firstNotNullOfOrNull { name ->
                        runCatching { Class.forName(name) }.getOrNull()
                    }
                Log.i(TAG, "已找到顶象 SDK: $pkg.$name")
                return SdkClasses(viewClass, listenerClass, privacyClass)
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
                    "创建 DXCaptchaViewV5 失败：${error.message}",
                )
            }

        applyPrivacyIfNeeded(classes, view, config)
        applyInit(classes, view, appId, config)
        return view
    }

    /**
     * 开始加载验证码，事件通过 [onEvent] 回调。
     *
     * 回调参数为 SDK 原始事件名（success / fail / ...）与事件负载。
     *
     * 文档写法为 `startToLoad(listener, "success", "fail")`，其中 extraEvents 是
     * varargs（编译后签名 `(DXCaptchaListener, String[])`）；v5.1.5r 之前只有
     * `startToLoad(listener)`，这里两种签名都兼容。
     */
    fun load(view: View, onEvent: (String, Map<String, Any?>) -> Unit) {
        val classes = sdk ?: return
        val listenerClass = classes.listenerClass

        if (listenerClass != null) {
            val method = findStartToLoad(view, listenerClass)
            if (method != null) {
                val listener = newListenerProxy(listenerClass, onEvent)
                try {
                    if (method.isVarArgs && method.parameterTypes.size == 2) {
                        // startToLoad(listener, vararg extraEvents)
                        method.invoke(view, listener, arrayOf("success", "fail"))
                    } else {
                        method.invoke(view, listener)
                    }
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
            // 罗列实际可见的方法，便于定位 aar 版本或旧构建残留问题。
            val startToLoadLike =
                view.javaClass.methods.filter { it.name.contains("start", ignoreCase = true) }
                    .joinToString { "${it.name}(${it.parameterTypes.joinToString { p -> p.simpleName }})" }
            throw DxCaptchaSdkException(
                "init_failed",
                "SDK(${view.javaClass.name}) 未提供可用的 startToLoad 方法，请确认 aar 版本。" +
                    "可见的 start* 方法：[${startToLoadLike.ifEmpty { "无" }}]",
            )
        }
    }

    /**
     * 动态代理 [DXCaptchaListener]，文档定义的回调签名：
     * `handleEvent(View view, String event, Map<String, String> args)`。
     */
    private fun newListenerProxy(
        listenerClass: Class<*>,
        onEvent: (String, Map<String, Any?>) -> Unit,
    ): Any =
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

    /**
     * 查找 startToLoad 方法，兼容三种签名：
     * `startToLoad(listener)`、`startToLoad(listener, vararg extraEvents)`、
     * 以及部分版本把 listener 参数声明成具体实现类型的情况。
     */
    private fun findStartToLoad(view: View, listenerClass: Class<*>): Method? =
        view.javaClass.methods.firstOrNull { method ->
            method.name == "startToLoad" &&
                method.parameterTypes.isNotEmpty() &&
                method.parameterTypes[0].isAssignableFrom(listenerClass)
        }

    /**
     * 是否加载设备指纹（风控）SDK。Dart 侧 `enableRiskSdk` 默认 false，
     * 对应官方文档「最小化使用，不需要集成顶象设备指纹（风控）SDK」。
     */
    private fun isRiskSdkEnabled(config: Map<String, Any?>): Boolean =
        config["enableRiskSdk"] as? Boolean ?: false

    private fun applyPrivacyIfNeeded(
        classes: SdkClasses,
        view: View,
        config: Map<String, Any?>,
    ) {
        // 最小化模式（enableRiskSdk=false）下不调用 setAllowPrivacyList：
        // 1. 官方最小化示例本身省略了该调用；
        // 2. 字节码层面它是无条件调用 DXRisk.setAllowPrivacyList，工程未集成
        //    dx-risk 时会抛 NoClassDefFoundError。
        if (!isRiskSdkEnabled(config)) {
            return
        }
        applyPrivacy(classes, view, config)
    }

    /**
     *
     * 实测 v5.4.27r 的真实签名是 `DXCaptchaView.setAllowPrivacyList(long)`，
     * 文档示例 `PrivacyFlag.DEFALUT` 的常量在 com.dx.mobile.risk.PrivacyFlag 中
     * 定义为 DEFAULT=0（仅采集必要信息）、ALL=-1（全部）。含指纹 aar 里能取到
     * 常量类就用常量，取不到（如 without-risk aar）则直接回退到这两个数值。
     */
    private fun applyPrivacy(
        classes: SdkClasses,
        view: View,
        config: Map<String, Any?>,
    ) {
        val full = config["privacy"] == "full"

        var flagValue: Long = if (full) -1L else 0L
        var flagObject: Any? = null

        classes.privacyClass?.let { privacyClass ->
            // 文档示例写 DEFALUT（拼写与 SDK 不一致），两个候选都覆盖。
            val constantNames =
                if (full) listOf("ALL", "FULL", "DEFAULT", "DEFALUT")
                else listOf("DEFAULT", "DEFALUT")
            val field = constantNames.firstNotNullOfOrNull { name ->
                runCatching { privacyClass.getField(name) }.getOrNull()
            }
            if (field != null) {
                flagObject = field.get(null)
                (flagObject as? Number)?.let { flagValue = it.toLong() }
            }
        }

        val method =
            classes.viewClass.methods.firstOrNull { candidate ->
                candidate.name == "setAllowPrivacyList" &&
                    candidate.parameterTypes.size == 1
            } ?: return

        val paramType = method.parameterTypes[0]
        val argument =
            when {
                paramType == Long::class.javaPrimitiveType -> flagValue
                paramType == Long::class.java -> java.lang.Long.valueOf(flagValue)
                classes.privacyClass != null &&
                    paramType.isAssignableFrom(classes.privacyClass) &&
                    flagObject != null -> flagObject
                else -> flagValue
            }

        try {
            val target = if (Modifier.isStatic(method.modifiers)) null else view
            method.invoke(target, argument)
        } catch (error: Throwable) {
            Log.w(TAG, "setAllowPrivacyList 调用失败", error)
        }
    }

    /**
     * 文档写法 `captcha.init(appId)`；自定义配置通过 initConfig(Map) 传入。
     */
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

        // 官方「最小化使用」配置（https://www.dingxiang-inc.com/docs/detail/captcha）：
        // enableRiskSdk=false 时告知 SDK 不加载设备指纹，并通知服务端不等待设备指纹。
        // 字节码确认 startToLoad 内的 DXRisk 调用受 DXKeyRiskEnable 开关保护，
        // 为 false 时不会触碰 DXRisk 类，工程无需集成 dx-risk aar。
        if (!isRiskSdkEnabled(config)) {
            result["DXKeyRiskEnable"] = false
            result["wait_for_const_id_sdk"] = false
        }

        // 透传其余参数（私有化部署的 keyURL、ua_js 等）。
        val reserved =
            setOf(
                "appId", "apiServer", "language", "cacheStorage", "timeout",
                "showVoice", "customStyle", "customLanguage", "bgColor",
                "style", "width", "privacy", "scriptUrl", "enableRiskSdk",
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
