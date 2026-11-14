import 'dart:async';

import 'package:flutter/material.dart';

import 'dx_captcha_controller.dart';
import 'models/dx_captcha_config.dart';
import 'models/dx_captcha_event.dart';
import 'models/dx_captcha_exception.dart';
import 'models/dx_captcha_result.dart';
import 'platform/dx_captcha_platform.dart';

/// 顶象无感验证码组件（嵌入模式）。
///
/// 组件会把原生 / JS SDK 渲染在当前 Widget 树的位置，验证过程中通过
/// [onEvent] 回调所有事件，验证结束时通过 [onSuccess] / [onFail] 通知结果。
///
/// ```dart
/// DxCaptcha(
///   config: const DxCaptchaConfig(appId: 'your-app-id'),
///   onSuccess: (result) => print('token: ${result.token}'),
///   onFail: (result) => print('失败: ${result.message}'),
/// )
/// ```
///
/// 若需要在验证失败后主动重试，可传入 [controller] 并调用
/// [DxCaptchaController.reload]。
class DxCaptcha extends StatefulWidget {
  /// 创建验证码组件。
  const DxCaptcha({
    super.key,
    required this.config,
    this.controller,
    this.width,
    this.height,
    this.aspectRatio = 362 / 335,
    this.onSuccess,
    this.onFail,
    this.onEvent,
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// 验证码配置。
  final DxCaptchaConfig config;

  /// 可选控制器，用于重载、读取状态。
  final DxCaptchaController? controller;

  /// 组件宽度，为空时撑满父级约束。
  final double? width;

  /// 组件高度，为空时按 [aspectRatio] 计算。
  final double? height;

  /// 宽高比，默认取顶象 SDK 弹窗的推荐比例 362 : 335。
  final double aspectRatio;

  /// 验证通过时回调。
  final ValueChanged<DxCaptchaResult>? onSuccess;

  /// 验证失败时回调。
  final ValueChanged<DxCaptchaResult>? onFail;

  /// 所有事件回调。
  final ValueChanged<DxCaptchaResult>? onEvent;

  /// 自定义加载占位。
  final WidgetBuilder? loadingBuilder;

  /// 自定义错误提示。
  final Widget Function(BuildContext context, DxCaptchaException error)?
      errorBuilder;

  /// 以弹窗方式弹出验证码，返回验证结果。
  ///
  /// 用户点击遮罩或返回键关闭时返回 `null`，与「验证失败」区分开，
  /// 便于业务侧做不同的提示。
  ///
  /// ```dart
  /// final result = await DxCaptcha.show(
  ///   context,
  ///   config: const DxCaptchaConfig(appId: 'your-app-id'),
  /// );
  /// if (result != null && result.isSuccess) {
  ///   await login(result.token!);
  /// }
  /// ```
  static Future<DxCaptchaResult?> show(
    BuildContext context, {
    required DxCaptchaConfig config,
    String? title,
    String? description,
    double maxWidth = 362,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x8A000000),
    bool dismissOnSuccess = true,
    EdgeInsets padding = const EdgeInsets.fromLTRB(0, 20, 0, 16),
    Duration? timeout,
  }) {
    return showDialog<DxCaptchaResult>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (BuildContext dialogContext) {
        return _DxCaptchaDialog(
          config: config,
          title: title,
          description: description,
          maxWidth: maxWidth,
          dismissOnSuccess: dismissOnSuccess,
          padding: padding,
          timeout: timeout,
        );
      },
    );
  }

  @override
  State<DxCaptcha> createState() => _DxCaptchaState();
}

class _DxCaptchaState extends State<DxCaptcha> {
  DxCaptchaDriver? _driver;
  DxCaptchaException? _error;
  bool _loading = true;
  String? _signature;

  @override
  void initState() {
    super.initState();
    _signature = _configSignature;
  }

