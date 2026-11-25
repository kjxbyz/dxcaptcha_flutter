/// 验证码生命周期事件类型。
///
/// 三端（iOS / Android / Web）的事件名不完全一致，插件在收到原生事件后
/// 统一归一化为以下枚举值，业务代码无需关心平台差异。
enum DxCaptchaEventType {
  /// 验证码开始渲染。
  render('render'),

  /// 验证码准备就绪，可以接受用户输入。
  ready('ready'),

  /// 加载失败，通常是网络或 appId 配置问题。
  loadFail('load_fail'),

  /// 用户开始拖动滑块。
  dragStart('drag_start'),

  /// 用户拖动滑块过程中。
  dragging('dragging'),

  /// 用户释放滑块。
  dragEnd('drag_end'),

  /// 向校验接口提交数据。
  verify('verify'),

  /// 校验接口已返回数据。
  verifyDone('verify_done'),

  /// 校验接口返回成功。
  verifySuccess('verify_success'),

  /// 校验接口返回失败。
  verifyFail('verify_fail'),

  /// 无感验证通过（用户无需操作）。
  passByServer('pass_by_server'),

  /// 验证通过，滑动验证与无感验证都会触发，[DxCaptchaResult.token] 此时可用。
  success('success'),

  /// 验证失败。
  fail('fail'),

  /// 用户点击了验证码 logo。
  tapLogo('tap_logo'),

  /// 加载次数超限。
  loadTooMuch('load_too_much'),

  /// 未识别的平台事件，原始值见 [DxCaptchaResult.rawEvent]。
  unknown('unknown');

  const DxCaptchaEventType(this.value);

  /// 归一化后的事件名。
  final String value;

  /// 将原生层回调的事件字符串归一化为枚举。
  ///
  /// 传入值可能是 `success`、`verify_success`、`DXCaptchaEventReady`
  /// 等多种写法，这里做了兼容处理。
  static DxCaptchaEventType parse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return DxCaptchaEventType.unknown;
    }
    final String key = raw
        .trim()
        .toLowerCase()
        .replaceAll('dxcaptchaevent', '')
        .replaceAll(RegExp(r'[\s\-]'), '_');

    for (final DxCaptchaEventType type in values) {
      if (type == DxCaptchaEventType.unknown) {
        continue;
      }
      if (type.value == key || type.name.toLowerCase() == key) {
        return type;
      }
    }

    // 常见别名兜底。
    switch (key) {
      case 'loadfail':
      case 'error':
      // Android v5.1.7r+ 的事件名（文档与 DEMO 确认）。
      case 'oncaptchajsloadfail':
        return DxCaptchaEventType.loadFail;
      case 'oncaptchajsloaded':
      case 'oncaptchajsload':
        return DxCaptchaEventType.ready;
      case 'beforerender':
      case 'afterrender':
        return DxCaptchaEventType.render;
      case 'beforeready':
      case 'afterready':
        return DxCaptchaEventType.ready;
      case 'passbyserver':
      case 'pass_by_server_success':
        return DxCaptchaEventType.passByServer;
      case 'loadtoomuch':
        return DxCaptchaEventType.loadTooMuch;
      case 'taplogo':
        return DxCaptchaEventType.tapLogo;
      default:
        return DxCaptchaEventType.unknown;
    }
  }
}
