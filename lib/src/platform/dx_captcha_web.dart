import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import '../models/dx_captcha_config.dart';
import '../models/dx_captcha_event.dart';
import '../models/dx_captcha_exception.dart';
import '../models/dx_captcha_result.dart';
import 'dx_captcha_platform.dart';

/// Web 端插件入口，由 Flutter 在启动时调用 [registerWith]。
class DxCaptchaWebPlugin {
  /// 注册 Web 平台实现。
  static void registerWith(Registrar registrar) {
    DxCaptchaPlatform.instance = DxCaptchaWeb();
  }
}

/// 官方 v5 JS SDK 的 CDN 地址。
///
/// 顶象要求直接引用 CDN 资源以便及时获得安全更新，不要自行下载托管。
const String kDxCaptchaScriptUrl =
    'https://cdn.dingxiang-inc.com/ctu-group/captcha-ui/v5/index.js';

/// 基于 `_dx.Captcha` JS SDK 的 Web 实现。
class DxCaptchaWeb extends DxCaptchaPlatform {
  static bool _scriptRequested = false;
  static Future<void>? _scriptLoading;

  /// 确保 JS SDK 已加载。
  static Future<void> ensureScriptLoaded([String url = kDxCaptchaScriptUrl]) {
    if (_dxNamespace != null) {
      return Future<void>.value();
    }
    return _scriptLoading ??= _loadScript(url);
  }

  static Future<void> _loadScript(String url) async {
    if (_scriptRequested) {
      // 已有一次加载在进行中，等待其完成后再次确认命名空间。
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return;
    }
    _scriptRequested = true;

    final Completer<void> completer = Completer<void>();
    final web.HTMLScriptElement script = web.HTMLScriptElement()
      ..src = url
      ..async = true
      ..crossOrigin = 'anonymous';

    script.addEventListener(
      'load',
      ((web.Event event) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }).toJS,
    );
    script.addEventListener(
      'error',
      ((web.Event event) {
        _scriptRequested = false;
        _scriptLoading = null;
        if (!completer.isCompleted) {
          completer.completeError(
            const DxCaptchaException(
              DxCaptchaException.initFailed,
              '顶象验证码 JS SDK 加载失败，请检查网络或自定义 scriptUrl',
            ),
          );
        }
      }).toJS,
    );

    web.document.head?.appendChild(script);

    return completer.future;
  }

  @override
  Widget buildView(DxCaptchaViewParams params) {
    final _WebDriver driver = _WebDriver(params);

    // 预热脚本，避免首帧空白。
    unawaited(
      ensureScriptLoaded(
        (params.config.extra['scriptUrl'] as String?) ?? kDxCaptchaScriptUrl,
      ).catchError((Object error) {
        params.onError(
          error is DxCaptchaException
              ? error
              : DxCaptchaException(
                  DxCaptchaException.initFailed,
                  '顶象验证码 JS SDK 加载失败',
                  cause: error,
                ),
        );
      }),
    );

    return _DxCaptchaHtmlView(driver: driver);
  }
}

class _DxCaptchaHtmlView extends StatefulWidget {
  const _DxCaptchaHtmlView({required this.driver});

  final _WebDriver driver;

  @override
  State<_DxCaptchaHtmlView> createState() => _DxCaptchaHtmlViewState();
}

class _DxCaptchaHtmlViewState extends State<_DxCaptchaHtmlView> {
  @override
  void initState() {
    super.initState();
    widget.driver.onAttached = () {
      widget.driver.attach();
    };
    widget.driver.owner = this;
  }

  @override
  void dispose() {
    widget.driver.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (Object element) {
        // fromTagName('div') 的契约就是返回 HTMLDivElement，直接转换即可。
        widget.driver.host = element as web.HTMLDivElement;
        widget.driver.attach();
      },
    );
  }
}

class _WebDriver implements DxCaptchaDriver {
  _WebDriver(this._params);

  final DxCaptchaViewParams _params;

  web.HTMLDivElement? host;
  JSObject? _instance;
  bool _disposed = false;
  bool _creating = false;

  /// 视图首次挂载后的回调钩子。
  VoidCallback? onAttached;

  /// 宿主 State，用于在异步创建失败后安全地回调。
  State? owner;

  DxCaptchaConfig get _config => _params.config;

  @override
  bool get isAttached => !_disposed && host != null;

  /// 在宿主 div 上创建 JS 实例。
  Future<void> attach() async {
    if (_disposed || _creating || _instance != null) {
      return;
    }
    final web.HTMLDivElement? element = host;
    if (element == null) {
      return;
    }

    _creating = true;
    try {
      await DxCaptchaWeb.ensureScriptLoaded(
        (_config.extra['scriptUrl'] as String?) ?? kDxCaptchaScriptUrl,
      );
      if (_disposed) {
        return;
      }
      _instance = _createInstance(element);
    } catch (error) {
      _params.onError(
        error is DxCaptchaException
            ? error
            : DxCaptchaException(
                DxCaptchaException.initFailed,
                '顶象验证码初始化失败：$error',
                cause: error,
              ),
      );
    } finally {
      _creating = false;
    }
  }

