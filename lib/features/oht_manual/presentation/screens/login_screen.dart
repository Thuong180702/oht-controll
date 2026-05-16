import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/auth_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onLogin, super.key});

  final void Function(String username) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController(
    text: AuthStorage.defaultUsername,
  );
  final _passwordCtrl = TextEditingController(text: '');
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  bool _authReady = false;
  String _storedPassword = AuthStorage.defaultPassword;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadAuth();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAuth() async {
    await AuthStorage.ensureSeeded();
    final pwd = await AuthStorage.getPassword();
    if (!mounted) return;
    setState(() {
      _storedPassword = pwd;
      _authReady = true;
    });
  }

  void _showAuthError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sai tên đăng nhập hoặc mật khẩu.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_authReady) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username != AuthStorage.defaultUsername ||
        password != _storedPassword) {
      if (mounted) {
        setState(() => _loading = false);
        _showAuthError();
      }
      return;
    }
    if (mounted) {
      widget.onLogin(username);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isAndroidCompactLandscape =
        defaultTargetPlatform == TargetPlatform.android &&
        size.width > size.height &&
        size.height < 620;
    final isWide = size.width > 800 && !isAndroidCompactLandscape;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Row(
        children: [
          // Left branding panel
          if (isWide) Expanded(flex: 5, child: _BrandingPanel()),
          // Right login form
          Expanded(
            flex: isWide ? 4 : 1,
            child: Container(
              color: AppColors.surface,
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 48,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo + title (mobile)
                              if (!isWide) ...[
                                Center(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.precision_manufacturing_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Đăng nhập hệ thống',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'OHT Manual Control & Monitoring',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 36),
                              TextFormField(
                                controller: _usernameCtrl,
                                focusNode: _usernameFocus,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                  labelText: 'Tên đăng nhập',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocus),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Nhập tên đăng nhập'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordCtrl,
                                focusNode: _passwordFocus,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'Mật khẩu',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textHint,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                height: 50,
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _submit,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.login_rounded),
                                  label: Text(
                                    _loading ? 'Đang xác thực...' : 'Đăng nhập',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  'v1.3.0 — OHT Control System',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.textHint),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandingPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryLight,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // Content
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.precision_manufacturing_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OHT Control',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Overhead Hoist Transport',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Hệ thống điều khiển\nOHT thông minh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Điều khiển, giám sát và chẩn đoán toàn bộ hệ thống\ntruyền động OHT theo thời gian thực.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: const [
                    _FeatureChip(
                      icon: Icons.speed_rounded,
                      label: 'Thời gian thực',
                    ),
                    _FeatureChip(
                      icon: Icons.shield_rounded,
                      label: 'An toàn E-Stop',
                    ),
                    _FeatureChip(
                      icon: Icons.analytics_rounded,
                      label: 'Giám sát IO',
                    ),
                    _FeatureChip(
                      icon: Icons.history_rounded,
                      label: 'Lưu log lỗi',
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
