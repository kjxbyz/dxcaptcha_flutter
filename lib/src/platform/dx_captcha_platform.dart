import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../models/dx_captcha_config.dart';
import '../models/dx_captcha_exception.dart';
import '../models/dx_captcha_result.dart';
import 'dx_captcha_method_channel.dart';

/// 由平台实现创建的句柄，供 [DxCaptchaController] 操控验证码实例。
abstract class DxCaptchaDriver {
  /// 销毁当前验证码实例并重新加载。
  Future<void> reload();

  /// 释放原生资源。
  Future<void> dispose();

  /// 是否已经绑定到底层视图。
  bool get isAttached;
}

/// 构建平台视图所需的参数集合。
class DxCaptchaViewParams {
  /// 创建参数集合。
  const DxCaptchaViewParams({
    required this.config,
    required this.onResult,
    required this.onError,
    required this.onDriverCreated,
  });

  /// 验证码配置。
  final DxCaptchaConfig config;

  /// 收到验证码事件时回调。
  final ValueChanged<DxCaptchaResult> onResult;

  /// 原生层报错时回调。
  final ValueChanged<DxCaptchaException> onError;

  /// 视图创建完成后回调，用于把 driver 交给控制器。
  final ValueChanged<DxCaptchaDriver> onDriverCreated;
}

/// 各平台实现的公共契约。
abstract class DxCaptchaPlatform extends PlatformInterface {
  /// 构造平台实现。
  DxCaptchaPlatform() : super(token: _token);

  static final Object _token = Object();

  static DxCaptchaPlatform _instance = MethodChannelDxCaptcha();

  /// 当前生效的平台实现。
  static DxCaptchaPlatform get instance => _instance;

  /// 由具体平台实现替换默认实例。
  static set instance(DxCaptchaPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 构建承载验证码的 Widget。
  Widget buildView(DxCaptchaViewParams params);
}
