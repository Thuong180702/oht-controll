import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/enums/communication_protocol.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/oht_manual_controller.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    required this.controller,
    required this.username,
    required this.onConnected,
    required this.onLogout,
    super.key,
  });

  final OhtManualController controller;
  final String username;
  final VoidCallback onConnected;
  final VoidCallback onLogout;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  final _hostCtrl = TextEditingController(text: '192.168.1.100');
  final _portCtrl = TextEditingController(text: '8080');
  final _pathCtrl = TextEditingController(text: '/ws');
  final _hostFocus = FocusNode();
  final _portFocus = FocusNode();
  final _pathFocus = FocusNode();
  CommunicationProtocol _protocol = CommunicationProtocol.websocket;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    // Parse existing URL
    final url = widget.controller.webSocketUrl;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      _hostCtrl.text = uri.host.isNotEmpty ? uri.host : '192.168.1.100';
      _portCtrl.text = uri.port > 0 ? uri.port.toString() : '8080';
      _pathCtrl.text = uri.path.isNotEmpty ? uri.path : '/ws';
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _pathCtrl.dispose();
    _hostFocus.dispose();
    _portFocus.dispose();
    _pathFocus.dispose();
    _animCtrl.dispose();
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
      _showConnectError('Khong ket noi duoc. Khong nhan du lieu trong 3 giay.');
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
    if (mounted) {
      setState(() => _connecting = false);
      widget.onConnected();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // Top bar
            _TopBar(username: widget.username, onLogout: widget.onLogout),
            // Content
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(
                          icon: Icons.cable_rounded,
                          title: 'Cấu hình kết nối',
                          subtitle:
                              'Thiết lập địa chỉ và giao thức kết nối tới OHT',
                        ),
                        const SizedBox(height: 24),
                        // Protocol selector
                        _PanelCard(
                          title: 'Giao thức truyền thông',
                          child: Row(
                            children: CommunicationProtocol.values.map((p) {
                              final selected = _protocol == p;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: _ProtocolCard(
                                    protocol: p,
                                    selected: selected,
                                    onTap: () => setState(() => _protocol = p),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Address
                        if (_protocol != CommunicationProtocol.mock)
                          _PanelCard(
                            title: 'Địa chỉ kết nối',
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _hostCtrl,
                                        focusNode: _hostFocus,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        decoration: const InputDecoration(
                                          labelText: 'Địa chỉ IP / Host',
                                          prefixIcon: Icon(Icons.dns_rounded),
                                          hintText: '192.168.1.100',
                                        ),
                                        keyboardType: TextInputType.url,
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_portFocus),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 1,
                                      child: TextFormField(
                                        controller: _portCtrl,
                                        focusNode: _portFocus,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        decoration: const InputDecoration(
                                          labelText: 'Port',
                                          prefixIcon: Icon(
                                            Icons.router_rounded,
                                          ),
                                          hintText: '8080',
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(5),
                                        ],
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) => FocusScope.of(
                                          context,
                                        ).requestFocus(_pathFocus),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _pathCtrl,
                                  focusNode: _pathFocus,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    labelText: 'Path / Topic',
                                    prefixIcon: Icon(Icons.link_rounded),
                                    hintText: '/ws',
                                  ),
                                  keyboardType: TextInputType.url,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _connect(),
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                // URL preview
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySurface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _buildUrl,
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _connecting ? null : _connectMock,
                                icon: const Icon(Icons.science_rounded),
                                label: const Text('Chế độ Mock (Demo)'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(100, 52),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _connecting ? null : _connect,
                                icon: _connecting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.link_rounded),
                                label: Text(
                                  _connecting ? 'Đang kết nối...' : 'Kết nối',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(100, 52),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.username, required this.onLogout});
  final String username;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.precision_manufacturing_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Text(
            'OHT Control System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.account_circle_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                username,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
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

  IconData get _icon {
    switch (protocol) {
      case CommunicationProtocol.websocket:
        return Icons.wifi_rounded;
      case CommunicationProtocol.mqtt:
        return Icons.hub_rounded;
      case CommunicationProtocol.mock:
        return Icons.science_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.surfaceBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _icon,
              color: selected ? AppColors.primary : AppColors.textHint,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              protocol.label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
