//
//  DxcaptchaFlutterPlugin.m
//  dxcaptcha_flutter
//
//  顶象无感验证码 Flutter 插件 iOS 端实现。
//  通过 PlatformView 承载 DXCaptchaViewV5（WKWebView 子类），
//  并用独立 MethodChannel 把验证事件回传给 Dart 层。
//

#import "DxcaptchaFlutterPlugin.h"

#import <dx-captcha/DXCaptchaDelegate.h>
#import <dx-captcha/DXCaptchaView.h>

static NSString *const kDxCaptchaViewType = @"dxcaptcha_flutter/view";
static NSString *const kDxCaptchaChannelPrefix = @"dxcaptcha_flutter/view_";

/// iOS SDK 认识的配置键，其余键（width / privacy 等）仅 Android 使用。
static NSSet<NSString *> *DxCaptchaAllowedConfigKeys(void) {
  static NSSet<NSString *> *keys;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    keys = [NSSet setWithArray:@[
      @"appId", @"apiServer", @"isSaaS", @"language", @"customStyle",
      @"customLanguage", @"cacheStorage", @"timeout", @"showVoice", @"uid",
      @"ua_js", @"captchaJS", @"constID_js", @"keyURL", @"logoServer",
      @"constIDServer", @"corsBaseURL", @"protocol"
    ]];
  });
  return keys;
}

static NSDictionary<NSString *, id> *DxCaptchaFilterConfig(NSDictionary *raw) {
  NSMutableDictionary<NSString *, id> *config = [NSMutableDictionary dictionary];
  NSSet<NSString *> *allowed = DxCaptchaAllowedConfigKeys();
  [raw enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    if (![key isKindOfClass:[NSString class]]) {
      return;
    }
    if (![allowed containsObject:key] || value == [NSNull null]) {
      return;
    }
    config[key] = value;
  }];
  return config;
}

/// 把 SDK 回传的字典裁剪成 Flutter 标准编解码器可以传输的类型。
static NSDictionary<NSString *, id> *DxCaptchaSanitizePayload(
    NSString *event, NSDictionary *raw) {
  NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary dictionary];
  payload[@"event"] = event.length > 0 ? event : @"unknown";

  [raw enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
    if (![key isKindOfClass:[NSString class]] || value == nil) {
      return;
    }
    if ([value isKindOfClass:[NSString class]] ||
        [value isKindOfClass:[NSNumber class]]) {
      payload[key] = value;
    } else if (value != [NSNull null]) {
      payload[key] = [value description];
    }
  }];

  return payload;
}

#pragma mark - PlatformView

@interface DxCaptchaPlatformView : NSObject <FlutterPlatformView, DXCaptchaDelegate>

- (instancetype)initWithFrame:(CGRect)frame
                   viewId:(int64_t)viewId
                     args:(id)args
                messenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

@implementation DxCaptchaPlatformView {
  UIView *_container;
  DXCaptchaViewV5 *_captchaView;
  FlutterMethodChannel *_channel;
  NSDictionary *_config;
  BOOL _disposed;
}

- (instancetype)initWithFrame:(CGRect)frame
                       viewId:(int64_t)viewId
                         args:(id)args
                    messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) {
    _config = [args isKindOfClass:[NSDictionary class]]
                  ? [args copy]
                  : [NSDictionary dictionary];
    _container = [[UIView alloc] initWithFrame:frame];
    _container.backgroundColor = [UIColor clearColor];
    _container.clipsToBounds = YES;

    NSString *channelName =
        [NSString stringWithFormat:@"%@%lld", kDxCaptchaChannelPrefix, viewId];
    _channel = [FlutterMethodChannel methodChannelWithName:channelName
                                           binaryMessenger:messenger];

    __weak typeof(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall *call,
                                     FlutterResult result) {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (strongSelf == nil) {
        result(nil);
        return;
      }
      [strongSelf handleMethodCall:call result:result];
    }];

    [self createCaptchaView];
  }
  return self;
}

- (UIView *)view {
  return _container;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"reload"]) {
    [self createCaptchaView];
    result(nil);
    return;
  }
  if ([call.method isEqualToString:@"dispose"]) {
    [self disposeCaptchaView];
    result(nil);
    return;
  }
  result(FlutterMethodNotImplemented);
}

/// 顶象验证码（DXCaptchaViewV5）原生设计尺寸 362x335，与官方 iOS Demo 的
/// 弹窗示例一致（width=362, height=362/(362/335)）。WebView 必须按该尺寸
/// 承载内容，容器不足时整体等比缩放，容器更大时居中放置。
static const CGFloat kDxCaptchaNativeWidth = 362.0;
static const CGFloat kDxCaptchaNativeHeight = 335.0;

