/// 验证码界面语言。
enum DxCaptchaLanguage {
  /// 中文（SDK 取值 `cn`）。
  zh('cn'),

  /// 英文（SDK 取值 `en`）。
  en('en');

  const DxCaptchaLanguage(this.value);

  /// 传给 SDK 的原始字符串值。
  final String value;
}

/// 隐私数据采集白名单。
///
/// 顶象 SDK 自 v5.1.6r 起要求初始化前显式声明可采集的信息范围，
/// 不做声明时按 [minimal] 处理。
enum DxCaptchaPrivacy {
  /// 仅采集验证必需的信息（SDK `PrivacyFlag.DEFALUT`）。
  minimal('minimal'),

  /// 采集全部信息，仅排除 WiFi SSID / BSSID。
  full('full');

  const DxCaptchaPrivacy(this.value);

  /// 传给原生层的原始字符串值。
  final String value;
}

/// 顶象验证码初始化配置。
///
/// 只有 [appId] 是必填项，其余参数会按需透传给各平台 SDK，
/// 未设置的参数不会覆盖 SDK 默认值。
///
/// ```dart
/// const config = DxCaptchaConfig(
///   appId: 'dxdxdxtest2017keyc3e83b6940835',
///   language: DxCaptchaLanguage.zh,
/// );
/// ```
class DxCaptchaConfig {
  /// 创建验证码配置。
  const DxCaptchaConfig({
    required this.appId,
    this.apiServer,
    this.language,
    this.width,
    this.bgColor,
    this.customStyle = const <String, Object?>{},
    this.customLanguage = const <String, String>{},
    this.timeout,
    this.showVoice,
    this.privacy = DxCaptchaPrivacy.minimal,
    this.enableCache = true,
    this.enableRiskSdk = false,
    this.extra = const <String, Object?>{},
  });

  /// 应用标识，在顶象控制台「应用管理」中获取。
  final String appId;

  /// 私有化部署的接口域名，形如 `https://xxx.dingxiang-inc.com`。
  ///
  /// SaaS 场景留空即可。
  final String? apiServer;

  /// 界面语言，留空时由 SDK 决定。
  final DxCaptchaLanguage? language;

  /// 验证码控件宽度（像素），留空使用 SDK 默认值。
  final int? width;

  /// 控件背景色，CSS 颜色字符串，例如 `#FFFFFF`。
  final String? bgColor;

  /// 自定义样式，字段与顶象文档的 `customStyle` 一致，
  /// 例如 `{'bar': {'normalTextColor': '#3D5CC4'}}`。
  final Map<String, Object?> customStyle;

  /// 自定义文案，字段与顶象文档的 `customLanguage` 一致，
  /// 例如 `{'init_inform': '请按住滑块拖动'}`。
  final Map<String, String> customLanguage;

  /// 请求超时时间，留空使用 SDK 默认的 6 秒。
  final Duration? timeout;

  /// 是否展示语音验证码入口。
  final bool? showVoice;

  /// 隐私采集白名单。
  final DxCaptchaPrivacy privacy;

  /// 是否启用无感验证结果本地缓存（Android 支持，iOS 忽略）。
  final bool enableCache;

  /// 是否加载顶象设备指纹（风控）SDK，默认 `false`（最小化使用）。
  ///
  /// 设为 `false` 时 Android 端自动传入 `DXKeyRiskEnable=false` 与
  /// `wait_for_const_id_sdk=false`（通知服务端不等待设备指纹），并且跳过
  /// `setAllowPrivacyList` 调用，无需在工程中集成 `dx-risk-*.aar`；
  /// 代价是失去设备指纹带来的安全增强能力。
  ///
  /// 设为 `true` 时需要在插件 `android/libs/` 中提供 `dx-risk-*.aar`
  /// （iOS 端使用含指纹的 xcframework），SDK 将按 [privacy] 白名单采集。
  final bool enableRiskSdk;

  /// 透传给 SDK 的额外参数，键名与顶象文档保持一致。
  ///
  /// 用于覆盖上面未覆盖到的参数，例如私有化部署的 `keyURL`、`ua_js`。
  final Map<String, Object?> extra;

  /// 序列化为跨平台通道使用的 Map。
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'appId': appId,
      if (apiServer != null && apiServer!.isNotEmpty) 'apiServer': apiServer,
      if (language != null) 'language': language!.value,
      if (width != null) 'width': width,
      if (bgColor != null) 'bgColor': bgColor,
      if (customStyle.isNotEmpty) 'customStyle': customStyle,
      if (customLanguage.isNotEmpty) 'customLanguage': customLanguage,
      if (timeout != null) 'timeout': timeout!.inMilliseconds,
      if (showVoice != null) 'showVoice': showVoice,
      'privacy': privacy.value,
      'cacheStorage': enableCache,
      'enableRiskSdk': enableRiskSdk,
      ...extra,
    };
  }

  /// 返回一份覆盖了部分字段的新配置。
  DxCaptchaConfig copyWith({
    String? appId,
    String? apiServer,
    DxCaptchaLanguage? language,
    int? width,
    String? bgColor,
    Map<String, Object?>? customStyle,
    Map<String, String>? customLanguage,
    Duration? timeout,
    bool? showVoice,
    DxCaptchaPrivacy? privacy,
    bool? enableCache,
    bool? enableRiskSdk,
    Map<String, Object?>? extra,
  }) {
    return DxCaptchaConfig(
      appId: appId ?? this.appId,
      apiServer: apiServer ?? this.apiServer,
      language: language ?? this.language,
      width: width ?? this.width,
      bgColor: bgColor ?? this.bgColor,
      customStyle: customStyle ?? this.customStyle,
      customLanguage: customLanguage ?? this.customLanguage,
      timeout: timeout ?? this.timeout,
      showVoice: showVoice ?? this.showVoice,
      privacy: privacy ?? this.privacy,
      enableCache: enableCache ?? this.enableCache,
      enableRiskSdk: enableRiskSdk ?? this.enableRiskSdk,
      extra: extra ?? this.extra,
    );
  }

  @override
  String toString() =>
      'DxCaptchaConfig(appId: $appId, language: ${language?.value}, '
      'apiServer: $apiServer)';
}
