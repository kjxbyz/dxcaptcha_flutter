/// 插件层的统一异常类型。
///
/// 原生 SDK 未集成、初始化失败、通道调用失败等情况都会抛出该异常，
/// 通过 [code] 区分具体原因。
class DxCaptchaException implements Exception {
  /// 创建异常。
  const DxCaptchaException(this.code, this.message, {this.cause});

  /// 原生 SDK 未找到，通常是 Android 未把 aar 放进 `libs` 目录。
  static const String sdkUnavailable = 'sdk_unavailable';

  /// SDK 初始化失败，多为 appId 非法或方法签名不匹配。
  static const String initFailed = 'init_failed';

  /// 通道调用失败。
  static const String platformError = 'platform_error';

  /// 当前平台不支持。
  static const String unsupported = 'unsupported';

  /// 组件已销毁。
  static const String disposed = 'disposed';

  /// 错误码。
  final String code;

  /// 可读的错误描述。
  final String message;

  /// 底层原始错误。
  final Object? cause;

  @override
  String toString() => 'DxCaptchaException($code): $message';
}