/// 创建（或重建）验证码视图。
- (void)createCaptchaView {
  if (_disposed) {
    return;
  }

  [self disposeCaptchaView];

  Class captchaClass = NSClassFromString(@"DXCaptchaViewV5");
  if (captchaClass == Nil) {
    [self sendError:@"sdk_unavailable"
             message:@"未找到 DXCaptchaViewV5，请确认已集成 dx-captcha.framework"];
    return;
  }

  NSMutableDictionary *config =
      [DxCaptchaFilterConfig(_config) mutableCopy];
  // protocol 在 SDK v5.4.21 以下为必填项（官方文档），未提供时 SDK 可能按 http
  // 发起请求被 ATS 拦截，前端 JS 资源加载失败并触发 load_fail 事件（白屏）。
  // 插件内置的 dx-captcha 为 v5.4.18r，因此这里默认补齐 https。
  if (config[@"protocol"] == nil) {
    config[@"protocol"] = @"https:";
  }
  NSString *appId = config[@"appId"];
  if (![appId isKindOfClass:[NSString class]] || appId.length == 0) {
    [self sendError:@"init_failed" message:@"appId 不能为空"];
    return;
  }

  // SDK 通过 mainBundle 查找 DXCaptcha.bundle（验证码前端资源），
  // 缺失时 WKWebView 加载空白页，表现为白屏。提前拦截给出可诊断的错误。
  if ([NSBundle.mainBundle pathForResource:@"DXCaptcha" ofType:@"bundle"] == nil) {
    [self sendError:@"sdk_resource_missing"
             message:@"未找到 DXCaptcha.bundle：请确认 podspec 的 resources 已包含"
                        " Frameworks/DXCaptcha.bundle，并重新 pod install"];
    return;
  }

  CGFloat containerWidth = CGRectGetWidth(_container.bounds);
  CGFloat containerHeight = CGRectGetHeight(_container.bounds);
  if (containerWidth < 1 || containerHeight < 1) {
    containerWidth = kDxCaptchaNativeWidth;
    containerHeight = kDxCaptchaNativeHeight;
  }

  // WebView 恒定按原生设计尺寸 362x335 布局；容器更窄时整体等比缩放，
  // 缩放围绕视图中心进行，因此 frame 的中心要对齐容器中心（除以 scale
  // 折算回未缩放坐标系）。
  CGFloat scale = MIN(1.0, containerWidth / kDxCaptchaNativeWidth);
  CGFloat originX = (containerWidth / scale - kDxCaptchaNativeWidth) / 2;
  CGFloat originY = (containerHeight / scale - kDxCaptchaNativeHeight) / 2;

  DXCaptchaViewV5 *captchaView = [[DXCaptchaViewV5 alloc]
      initWithConfig:config
            delegate:self
               frame:CGRectMake(originX, originY,
                                kDxCaptchaNativeWidth, kDxCaptchaNativeHeight)];

  if (captchaView == nil) {
    [self sendError:@"init_failed" message:@"DXCaptchaViewV5 初始化失败"];
    return;
  }

  if (scale < 1.0) {
    captchaView.transform = CGAffineTransformMakeScale(scale, scale);
    captchaView.autoresizingMask = UIViewAutoresizingNone;
  } else {
    // 容器更大时保持 362x335 原生尺寸，四边留白均分保持居中。
    captchaView.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleTopMargin |
        UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleBottomMargin;
  }
  captchaView.backgroundColor = [UIColor clearColor];
  captchaView.opaque = NO;

  [_container addSubview:captchaView];
  _captchaView = captchaView;
}

- (void)disposeCaptchaView {
  [_captchaView stopLoading];
  [_captchaView removeFromSuperview];
  _captchaView.delegate = nil;
  _captchaView = nil;
}

- (void)sendError:(NSString *)code message:(NSString *)message {
  [_channel invokeMethod:@"onError"
               arguments:@{@"code": code, @"message": message}];
}

#pragma mark - DXCaptchaDelegate

- (void)captchaView:(DXCaptchaView *)view
    didReceiveEventString:(NSString *)event
                     arg:(NSDictionary *)dict {
  NSDictionary *payload = DxCaptchaSanitizePayload(event, dict);
  [_channel invokeMethod:@"onEvent" arguments:payload];
}

- (void)dealloc {
  _disposed = YES;
  [_channel setMethodCallHandler:nil];
  [self disposeCaptchaView];
}

@end

#pragma mark - Factory

@interface DxCaptchaViewFactory : NSObject <FlutterPlatformViewFactory>

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;

@end

@implementation DxCaptchaViewFactory {
  NSObject<FlutterBinaryMessenger> *_messenger;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) {
    _messenger = messenger;
  }
  return self;
}

- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame
                                    viewIdentifier:(int64_t)viewId
                                         arguments:(id _Nullable)args {
  return [[DxCaptchaPlatformView alloc] initWithFrame:frame
                                               viewId:viewId
                                                 args:args
                                            messenger:_messenger];
}

- (NSObject<FlutterMessageCodec> *)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

@end

#pragma mark - Plugin

@implementation DxcaptchaFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  DxCaptchaViewFactory *factory =
      [[DxCaptchaViewFactory alloc] initWithMessenger:registrar.messenger];
  [registrar registerViewFactory:factory withId:kDxCaptchaViewType];
}

@end
