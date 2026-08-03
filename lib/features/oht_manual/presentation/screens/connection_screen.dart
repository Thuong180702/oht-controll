import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/enums/communication_protocol.dart';
import '../../../../core/enums/connection_phase.dart';
import '../../../../core/enums/manual_command_type.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_locale.dart';
import '../controllers/oht_manual_controller.dart';
import '../widgets/emergency_alert_frame.dart';
import '../widgets/industrial_top_bar.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    required this.controller,
    required this.username,
    required this.languageCode,
    required this.onConnected,
    required this.onLogout,
    required this.onTopNavSelected,
    super.key,
  });

  final OhtManualController controller;
  final String username;
  final String languageCode;
  final VoidCallback onConnected;
  final VoidCallback onLogout;
  final ValueChanged<IndustrialTopBarItem> onTopNavSelected;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _hostCtrl = TextEditingController(text: '10.14.64.7');
  final _portCtrl = TextEditingController(text: '80');
  final _pathCtrl = TextEditingController(text: '/ws');
  final _operatorCtrl = TextEditingController(text: 'oht_operator');
  final _passwordCtrl = TextEditingController(text: '••••••••');
  final _hostFocus = FocusNode();
  final _portFocus = FocusNode();
  final _pathFocus = FocusNode();

  CommunicationProtocol _protocol = CommunicationProtocol.websocket;
  bool _connecting = false;
  bool _authEnabled = true;

  @override
  void initState() {
    super.initState();
    final url = widget.controller.webSocketUrl;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      _hostCtrl.text = uri.host.isNotEmpty ? uri.host : '192.168.1.100';
      _portCtrl.text = uri.port > 0 ? uri.port.toString() : '80';
      _pathCtrl.text = uri.path.isNotEmpty ? uri.path : '/ws';
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _pathCtrl.dispose();
    _operatorCtrl.dispose();
    _passwordCtrl.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    _pathFocus.dispose();
    super.dispose();
  }

  String get _buildUrl {
    if (_protocol == CommunicationProtocol.mock) return 'mock://local-oht';
    final host = _hostCtrl.text.trim();
    final port = _portCtrl.text.trim();
    final path = _pathCtrl.text.trim();
    final scheme = _protocol == CommunicationProtocol.mqtt ? 'mqtt' : 'ws';
    return '$scheme://$host:$port$path';
  }

  void _hideKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (defaultTargetPlatform == TargetPlatform.android) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  void _showConnectError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _connect() async {
    _hideKeyboard();
    setState(() => _connecting = true);
    await widget.controller.updateConnectionSettings(
      protocol: _protocol,
      webSocketUrl: _buildUrl,
    );
    await widget.controller.connect();
    final ok = await widget.controller.waitForFirstTelemetry(
      const Duration(seconds: 3),
    );
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!ok) {
      _showConnectError(
        AppLocale.t('Không kết nối được. Không nhận dữ liệu trong 3 giây.'),
      );
      return;
    }
    widget.onConnected();
  }

  Future<void> _connectMock() async {
    _hideKeyboard();
    setState(() => _connecting = true);
    await widget.controller.updateConnectionSettings(
      protocol: CommunicationProtocol.mock,
      webSocketUrl: 'mock://local-oht',
    );
    await widget.controller.connect();
    if (!mounted) return;
    setState(() => _connecting = false);
    widget.onConnected();
  }

  @override
  Widget build(BuildContext context) {
    final phase = widget.controller.connectionStatus.phase;
    final (statusLabel, statusColor) = _statusMeta(phase);
    final emergencyActive =
        widget.controller.emergencyStopActive ||
        widget.controller.hasCriticalError;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: EmergencyAlertFrame(
        active: emergencyActive,
        child: Column(
          children: [
            IndustrialTopBar(
              activeItem: IndustrialTopBarItem.connection,
              username: widget.username,
              languageCode: widget.languageCode,
              statusLabel: statusLabel,
              statusColor: statusColor,
              emergencyActive: emergencyActive,
              onItemSelected: widget.onTopNavSelected,
              onEmergencyPressed: () {
                widget.controller.sendManualCommand(
                  ManualCommandType.emergencyStop,
                );
                if (mounted) setState(() {});
              },
              onExit: () async {
                if (widget.controller.isConnected) {
                  await widget.controller.disconnect();
                  if (mounted) setState(() {});
                } else {
                  widget.onLogout();
                }
              },
              exitLabel: widget.controller.isConnected
                  ? AppLocale.t('Ngắt kết nối')
                  : AppLocale.t('Đăng xuất'),
              exitIcon: widget.controller.isConnected
                  ? Icons.link_off_rounded
                  : Icons.logout_rounded,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 980;
                  final content = stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StatusPanel(
                              statusLabel: statusLabel,
                              statusColor: statusColor,
                              endpoint: _buildUrl,
                            ),
                            const SizedBox(height: 16),
                            _ConfigPanel(
                              protocol: _protocol,
                              onProtocolChanged: (value) =>
                                  setState(() => _protocol = value),
                              hostCtrl: _hostCtrl,
                              portCtrl: _portCtrl,
                              pathCtrl: _pathCtrl,
                              operatorCtrl: _operatorCtrl,
                              passwordCtrl: _passwordCtrl,
                              hostFocus: _hostFocus,
                              portFocus: _portFocus,
                              pathFocus: _pathFocus,
                              authEnabled: _authEnabled,
                              onAuthChanged: (value) =>
                                  setState(() => _authEnabled = value),
                              urlPreview: _buildUrl,
                              connecting: _connecting,
                              onConnect: _connect,
                              onConnectMock: _connectMock,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 320,
                              child: _StatusPanel(
                                statusLabel: statusLabel,
                                statusColor: statusColor,
                                endpoint: _buildUrl,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _ConfigPanel(
                                protocol: _protocol,
                                onProtocolChanged: (value) =>
                                    setState(() => _protocol = value),
                                hostCtrl: _hostCtrl,
                                portCtrl: _portCtrl,
                                pathCtrl: _pathCtrl,
                                operatorCtrl: _operatorCtrl,
                                passwordCtrl: _passwordCtrl,
                                hostFocus: _hostFocus,
                                portFocus: _portFocus,
                                pathFocus: _pathFocus,
                                authEnabled: _authEnabled,
                                onAuthChanged: (value) =>
                                    setState(() => _authEnabled = value),
                                urlPreview: _buildUrl,
                                connecting: _connecting,
                                onConnect: _connect,
                                onConnectMock: _connectMock,
                              ),
                            ),
                          ],
                        );

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: content,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.statusLabel,
    required this.statusColor,
    required this.endpoint,
  });

  final String statusLabel;
  final Color statusColor;
  final String endpoint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelCard(
          title: AppLocale.t('Trạng thái hiện tại'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusLine(
                label: 'Vehicle Link: 402-B',
                color: statusColor,
                value: statusLabel,
              ),
              const SizedBox(height: 10),
              const _BulletLine(text: 'MCS Server'),
              const _BulletLine(text: 'Local Network', active: true),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LAST CONNECTED',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      endpoint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: null,
          icon: Icon(Icons.settings_input_component_outlined, size: 16),
          label: Text(AppLocale.t('KẾT NỐI')),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocale.t('Mạng không dây (WLAN)\nBảo mật & Chứng chỉ'),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({
    required this.protocol,
    required this.onProtocolChanged,
    required this.hostCtrl,
    required this.portCtrl,
    required this.pathCtrl,
    required this.operatorCtrl,
    required this.passwordCtrl,
    required this.hostFocus,
    required this.portFocus,
    required this.pathFocus,
    required this.authEnabled,
    required this.onAuthChanged,
    required this.urlPreview,
    required this.connecting,
    required this.onConnect,
    required this.onConnectMock,
  });

  final CommunicationProtocol protocol;
  final ValueChanged<CommunicationProtocol> onProtocolChanged;
  final TextEditingController hostCtrl;
  final TextEditingController portCtrl;
  final TextEditingController pathCtrl;
  final TextEditingController operatorCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode hostFocus;
  final FocusNode portFocus;
  final FocusNode pathFocus;
  final bool authEnabled;
  final ValueChanged<bool> onAuthChanged;
  final String urlPreview;
  final bool connecting;
  final VoidCallback onConnect;
  final VoidCallback onConnectMock;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: AppLocale.t('Cấu hình giao thức kết nối'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final item in const [
                CommunicationProtocol.mqtt,
                CommunicationProtocol.websocket,
                CommunicationProtocol.mock,
              ]) ...[
                Expanded(
                  child: _ProtocolCard(
                    protocol: item,
                    selected: protocol == item,
                    onTap: () => onProtocolChanged(item),
                  ),
                ),
                if (item != CommunicationProtocol.mock)
                  const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _IndustrialTextField(
                  controller: hostCtrl,
                  focusNode: hostFocus,
                  label: AppLocale.t('ĐỊA CHỈ IP / HOST'),
                  hint: '192.168.1.100',
                  icon: Icons.dns_outlined,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(portFocus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IndustrialTextField(
                  controller: portCtrl,
                  focusNode: portFocus,
                  label: AppLocale.t('CỔNG (PORT)'),
                  hint: '8083',
                  icon: Icons.router_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(pathFocus),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _IndustrialTextField(
            controller: pathCtrl,
            focusNode: pathFocus,
            label: AppLocale.t('CẤU TRÚC TOPIC CƠ BẢN / BASE TOPIC'),
            hint: '/ws',
            icon: Icons.link_outlined,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onConnect(),
          ),
          const SizedBox(height: 14),
          _UrlPreview(url: urlPreview),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocale.t('Yêu cầu xác thực'),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      value: authEnabled,
                      onChanged: onAuthChanged,
                      activeThumbColor: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _IndustrialTextField(
                        controller: operatorCtrl,
                        label: AppLocale.t('TÊN ĐĂNG NHẬP'),
                        hint: 'oht_operator',
                        icon: Icons.person_outline_rounded,
                        enabled: authEnabled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _IndustrialTextField(
                        controller: passwordCtrl,
                        label: AppLocale.t('MẬT KHẨU'),
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        enabled: authEnabled,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: connecting ? null : onConnectMock,
                  icon: Icon(Icons.science_outlined, size: 16),
                  label: Text(AppLocale.t('Chế độ Mock (Demo)')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 190,
                child: FilledButton.icon(
                  onPressed: connecting ? null : onConnect,
                  icon: connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.settings_input_component_outlined),
                  label: Text(
                    AppLocale.t(connecting ? 'ĐANG KẾT NỐI...' : 'KẾT NỐI'),
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({
    required this.protocol,
    required this.selected,
    required this.onTap,
  });

  final CommunicationProtocol protocol;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurfaceLight : AppColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 17, color: AppColors.textSecondary),
                const Spacer(),
                if (selected)
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              protocol.label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 10,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (protocol) {
    CommunicationProtocol.websocket => Icons.wifi_tethering_outlined,
    CommunicationProtocol.mqtt => Icons.hub_outlined,
    CommunicationProtocol.mock => Icons.memory_outlined,
  };

  String get _description => switch (protocol) {
    CommunicationProtocol.websocket => AppLocale.t(
      'Giao tiếp thời gian thực qua WebSocket.',
    ),
    CommunicationProtocol.mqtt => AppLocale.t('Tối ưu cho gateway và broker.'),
    CommunicationProtocol.mock => AppLocale.t('Mô phỏng cục bộ để kiểm thử.'),
  };
}

class _IndustrialTextField extends StatelessWidget {
  const _IndustrialTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) {},
          decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
        ),
      ],
    );
  }
}

class _UrlPreview extends StatelessWidget {
  const _UrlPreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.route_outlined, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.copy_outlined, color: AppColors.textHint, size: 15),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text, this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textHint;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

(String, Color) _statusMeta(ConnectionPhase phase) => switch (phase) {
  ConnectionPhase.connected => ('ONLINE', AppColors.success),
  ConnectionPhase.connecting => ('CONNECTING', AppColors.warning),
  ConnectionPhase.timeout => ('TIMEOUT', AppColors.error),
  ConnectionPhase.error => ('ERROR', AppColors.error),
  ConnectionPhase.disconnected => ('OFFLINE', AppColors.textHint),
};
