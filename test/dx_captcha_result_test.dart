import 'package:dxcaptcha_flutter/dxcaptcha_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DxCaptchaResult.fromMap', () {
    test('解析成功事件并裁剪 token 空白', () {
      final DxCaptchaResult result = DxCaptchaResult.fromMap(<Object?, Object?>{
        'event': 'success',
        'token': '  abc123  ',
      });

      expect(result.type, DxCaptchaEventType.success);
      expect(result.token, 'abc123');
      expect(result.normalizedToken, 'abc123');
      expect(result.isSuccess, isTrue);
      expect(result.rawEvent, 'success');
    });

    test('成功事件缺少 token 时不算成功', () {
      final DxCaptchaResult result = DxCaptchaResult.fromMap(<Object?, Object?>{
        'event': 'success',
      });

      expect(result.type, DxCaptchaEventType.success);
      expect(result.token, isNull);
      expect(result.isSuccess, isFalse);
    });

    test('解析失败事件并保留错误信息', () {
      final DxCaptchaResult result = DxCaptchaResult.fromMap(<Object?, Object?>{
        'event': 'fail',
        'message': '验证未通过',
      });

      expect(result.type, DxCaptchaEventType.fail);
      expect(result.isFailure, isTrue);
      expect(result.message, '验证未通过');
    });

    test('空 token 归一化为 null', () {
      final DxCaptchaResult result = DxCaptchaResult.fromMap(<Object?, Object?>{
        'event': 'success',
        'token': '   ',
      });

      expect(result.token, isNull);
      expect(result.normalizedToken, isNull);
    });

    test('保留原始负载便于排查', () {
      final DxCaptchaResult result = DxCaptchaResult.fromMap(<Object?, Object?>{
        'event': 'ready',
        'extra': 42,
      });

      expect(result.raw['extra'], 42);
    });
  });
}
