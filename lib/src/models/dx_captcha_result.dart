import 'dx_captcha_event.dart';

/// 一次验证码交互的结果。
///
/// 通过 [DxCaptcha.onSuccess]、[DxCaptchaController.result] 或
/// [DxCaptcha.show] 获取。验证成功时 [token] 即后端二次校验所需的凭证。
class DxCaptchaResult {
  /// 创建验证结果。
  const DxCaptchaResult({
    required this.type,
    this.token,
    this.message,
    this.rawEvent,
    this.raw = const <String, Object?>{},
  });

  /// 事件类型。
  final DxCaptchaEventType type;

  /// 验证通过后的 token，仅在 [isSuccess] 为 true 时有值。
  ///
  /// 注意：以 `sl` 开头的 token 是前端网络不通时的降级 token，
  /// 上线前应与顶象确认是否需要拦截。
  final String? token;

  /// 失败或错误信息。
  final String? message;

  /// 原生层返回的原始事件名，便于排查未知事件。
  final String? rawEvent;

  /// 原生层返回的完整事件负载。
  final Map<String, Object?> raw;

  /// 是否验证成功。
  bool get isSuccess => type == DxCaptchaEventType.success && token != null;

  /// 是否验证失败。
  bool get isFailure => type == DxCaptchaEventType.fail;

  /// 归一化 token，剔除前后空白。
  String? get normalizedToken {
    final String? value = token?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// 从原生层回传的 Map 构造结果。
  factory DxCaptchaResult.fromMap(Map<Object?, Object?> map) {
    final Map<String, Object?> data = <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in map.entries)
        '${entry.key}': entry.value,
    };
    final String? rawEvent = data['event'] as String?;
    final String? token = (data['token'] as String?)?.trim();

    return DxCaptchaResult(
      type: DxCaptchaEventType.parse(rawEvent),
      token: (token == null || token.isEmpty) ? null : token,
      message: data['message'] as String?,
      rawEvent: rawEvent,
      raw: data,
    );
  }

  @override
  String toString() =>
      'DxCaptchaResult(type: ${type.value}, token: $token, message: $message)';
}
