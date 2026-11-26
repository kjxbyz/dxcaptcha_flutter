/// 顶象无感验证码 Flutter 插件。
///
/// 支持 iOS / Android / OpenHarmony，提供嵌入组件与弹窗两种接入方式。
library;

export 'src/dx_captcha.dart' show DxCaptcha;
export 'src/dx_captcha_controller.dart'
    show DxCaptchaController, DxCaptchaState;
export 'src/models/dx_captcha_config.dart'
    show DxCaptchaConfig, DxCaptchaLanguage, DxCaptchaPrivacy;
export 'src/models/dx_captcha_event.dart' show DxCaptchaEventType;
export 'src/models/dx_captcha_exception.dart' show DxCaptchaException;
export 'src/models/dx_captcha_result.dart' show DxCaptchaResult;
export 'src/platform/dx_captcha_platform.dart'
    show DxCaptchaDriver, DxCaptchaPlatform, DxCaptchaViewParams;
export 'src/platform/dx_captcha_method_channel.dart'
    show MethodChannelDxCaptcha;
