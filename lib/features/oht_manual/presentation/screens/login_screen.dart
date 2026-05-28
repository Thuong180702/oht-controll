import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_locale.dart';
import '../../../../core/utils/auth_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.onLogin, super.key});

  final void Function(String username) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController(
    text: AuthStorage.defaultUsername,
  );
  final _passwordCtrl = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _loading = false;
  bool _authReady = false;
  String _storedPassword = AuthStorage.defaultPassword;

  @override
  void initState() {
    super.initState();
    _loadAuth();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
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
      SnackBar(
        content: Text(AppLocale.t('Sai tên đăng nhập hoặc mật khẩu.')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_authReady) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 450));

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username != AuthStorage.defaultUsername ||
        password != _storedPassword) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showAuthError();
      return;
    }

    if (mounted) widget.onLogin(username);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isAndroidCompactLandscape =
        defaultTargetPlatform == TargetPlatform.android &&
        size.width > size.height &&
        size.height < 620;
    final isWide = size.width > 840 && !isAndroidCompactLandscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isWide
          ? Row(
              children: [
                Expanded(child: _BrandingPanel()),
                Expanded(child: _LoginPane(form: _buildForm(context, isWide))),
              ],
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    const _MobileBrand(),
                    const SizedBox(height: 24),
                    _LoginPane(form: _buildForm(context, isWide)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildForm(BuildContext context, bool isWide) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocale.t('Đăng nhập hệ thống'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocale.t('Mã Terminal: VN-40'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          _FieldLabel(AppLocale.t('MÃ NGƯỜI VẬN HÀNH')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameCtrl,
            focusNode: _usernameFocus,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: AppLocale.t('Nhập mã nhân viên vận hành'),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocus),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? AppLocale.t('Nhập tên đăng nhập')
                : null,
          ),
          const SizedBox(height: 16),
          _FieldLabel(AppLocale.t('MÃ KHÓA BẢO MẬT')),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordCtrl,
            focusNode: _passwordFocus,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: AppLocale.t('Nhập mật khẩu'),
              prefixIcon: Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscure
                    ? AppLocale.t('Hiện mật khẩu')
                    : AppLocale.t('Ẩn mật khẩu'),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textHint,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) => (value == null || value.isEmpty)
                ? AppLocale.t('Nhập mật khẩu')
                : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              key: const Key('login_submit_button'),
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
                  : Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                AppLocale.t(
                  _loading ? 'ĐANG XÁC THỰC...' : 'XÁC THỰC VÀ ĐĂNG NHẬP',
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'v2.4.1 (${AppLocale.t('Ổn định')})',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginPane extends StatelessWidget {
  const _LoginPane({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: form,
        ),
      ),
    );
  }
}

class _BrandingPanel extends StatelessWidget {
  const _BrandingPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Padding(
            padding: const EdgeInsets.all(72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BrandIcon(size: 64),
                SizedBox(height: 28),
                Text(
                  AppLocale.t('Hệ Thống Điều khiển\nOHT'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    height: 1.14,
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: 430,
                  child: Text(
                    AppLocale.t(
                      'Hệ thống vận chuyển tự động Overhead Hoist Transport trong nhà máy sản xuất, hỗ trợ vận hành thủ công và giám sát an toàn theo thời gian thực.',
                    ),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.65,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Spacer(),
                _BuildBadge(
                  icon: Icons.verified_outlined,
                  label: AppLocale.t('PHIÊN BẢN'),
                  value: '2.4.1 (${AppLocale.t('Ổn định')})',
                ),
                SizedBox(height: 12),
                _BuildBadge(
                  icon: Icons.update_rounded,
                  label: AppLocale.t('PHIÊN BẢN'),
                  value: '2.4.1 (${AppLocale.t('Ổn định')})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBrand extends StatelessWidget {
  const _MobileBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BrandIcon(size: 54),
        SizedBox(height: 12),
        Text(
          'OHT CONTROL SYSTEM',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(
        Icons.precision_manufacturing_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}

class _BuildBadge extends StatelessWidget {
  const _BuildBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF004174).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;

    const step = 56.0;
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