  JSObject _createInstance(web.HTMLDivElement element) {
    // 清空上一次渲染的节点，保证 reload 后是干净的容器。
    element.innerHTML = ''.toJS;

    final JSObject options = JSObject();
    options.setProperty('appId'.toJS, _config.appId.toJS);

    final String? apiServer = _config.apiServer;
    if (apiServer != null && apiServer.isNotEmpty) {
      options.setProperty('apiServer'.toJS, apiServer.toJS);
    }

    options.setProperty('style'.toJS, _config.style.value.toJS);

    final DxCaptchaLanguage? language = _config.language;
    if (language != null) {
      options.setProperty('language'.toJS, language.value.toJS);
    }

    final int? width = _config.width;
    if (width != null) {
      options.setProperty('width'.toJS, width.toJS);
    }

    final Map<String, Object?> customStyle = <String, Object?>{
      if (_config.bgColor != null) 'bgColor': _config.bgColor,
      ..._config.customStyle,
    };
    if (customStyle.isNotEmpty) {
      options.setProperty('customStyle'.toJS, customStyle.jsify());
    }

    if (_config.customLanguage.isNotEmpty) {
      options.setProperty(
        'customLanguage'.toJS,
        _config.customLanguage.jsify(),
      );
    }

    final Duration? timeout = _config.timeout;
    if (timeout != null) {
      options.setProperty('timeout'.toJS, timeout.inMilliseconds.toJS);
    }

    final bool? showVoice = _config.showVoice;
    if (showVoice != null) {
      options.setProperty('showVoice'.toJS, showVoice.toJS);
    }

    options.setProperty('cacheStorage'.toJS, _config.enableCache.toJS);

    options.setProperty(
      'success'.toJS,
      ((JSString token) {
        _emit(
          DxCaptchaResult(
            type: DxCaptchaEventType.success,
            token: token.toDart,
            rawEvent: 'success',
            raw: <String, Object?>{'event': 'success', 'token': token.toDart},
          ),
        );
      }).toJS,
    );

    options.setProperty(
      'fail'.toJS,
      ((JSAny? error) {
        final String message = error.dartify()?.toString() ?? '验证失败';
        _emit(
          DxCaptchaResult(
            type: DxCaptchaEventType.fail,
            message: message,
            rawEvent: 'fail',
            raw: <String, Object?>{'event': 'fail', 'message': message},
          ),
        );
      }).toJS,
    );

    // 透传其余参数（例如私有化部署的 keyURL、ua_js）。
    for (final MapEntry<String, Object?> entry in _config.extra.entries) {
      if (entry.key == 'scriptUrl') {
        continue;
      }
      options.setProperty(entry.key.toJS, entry.value.jsify());
    }

    final JSObject? namespace = _dxNamespace;
    if (namespace == null) {
      throw const DxCaptchaException(
        DxCaptchaException.sdkUnavailable,
        '页面上未找到 _dx 命名空间，请确认 JS SDK 已正确加载',
      );
    }

    final JSFunction? factory = namespace.getProperty<JSFunction?>(
      'Captcha'.toJS,
    );
    if (factory == null) {
      throw const DxCaptchaException(
        DxCaptchaException.sdkUnavailable,
        '_dx.Captcha 不存在，JS SDK 版本可能不匹配',
      );
    }

    final JSAny? created = factory.callAsFunction(element, options);

    if (created == null || !created.isA<JSObject>()) {
      return JSObject();
    }

    final JSObject instance = created as JSObject;

    // 部分版本的 _dx.Captcha 返回 Promise，需要等其 resolve 后才是实例。
    // 用鸭子类型判断 thenable，避免依赖具体 Promise 泛型。
    if (instance['then'] != null) {
      unawaited(
        (instance as JSPromise<JSAny?>).toDart.then((JSAny? value) {
          if (!_disposed && value != null && value.isA<JSObject>()) {
            _instance = value as JSObject;
          }
        }),
      );
      return instance;
    }

    return instance;
  }

  void _emit(DxCaptchaResult result) {
    if (_disposed) {
      return;
    }
    _params.onResult(result);
  }

  @override
  Future<void> reload() async {
    if (_disposed) {
      throw const DxCaptchaException(
        DxCaptchaException.disposed,
        '验证码组件已销毁，无法重新加载',
      );
    }
    _instance = null;
    final web.HTMLDivElement? element = host;
    if (element != null) {
      await attach();
    }
  }

  @override
  Future<void> dispose() async {
    destroy();
  }

  /// 释放 DOM 与 JS 实例。
  void destroy() {
    _disposed = true;
    _instance = null;
    host?.innerHTML = ''.toJS;
  }
}

@JS('_dx')
external JSObject? get _dxNamespace;
