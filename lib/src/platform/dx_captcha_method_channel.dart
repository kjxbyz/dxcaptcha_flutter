import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/dx_captcha_exception.dart';
import '../models/dx_captcha_result.dart';
import 'dx_captcha_platform.dart';

/// 基于 PlatformView + MethodChannel 的移动端实现。
///
/// 每个验证码实例都会创建一条独立通道 `dxcaptcha_flutter/view_<viewId>`，
/// 原生层通过该通道回传验证过程中产生的事件。
class MethodChannelDxCaptcha extends DxCaptchaPlatform {
  /// 原生视图注册名，需与 Android / iOS 侧保持一致。
  static const String viewType = 'dxcaptcha_flutter/view';

  /// 通道名前缀。
  static const String channelPrefix = 'dxcaptcha_flutter/view_';

  @override
  Widget buildView(DxCaptchaViewParams params) {
    // OpenHarmony 适配版 Flutter（Flutter-OH）下，平台视图通道协议与
    // Android 完全一致（create / touch / dispose 消息同构，direction 编码
    // 相同），因此直接复用 AndroidView。标准 Flutter SDK 中
    // Platform.operatingSystem 不会返回 'ohos'，该分支永不命中。
    if (Platform.operatingSystem == 'ohos') {
      return AndroidView(
        viewType: viewType,
        creationParams: params.config.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) => bindView(id, params),
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        creationParams: params.config.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) => bindView(id, params),
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: viewType,
        creationParams: params.config.toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) => bindView(id, params),
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      );
    }

    return const _UnsupportedPlatformView();
  }

  void bindView(int viewId, DxCaptchaViewParams params) {
    final MethodChannel channel = MethodChannel('$channelPrefix$viewId');

    channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onEvent':
          final Object? arguments = call.arguments;
          if (arguments is Map) {
            params.onResult(DxCaptchaResult.fromMap(arguments));
          }
          break;
        case 'onError':
          final Object? arguments = call.arguments;
          final Map<Object?, Object?> data =
              arguments is Map ? arguments : const <Object?, Object?>{};
          params.onError(
            DxCaptchaException(
              '${data['code'] ?? DxCaptchaException.platformError}',
              '${data['message'] ?? '验证码初始化失败'}',
            ),
          );
          break;
        default:
          break;
      }
    });

    params.onDriverCreated(_ChannelDriver(channel));
  }
}

class _ChannelDriver implements DxCaptchaDriver {
  _ChannelDriver(this._channel);

  final MethodChannel _channel;
  bool _disposed = false;

  @override
  bool get isAttached => !_disposed;

  @override
  Future<void> reload() async {
    if (_disposed) {
      throw const DxCaptchaException(
        DxCaptchaException.disposed,
        '验证码组件已销毁，无法重新加载',
      );
    }
    await _invokeSafely('reload');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _invokeSafely('dispose');
  }

  /// 页面销毁过程中的通道调用失败不应影响业务流程。
  Future<void> _invokeSafely(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error, stack) {
      debugPrint('[dxcaptcha] $method 调用失败: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'dxcaptcha_flutter',
          context: ErrorDescription('调用原生方法 $method'),
        ),
      );
    } on MissingPluginException {
      // 原生实现未注册（例如宿主未重新构建），静默忽略。
    }
  }
}

class _UnsupportedPlatformView extends StatelessWidget {
  const _UnsupportedPlatformView();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '顶象验证码暂不支持当前平台，请使用 iOS / Android / OpenHarmony。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
            ),
          ),
        ),
      ),
    );
  }
}
