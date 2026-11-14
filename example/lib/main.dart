import 'package:dxcaptcha_flutter/dxcaptcha_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

/// 顶象验证码接入示例。
///
/// 顶象控制台的 appId 是必填项，示例中预填的是官方 Demo 的测试 appId，
/// 上线前请替换为自己的应用标识。
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '顶象验证码示例',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3D5CC4),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3D5CC4),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const CaptchaDemoPage(),
    );
  }
}

class CaptchaDemoPage extends StatefulWidget {
  const CaptchaDemoPage({super.key});

  @override
  State<CaptchaDemoPage> createState() => _CaptchaDemoPageState();
}

class _CaptchaDemoPageState extends State<CaptchaDemoPage> {
  static const String _defaultAppId = 'dxdxdxtest2017keyc3e83b6940835';

  final TextEditingController _appIdController = TextEditingController(
    text: _defaultAppId,
  );
  final DxCaptchaController _captchaController = DxCaptchaController();
  final List<String> _logs = <String>[];

  bool _popupMode = false;
  bool _english = false;
  String? _token;
  String? _lastFailure;

  @override
  void initState() {
    super.initState();
    _captchaController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _captchaController.removeListener(_onControllerChanged);
    _captchaController.dispose();
    _appIdController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _token = _captchaController.token;
    });
  }

  DxCaptchaConfig get _config => DxCaptchaConfig(
    appId: _appIdController.text.trim().isEmpty
        ? _defaultAppId
        : _appIdController.text.trim(),
    language: _english ? DxCaptchaLanguage.en : DxCaptchaLanguage.zh,
  );

  void _log(String message) {
    final String time = TimeOfDay.now().format(context);
    setState(() {
      _logs.insert(0, '[$time] $message');
      if (_logs.length > 30) {
        _logs.removeLast();
      }
    });
  }

  void _handleSuccess(DxCaptchaResult result) {
    setState(() {
      _token = result.token;
      _lastFailure = null;
    });
    _log('验证通过，token=${result.token}');
  }

  void _handleFail(DxCaptchaResult result) {
    setState(() => _lastFailure = result.message ?? '验证失败');
    _log('验证失败：${result.message ?? '未知原因'}');
  }

  Future<void> _openPopup() async {
    final DxCaptchaResult? result = await DxCaptcha.show(
      context,
      config: _config,
      title: '安全验证',
      description: '请完成滑动验证以继续',
      timeout: const Duration(minutes: 2),
    );

    if (!mounted) {
      return;
    }
    if (result == null) {
      _log('用户取消了验证');
    } else if (result.isSuccess) {
      _handleSuccess(result);
    } else {
      _handleFail(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('顶象验证码示例'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            TextField(
              controller: _appIdController,
              decoration: const InputDecoration(
                labelText: 'appId',
                helperText: '在顶象控制台「应用管理」中获取',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF26262B) : const Color(0xFFF4F5F9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    value: _popupMode,
                    onChanged: (bool value) => setState(() {
                      _popupMode = value;
                      _captchaController.reset();
                    }),
                    title: const Text('弹窗模式'),
                    subtitle: const Text('关闭时使用嵌入组件'),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: _english,
                    onChanged: (bool value) => setState(() => _english = value),
                    title: const Text('英文界面'),
                    subtitle: const Text('language: en'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_popupMode)
              FilledButton.icon(
                onPressed: _openPopup,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('弹出验证码'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else
              _buildEmbeddedCaptcha(theme, isDark),
            const SizedBox(height: 20),
            _buildResultPanel(theme, isDark),
            const SizedBox(height: 20),
            _buildLogPanel(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedCaptcha(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C20) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF33333A) : const Color(0xFFE4E6EE),
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: DxCaptcha(
            config: _config,
            controller: _captchaController,
            onSuccess: _handleSuccess,
            onFail: _handleFail,
            onEvent: (DxCaptchaResult result) =>
                _log('事件：${result.type.value}'),
            loadingBuilder: (BuildContext context) => const Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorBuilder: (BuildContext context, DxCaptchaException error) =>
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(height: 8),
                      Text(
                        error.message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _captchaController.reload,
                        child: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await _captchaController.reload();
                    _log('已重新加载验证码');
                  } on DxCaptchaException catch (error) {
                    _log('重载失败：${error.message}');
                  }
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新加载'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _captchaController.reset();
                  setState(() {
                    _token = null;
                    _lastFailure = null;
                  });
                  _log('状态已重置');
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('重置状态'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultPanel(ThemeData theme, bool isDark) {
    final bool success = _token != null;
    final Color accent = success
        ? const Color(0xFF1F9254)
        : theme.colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success
            ? const Color(0xFF1F9254).withValues(alpha: 0.08)
            : (isDark ? const Color(0xFF26262B) : const Color(0xFFF4F5F9)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success
              ? const Color(0xFF1F9254).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF33333A) : const Color(0xFFE4E6EE)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                success ? Icons.verified_user : Icons.info_outline,
                size: 18,
                color: success ? accent : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                success ? '验证通过' : '尚未验证',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: success ? accent : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            _token ?? '验证成功后会在此显示 token，可用于服务端二次校验',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: success
                  ? (isDark ? Colors.white70 : Colors.black87)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_lastFailure != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _lastFailure!,
              style: theme.textTheme.bodySmall?.copyWith(color: accent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogPanel(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('事件日志', style: theme.textTheme.titleSmall),
            if (_logs.isNotEmpty)
              TextButton(
                onPressed: () => setState(_logs.clear),
                child: const Text('清空'),
              ),
          ],
        ),
        Container(
          width: double.infinity,
          height: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111114) : const Color(0xFF1B1D22),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _logs.isEmpty
              ? const Center(
                  child: Text(
                    '暂无事件',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Color(0xFF9BE6B8),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
