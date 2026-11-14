import 'package:dxcaptcha_flutter/dxcaptcha_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDriver implements DxCaptchaDriver {
  int reloadCount = 0;
  int disposeCount = 0;
  bool _attached = true;

  @override
  bool get isAttached => _attached;

  @override
  Future<void> reload() async {
    reloadCount++;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _attached = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DxCaptchaController 状态流转', () {
    late DxCaptchaController controller;
    late _FakeDriver driver;

    setUp(() {
      controller = DxCaptchaController();
      driver = _FakeDriver();
    });

    tearDown(() {
      controller.dispose();
    });

    test('初始状态为 idle', () {
      expect(controller.state, DxCaptchaState.idle);
      expect(controller.token, isNull);
      expect(controller.isAttached, isFalse);
    });

    test('绑定驱动后进入 loading', () {
      controller.attachDriver(driver);
      expect(controller.state, DxCaptchaState.loading);
      expect(controller.isAttached, isTrue);
    });

    test('ready 事件后进入 ready', () {
      controller.attachDriver(driver);
      controller.dispatchResult(
        const DxCaptchaResult(type: DxCaptchaEventType.ready, rawEvent: 'ready'),
      );
      expect(controller.state, DxCaptchaState.ready);
    });

    test('success 事件携带 token 并置为已验证', () {
      controller.attachDriver(driver);
      controller.dispatchResult(
        const DxCaptchaResult(
          type: DxCaptchaEventType.success,
          token: 'token-1',
          rawEvent: 'success',
        ),
      );

      expect(controller.state, DxCaptchaState.success);
      expect(controller.isVerified, isTrue);
      expect(controller.token, 'token-1');
    });

    test('fail 事件置为失败', () {
      controller.attachDriver(driver);
      controller.dispatchResult(
        const DxCaptchaResult(
          type: DxCaptchaEventType.fail,
          message: '验证未通过',
          rawEvent: 'fail',
        ),
      );

      expect(controller.state, DxCaptchaState.fail);
      expect(controller.lastResult?.message, '验证未通过');
    });

    test('reload 清空结果并调用驱动', () async {
      controller.attachDriver(driver);
      controller.dispatchResult(
        const DxCaptchaResult(
          type: DxCaptchaEventType.success,
          token: 'token-1',
          rawEvent: 'success',
        ),
      );

      await controller.reload();

      expect(driver.reloadCount, 1);
      expect(controller.token, isNull);
      expect(controller.state, DxCaptchaState.loading);
    });

    test('未挂载时 reload 抛出异常', () async {
      await expectLater(
        controller.reload(),
        throwsA(
          isA<DxCaptchaException>().having(
            (DxCaptchaException e) => e.code,
            'code',
            DxCaptchaException.initFailed,
          ),
        ),
      );
    });

    test('dispose 释放驱动', () async {
      controller.attachDriver(driver);
      controller.dispose();

      expect(driver.disposeCount, 1);
      expect(controller.state, DxCaptchaState.disposed);
    });
  });

  group('DxCaptchaController.waitForResult', () {
    test('在 success 事件到达后完成', () async {
      final DxCaptchaController controller = DxCaptchaController();
      final _FakeDriver driver = _FakeDriver();
      controller.attachDriver(driver);

      final Future<DxCaptchaResult> pending = controller.waitForResult();
      controller.dispatchResult(
        const DxCaptchaResult(
          type: DxCaptchaEventType.success,
          token: 'token-2',
          rawEvent: 'success',
        ),
      );

      final DxCaptchaResult result = await pending;
      expect(result.token, 'token-2');
      controller.dispose();
    });

    test('超时返回 unknown 结果而不是抛异常', () async {
      final DxCaptchaController controller = DxCaptchaController();
      controller.attachDriver(_FakeDriver());

      final DxCaptchaResult result = await controller.waitForResult(
        timeout: const Duration(milliseconds: 20),
      );

      expect(result.type, DxCaptchaEventType.unknown);
      expect(result.rawEvent, 'timeout');
      controller.dispose();
    });
  });
}