  @override
  void didUpdateWidget(DxCaptcha oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String next = _configSignature;
    if (_signature != next) {
      _signature = next;
      _error = null;
      _loading = true;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detachDriver();
    }
  }

  @override
  void dispose() {
    widget.controller?.detachDriver();
    unawaited(_driver?.dispose());
    _driver = null;
    super.dispose();
  }

  String get _configSignature => widget.config.toMap().toString();

  void _handleResult(DxCaptchaResult result) {
    if (!mounted) {
      return;
    }
    widget.controller?.dispatchResult(result);
    widget.onEvent?.call(result);

    switch (result.type) {
      case DxCaptchaEventType.success:
        widget.onSuccess?.call(result);
      case DxCaptchaEventType.fail:
        widget.onFail?.call(result);
      case DxCaptchaEventType.loadFail:
        setState(() {
          _loading = false;
          _error = DxCaptchaException(
            DxCaptchaException.initFailed,
            result.message ?? '验证码加载失败',
          );
        });
      default:
        break;
    }

    if (result.type == DxCaptchaEventType.ready && _loading) {
      setState(() => _loading = false);
    }
  }

  void _handleError(DxCaptchaException error) {
    if (!mounted) {
      return;
    }
    widget.controller?.dispatchError(error);
    setState(() {
      _error = error;
      _loading = false;
    });
  }

  Widget _buildPlatformView() {
    return DxCaptchaPlatform.instance.buildView(
      DxCaptchaViewParams(
        config: widget.config,
        onResult: _handleResult,
        onError: _handleError,
        onDriverCreated: (DxCaptchaDriver driver) {
          _driver = driver;
          widget.controller?.attachDriver(driver);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = KeyedSubtree(
      key: ValueKey<String>(_signature ?? ''),
      child: _buildPlatformView(),
    );

    if (_error != null && widget.errorBuilder != null) {
      content = widget.errorBuilder!(context, _error!);
    }

    if (widget.width != null && widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    } else if (widget.width != null) {
      content = SizedBox(
        width: widget.width,
        child: AspectRatio(aspectRatio: widget.aspectRatio, child: content),
      );
    } else if (widget.height != null) {
      content = SizedBox(height: widget.height, child: content);
    } else {
      content = AspectRatio(aspectRatio: widget.aspectRatio, child: content);
    }

    if (_loading && widget.loadingBuilder != null) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          content,
          widget.loadingBuilder!(context),
        ],
      );
    }

    return content;
  }
}

class _DxCaptchaDialog extends StatefulWidget {
  const _DxCaptchaDialog({
    required this.config,
    required this.maxWidth,
    required this.dismissOnSuccess,
    required this.padding,
    this.title,
    this.description,
    this.timeout,
  });

  final DxCaptchaConfig config;
  final String? title;
  final String? description;
  final double maxWidth;
  final bool dismissOnSuccess;
  final EdgeInsets padding;
  final Duration? timeout;

  @override
  State<_DxCaptchaDialog> createState() => _DxCaptchaDialogState();
}

class _DxCaptchaDialogState extends State<_DxCaptchaDialog> {
  late final DxCaptchaController _controller = DxCaptchaController();
  DxCaptchaResult? _failure;

  @override
  void initState() {
    super.initState();
    if (widget.timeout != null) {
      _controller.waitForResult(timeout: widget.timeout).then(_onResult);
    }
  }

  void _onResult(DxCaptchaResult result) {
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      if (widget.dismissOnSuccess && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _failure = null);
      }
    } else if (result.type == DxCaptchaEventType.fail) {
      setState(() => _failure = result);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1F1F23) : Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Padding(
          padding: widget.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                  child: Text(
                    widget.title!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (widget.description != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    widget.description!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              DxCaptcha(
                config: widget.config,
                controller: _controller,
                onSuccess: _onResult,
                onFail: _onResult,
              ),
              if (_failure != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          _failure!.message ?? '验证未通过，请重试',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          setState(() => _failure = null);
                          await _controller.reload();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
