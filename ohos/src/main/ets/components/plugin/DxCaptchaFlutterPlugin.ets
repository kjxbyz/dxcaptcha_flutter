/**
 * 顶象无感验证码 Flutter 插件 OpenHarmony 端入口。
 *
 * 对齐官方插件开发规范（developing-plugin.md）：
 * 实现 FlutterPlugin 接口，在引擎附加时把 PlatformView 工厂注册到
 * `dxcaptcha_flutter/view` 类型上。实际的验证码生命周期由
 * DxCaptchaPlatformView 管理。
 */

import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import PlatformViewFactory from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformViewFactory';
import PlatformView from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import common from '@ohos.app.ability.common';
import {
  DxCaptchaPlatformView,
  DX_CAPTCHA_VIEW_TYPE
} from './DxCaptchaPlatformView';

const TAG: string = 'DxcaptchaFlutterPlugin';

/** 创建 DxCaptchaPlatformView 的工厂。 */
export class DxCaptchaViewFactory extends PlatformViewFactory {
  private messenger: BinaryMessenger;

  constructor(messenger: BinaryMessenger) {
    super(StandardMessageCodec.INSTANCE);
    this.messenger = messenger;
  }

  public create(context: common.Context, viewId: number, args: ESObject): PlatformView {
    return new DxCaptchaPlatformView(context, viewId, args, this.messenger);
  }
}

export class DxcaptchaFlutterPlugin implements FlutterPlugin {
  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    binding.getPlatformViewRegistry()?.registerViewFactory(
      DX_CAPTCHA_VIEW_TYPE,
      new DxCaptchaViewFactory(binding.getBinaryMessenger())
    );
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    // 视图资源由各自的 PlatformView.dispose() 释放，这里无需额外处理。
  }
}
