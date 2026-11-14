import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'models/dx_captcha_event.dart';
import 'models/dx_captcha_exception.dart';
import 'models/dx_captcha_result.dart';
import 'platform/dx_captcha_platform.dart';

/// 验证码当前所处的状态。
enum DxCaptchaState {
  /// 尚未开始加载。
  idle,

  /// 正在加载或渲染中。
  loading,

  /// 已就绪，等待用户操作。
  ready,

  /// 用户正在拖动或校验中。
  verifying,

  /// 验证通过。
  success,

  /// 验证失败。
  fail,

  /// 已销毁。
  disposed,
}

/// 验证码实例控制器。
///
/// 一个控制器同一时刻只能绑定一个 [DxCaptcha] 组件。组件销毁时控制器
/// 会自动解绑，但不会自行 [dispose]，避免在 `build` 期间被意外释放。
///
/// ```dart
/// final controller = DxCaptchaController();
/// DxCaptcha(config: config, controller: controller);
///
/// final result = await controller.waitForResult();
/// if (result.isSuccess) {
///   print(result.token);
/// }
/// ```
class DxCaptchaController extends ChangeNotifier {
  /// 创建控制器。
  DxCaptchaController();

  DxCaptchaDriver? _driver;
  DxCaptchaState _state = DxCaptchaState.idle;
  DxCaptchaResult? _lastResult;
  DxCaptchaException? _error;
  Completer<DxCaptchaResult>? _pendingResult;
  bool _disposed = false;

  /// 当前状态。
  DxCaptchaState get state => _state;

  /// 最近一次的事件结果。
  DxCaptchaResult? get lastResult => _lastResult;

  /// 最近一次错误。
  DxCaptchaException? get error => _error;

  /// 最近一次验证通过得到的 token。
  String? get token => _lastResult?.normalizedToken;

  /// 是否已通过验证。
  bool get isVerified => _state == DxCaptchaState.success;

  /// 是否已经绑定到视图。
  bool get isAttached => _driver?.isAttached ?? false;

  /// 等待下一次验证结果（成功或失败都会返回）。
  ///
  /// 超时返回一个 [DxCaptchaEventType.unknown] 结果，不抛异常，便于业务侧
  /// 用统一分支处理。
  Future<DxCaptchaResult> waitForResult({Duration? timeout}) {
    if (_disposed) {
      return Future<DxCaptchaResult>.error(
        const DxCaptchaException(
          DxCaptchaException.disposed,
          '控制器已销毁',
        ),
      );
    }

    final Completer<DxCaptchaResult> completer =
        _pendingResult ??= Completer<DxCaptchaResult>();

    if (timeout == null) {
      return completer.future;
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () => DxCaptchaResult(
        type: DxCaptchaEventType.unknown,
        message: '等待验证结果超时',
        rawEvent: 'timeout',
      ),
    );
  }

  /// 重新加载验证码，用于验证失败后重试。
  Future<void> reload() async {
    final DxCaptchaDriver? driver = _driver;
    if (driver == null) {
      throw const DxCaptchaException(
        DxCaptchaException.initFailed,
        '验证码组件尚未挂载，无法重新加载',
      );
    }
    _state = DxCaptchaState.loading;
    _error = null;
    _lastResult = null;
    _pendingResult = null;
    _safeNotify();
    await driver.reload();
  }

  /// 重置状态，但不重新加载。
  void reset() {
    _state = DxCaptchaState.idle;
    _lastResult = null;
    _error = null;
    _pendingResult = null;
    _safeNotify();
  }

  /// 通知监听者。
  ///
  /// 原生视图在 `build` 阶段被创建时会同步回调，此时直接 notify 会触发
  /// 「setState() called during build」，因此按调度阶段延迟到帧末。
  void _safeNotify() {
    if (_disposed) {
      return;
    }
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @internal
  void attachDriver(DxCaptchaDriver driver) {
    _driver = driver;
    _state = DxCaptchaState.loading;
    _safeNotify();
  }

  @internal
  void detachDriver() {
    if (_driver != null) {
      _driver = null;
      if (!_disposed && _state != DxCaptchaState.success) {
        _state = DxCaptchaState.idle;
      }
    }
  }

  @internal
  void dispatchResult(DxCaptchaResult result) {
    _lastResult = result;

    switch (result.type) {
      case DxCaptchaEventType.ready:
        _state = DxCaptchaState.ready;
      case DxCaptchaEventType.render:
      case DxCaptchaEventType.dragStart:
      case DxCaptchaEventType.dragging:
      case DxCaptchaEventType.dragEnd:
      case DxCaptchaEventType.verify:
        _state = DxCaptchaState.verifying;
      case DxCaptchaEventType.success:
        _state = DxCaptchaState.success;
      case DxCaptchaEventType.fail:
      case DxCaptchaEventType.loadFail:
        _state = DxCaptchaState.fail;
      case DxCaptchaEventType.unknown:
      case DxCaptchaEventType.loadTooMuch:
      case DxCaptchaEventType.tapLogo:
      case DxCaptchaEventType.verifyDone:
      case DxCaptchaEventType.verifySuccess:
      case DxCaptchaEventType.verifyFail:
      case DxCaptchaEventType.passByServer:
        break;
    }

    if (result.type == DxCaptchaEventType.success ||
        result.type == DxCaptchaEventType.fail) {
      final Completer<DxCaptchaResult>? pending = _pendingResult;
      if (pending != null && !pending.isCompleted) {
        pending.complete(result);
      }
      _pendingResult = null;
    }

    _safeNotify();
  }

  @internal
  void dispatchError(DxCaptchaException error) {
    _error = error;
    _state = DxCaptchaState.fail;
    _safeNotify();
  }

  @override
  void dispose() {
    // 允许重复调用：业务代码显式 dispose 后，State.dispose 可能再次触发。
    if (_disposed) {
      return;
    }
    _disposed = true;
    _state = DxCaptchaState.disposed;
    final Completer<DxCaptchaResult>? pending = _pendingResult;
    if (pending != null && !pending.isCompleted) {
      pending.complete(
        const DxCaptchaResult(
          type: DxCaptchaEventType.unknown,
          message: '控制器已销毁',
          rawEvent: 'disposed',
        ),
      );
    }
    _pendingResult = null;
    unawaited(_driver?.dispose());
    _driver = null;
    super.dispose();
  }
}
