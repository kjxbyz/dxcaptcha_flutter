/**
 * 顶象无感验证码 Flutter 插件 OpenHarmony 端平台视图。
 *
 * 结构对齐官方 PlatformView 接入模式（using-platform-view.md）：
 * - DxCaptchaComponent：ArkUI 组件，内部渲染顶象 SDK 的 CaptchaViewV5；
 * - DxCaptchaBuilder：@Builder 函数，包装为 WrappedBuilder 供引擎绑定；
 * - DxCaptchaPlatformView：PlatformView + MethodCallHandler，负责
 *   `dxcaptcha_flutter/view_<viewId>` 通道上的 reload / dispose 与
 *   onEvent / onError 回传，行为与 Android 端 DxCaptchaPlatformView 一致。
 *
 * 顶象鸿蒙 SDK 用法（官方文档/示例）：
 * ```
 * CaptchaViewV5({
 *   captchaViewController: controller,
 *   callBack: (view) => {
 *     view.init(appId);
 *     view.initConfig(config);
 *     view.startToLoad(listener, 'success', 'fail');
 *   }
 * })
 * ```
 */

import {
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import PlatformView, { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import common from '@ohos.app.ability.common';
import { CaptchaViewV5, CaptchaViewController, CaptchaViewControllerImpl } from 'dx.captcha';

const TAG: string = 'DxCaptchaPlatformView';

/** 验证码视图注册名，与 Dart 侧 MethodChannelDxCaptcha.viewType 保持一致。 */
export const DX_CAPTCHA_VIEW_TYPE: string = 'dxcaptcha_flutter/view';

/** 每视图通道名前缀，与 Dart 侧 channelPrefix 保持一致。 */
export const DX_CAPTCHA_CHANNEL_PREFIX: string = 'dxcaptcha_flutter/view_';

/** 顶象 v5 SDK 的 UI 版本号，作为 CaptchaViewControllerImpl 构造参数。 */
const DX_SDK_UI_VERSION: number = 5;

/** SDK 组件的设计宽度（与 iOS 端 DXCaptchaViewV5 的 362 对齐）。 */
const DX_SDK_DEFAULT_WIDTH: number = 362;

/** Dart 配置中由插件自身消费、不应透传给 SDK 的键。 */
const RESERVED_KEYS: string[] = [
  'appId', 'apiServer', 'language', 'cacheStorage', 'timeout',
  'showVoice', 'customStyle', 'customLanguage', 'bgColor',
  'style', 'privacy', 'enableRiskSdk', 'enableCache'
];

@Component
export struct DxCaptchaComponent {
  @ObjectLink params: Params
  view: DxCaptchaPlatformView = this.params.platformView as DxCaptchaPlatformView

  build() {
    Column() {
      CaptchaViewV5({
        captchaViewController: this.view.controller,
        callBack: (controller: CaptchaViewController): void => {
          this.view.onCaptchaReady(controller)
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}

@Builder
export function DxCaptchaBuilder(params: Params) {
  DxCaptchaComponent({ params: params })
}

@Observed
export class DxCaptchaPlatformView extends PlatformView implements MethodCallHandler {
  /** 每视图方法通道。 */
  private channel: MethodChannel;

  /** 引擎注入的应用上下文，供 SDK 资源管理器初始化使用。 */
  private context: common.Context;

  /** Dart 侧下发的创建参数（DxCaptchaConfig.toMap() 解码结果）。 */
  private config: ESObject;

  /** 顶象 SDK 视图控制器，组件渲染时被 CaptchaViewV5 消费。 */
  public controller: CaptchaViewControllerImpl;

  /** 是否已释放，释放后忽略所有 SDK 回调。 */
  private disposed: boolean = false;

  constructor(context: common.Context, viewId: number, args: ESObject, messenger: BinaryMessenger) {
    super();
    this.context = context;
    this.config = args;
    this.controller = new CaptchaViewControllerImpl(DX_SDK_UI_VERSION, DX_SDK_DEFAULT_WIDTH);
    this.channel = new MethodChannel(messenger, `${DX_CAPTCHA_CHANNEL_PREFIX}${viewId}`, StandardMessageCodec.INSTANCE);
    this.channel.setMethodCallHandler(this);
  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(DxCaptchaBuilder);
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'reload':
        this.reloadCaptcha();
        result.success(null);
        break;
      case 'dispose':
        this.dispose();
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * SDK 组件就绪回调：初始化资源管理器、应用配置并开始加载验证码。
   * 由 DxCaptchaComponent 渲染 CaptchaViewV5 后触发。
   */
  public onCaptchaReady(view: CaptchaViewController): void {
    if (this.disposed) {
      return;
    }
    try {
      const impl = view as CaptchaViewControllerImpl;
      if (impl.initResMgr) {
        impl.initResMgr(this.context.resourceManager);
      }
      const config: ESObject = this.config ?? {};
      const appId: string = (config['appId'] as string) ?? '';
      view.init(appId);
      view.initConfig(this.buildSdkConfig(config));
      view.startToLoad(this.sdkEventListener, 'success', 'fail');
    } catch (error) {
      console.error(`${TAG} init failed: ${error}`);
      this.sendError('init_failed', `验证码初始化失败：${error}`);
    }
  }

  /** 重新加载验证码（Dart 侧 DxCaptchaController.reload 触发）。 */
  private reloadCaptcha(): void {
    if (this.disposed) {
      return;
    }
    try {
      this.controller.startToLoad(this.sdkEventListener, 'success', 'fail');
    } catch (error) {
      console.error(`${TAG} reload failed: ${error}`);
      this.sendError('init_failed', `验证码重新加载失败：${error}`);
    }
  }

  /** 释放资源：移除方法通道处理器。SDK 视图随组件销毁由引擎回收。 */
  private dispose(): void {
    if (this.disposed) {
      return;
    }
    this.disposed = true;
    this.channel.setMethodCallHandler(null);
  }

  /** SDK 事件监听器：把事件与负载转发给 Dart 层（onEvent）。 */
  private sdkEventListener = (event: string, args: ESObject): void => {
    if (this.disposed || !event) {
      return;
    }
    const payload: Record<string, ESObject> = { 'event': event };
    try {
      const map = args as HashMap<string, ESObject>;
      if (map) {
        map.forEach((value: ESObject, key: string): void => {
          payload[key] = value;
        });
      }
    } catch (error) {
      console.warn(`${TAG} convert args failed: ${error}`);
    }
    if (this.disposed) {
      return;
    }
    this.channel.invokeMethod('onEvent', payload);
  }

  /** 把 Dart 配置转换为 SDK 的 initConfig 参数（对齐 Android 端桥接）。 */
  private buildSdkConfig(config: ESObject): Record<string, ESObject> {
    const result: Record<string, ESObject> = {};

    const appId: string = config['appId'];
    if (appId) {
      result['appId'] = appId;
    }
    const apiServer: string = config['apiServer'];
    if (apiServer) {
      result['apiServer'] = apiServer;
    }
    const language: string = config['language'];
    if (language) {
      result['language'] = language;
    }
    const cacheStorage: boolean = config['cacheStorage'];
    if (cacheStorage !== undefined && cacheStorage !== null) {
      result['cacheStorage'] = cacheStorage;
    }
    const timeout: number = config['timeout'];
    if (timeout !== undefined && timeout !== null) {
      result['timeout'] = timeout;
    }
    const showVoice: boolean = config['showVoice'];
    if (showVoice !== undefined && showVoice !== null) {
      result['showVoice'] = showVoice;
    }
    const width: number = config['width'];
    if (width !== undefined && width !== null) {
      result['width'] = width;
      this.controller.width = width;
    }

    const customStyleSrc: ESObject = config['customStyle'];
    let customStyle: Record<string, ESObject> | undefined = undefined;
    if (customStyleSrc) {
      customStyle = customStyleSrc as Record<string, ESObject>;
    }

    // bgColor 是插件提供的便捷参数，归一到 SDK 的 customStyle.bgColor。
    const bgColor: string = config['bgColor'];
    if (bgColor && (!customStyle || customStyle['bgColor'] === undefined)) {
      if (customStyle === undefined) {
        customStyle = {};
      }
      customStyle['bgColor'] = bgColor;
    }
    if (customStyle !== undefined) {
      result['customStyle'] = customStyle;
    }

    const customLanguageSrc: ESObject = config['customLanguage'];
    if (customLanguageSrc) {
      result['customLanguage'] = customLanguageSrc as Record<string, ESObject>;
    }

    // 官方「最小化使用」配置：不加载设备指纹（风控）SDK，并通知服务端
    // 不等待设备指纹。默认 enableRiskSdk=false，与 Android 端桥接一致。
    const enableRiskSdk: boolean = config['enableRiskSdk'];
    if (enableRiskSdk === undefined || enableRiskSdk === null || enableRiskSdk === false) {
      result['DXKeyRiskEnable'] = false;
      result['wait_for_const_id_sdk'] = false;
    }

    // iOS SDK（v5.4.18r < v5.4.21）的 protocol 为必填参数；鸿蒙 SDK 同为
    // v5.4.18r，提前注入默认值 https:，避免 SDK 走 http 被网络策略拦截。
    // extra['protocol'] 可覆盖。
    result['protocol'] = 'https:';

    // 透传 extra 中其余参数（私有化部署的 keyURL、ua_js 等）。
    const keys: string[] = Object.keys(config as Record<string, ESObject>);
    for (const key of keys) {
      if (RESERVED_KEYS.indexOf(key) < 0) {
        const value: ESObject = config[key];
        if (value !== undefined && value !== null) {
          result[key] = value;
        }
      }
    }

    return result;
  }

  /** 原生层错误上报给 Dart 层（onError）。 */
  private sendError(code: string, message: string): void {
    if (this.disposed) {
      return;
    }
    const payload: Record<string, string> = {
      'code': code,
      'message': message
    };
    this.channel.invokeMethod('onError', payload);
  }
}
