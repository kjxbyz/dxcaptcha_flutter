import 'package:dxcaptcha_flutter/dxcaptcha_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DxCaptchaConfig', () {
    test('最小配置只序列化必填项与默认值', () {
      const DxCaptchaConfig config = DxCaptchaConfig(appId: 'app-id');
      final Map<String, Object?> map = config.toMap();

      expect(map['appId'], 'app-id');
      expect(map['privacy'], 'minimal');
      expect(map['cacheStorage'], true);
      expect(map['enableRiskSdk'], false);
      expect(map.containsKey('apiServer'), isFalse);
      expect(map.containsKey('language'), isFalse);
      expect(map.containsKey('width'), isFalse);
    });

    test('完整配置按 SDK 字段名序列化', () {
      final DxCaptchaConfig config = DxCaptchaConfig(
        appId: 'app-id',
        apiServer: 'https://cap.example.com',
        language: DxCaptchaLanguage.en,
        width: 300,
        bgColor: '#FFFFFF',
        customStyle: const <String, Object?>{
          'bar': <String, String>{'normalTextColor': '#3D5CC4'},
        },
        customLanguage: const <String, String>{'init_inform': '拖动一下'},
        timeout: const Duration(seconds: 8),
        showVoice: true,
        privacy: DxCaptchaPrivacy.full,
        enableCache: false,
        enableRiskSdk: true,
        extra: const <String, Object?>{'keyURL': 'https://key.example.com'},
      );
      final Map<String, Object?> map = config.toMap();

      expect(map['apiServer'], 'https://cap.example.com');
      expect(map['language'], 'en');
      expect(map['width'], 300);
      expect(map['bgColor'], '#FFFFFF');
      expect(map['customStyle'], isA<Map<String, Object?>>());
      expect(map['customLanguage'], isA<Map<String, String>>());
      expect(map['timeout'], 8000);
      expect(map['showVoice'], true);
      expect(map['privacy'], 'full');
      expect(map['cacheStorage'], false);
      expect(map['enableRiskSdk'], true);
      expect(map['keyURL'], 'https://key.example.com');
    });

    test('copyWith 保留未覆盖字段', () {
      const DxCaptchaConfig base = DxCaptchaConfig(
        appId: 'app-id',
        width: 300,
      );
      final DxCaptchaConfig copy = base.copyWith(language: DxCaptchaLanguage.en);

      expect(copy.appId, 'app-id');
      expect(copy.width, 300);
      expect(copy.language, DxCaptchaLanguage.en);
      expect(copy.enableRiskSdk, false);
    });

    test('copyWith 可覆盖 enableRiskSdk', () {
      const DxCaptchaConfig base = DxCaptchaConfig(appId: 'app-id');
      expect(base.copyWith(enableRiskSdk: true).enableRiskSdk, true);
    });
  });

  group('DxCaptchaEventType.parse', () {
    test('识别标准事件名', () {
      expect(DxCaptchaEventType.parse('success'), DxCaptchaEventType.success);
      expect(DxCaptchaEventType.parse('fail'), DxCaptchaEventType.fail);
      expect(DxCaptchaEventType.parse('ready'), DxCaptchaEventType.ready);
      expect(DxCaptchaEventType.parse('load_fail'), DxCaptchaEventType.loadFail);
    });

    test('兼容驼峰、大写与 SDK 枚举写法', () {
      expect(
        DxCaptchaEventType.parse('DXCaptchaEventVerifySuccess'),
        DxCaptchaEventType.verifySuccess,
      );
      expect(DxCaptchaEventType.parse('VerifyDone'), DxCaptchaEventType.verifyDone);
      expect(DxCaptchaEventType.parse('pass-by-server'), DxCaptchaEventType.passByServer);
    });

    test('未知事件归入 unknown', () {
      expect(DxCaptchaEventType.parse('something-new'), DxCaptchaEventType.unknown);
      expect(DxCaptchaEventType.parse(null), DxCaptchaEventType.unknown);
      expect(DxCaptchaEventType.parse(''), DxCaptchaEventType.unknown);
    });
  });
}
