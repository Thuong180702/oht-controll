import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';

import 'dart:async';

import 'core/theme/app_theme.dart';
import 'core/utils/app_locale.dart';
import 'core/utils/app_preferences.dart';
import 'core/utils/auth_storage.dart';
import 'core/utils/session_storage.dart';
import 'features/oht_manual/presentation/controllers/oht_manual_controller.dart';
import 'features/oht_manual/presentation/screens/connection_screen.dart';
import 'features/oht_manual/presentation/screens/login_screen.dart';
import 'features/oht_manual/presentation/screens/oht_manual_screen.dart';
import 'features/oht_manual/presentation/widgets/industrial_top_bar.dart';

enum _AppScreen { login, connection, main }

class OhtManualApp extends StatefulWidget {
  const OhtManualApp({this.forceAndroidViewport, super.key});

  final bool? forceAndroidViewport;

  @override
  State<OhtManualApp> createState() => _OhtManualAppState();
}

class _OhtManualAppState extends State<OhtManualApp> {
  late final OhtManualController _controller;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  _AppScreen _screen = _AppScreen.login;
  IndustrialTopBarItem _activeMainTab = IndustrialTopBarItem.dashboard;
  String _username = '';
  String _languageCode = AppPreferences.defaultLanguageCode;
  ThemeMode _themeMode = AppPreferences.defaultThemeMode;
  bool _prefsLoaded = false;

  Timer? _sessionCheckTimer;

  @override
  void initState() {
    super.initState();
    _controller = OhtManualController();

    // Instant synchronous read of session from localStorage
    final savedUser = AppPreferences.getLoggedInUser();
    final savedScreen = AppPreferences.getSavedScreen();
    if (savedUser != null && savedUser.trim().isNotEmpty) {
      _username = savedUser.trim();
      if (savedScreen == 'main') {
        _screen = _AppScreen.main;
      } else {
        _screen = _AppScreen.connection;
      }
    } else {
      _screen = _AppScreen.login;
    }
    _prefsLoaded = true;

    _loadAsyncPreferences();

    // Periodic background session check (every 5 seconds) for real-time cross-device logout
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkLiveSession();
    });
  }

  @override
  void dispose() {
    _sessionCheckTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onLogin(String username) async {
    setState(() {
      _username = username;
      _screen = _AppScreen.connection;
    });
    await AppPreferences.setLoggedInUser(username);
    await AppPreferences.setSavedScreen('connection');
  }

  Future<void> _onConnected() async {
    setState(() {
      _screen = _AppScreen.main;
      _activeMainTab = IndustrialTopBarItem.dashboard;
    });
    await AppPreferences.setSavedScreen('main');
  }

  Future<void> _onDisconnect() async {
    await _controller.disconnect();
    setState(() => _screen = _AppScreen.connection);
    await AppPreferences.setSavedScreen('connection');
  }

  Future<void> _onLogout() async {
    await _controller.disconnect();
    await SessionStorage.removeItem('active_session_password');
    setState(() {
      _username = '';
      _screen = _AppScreen.login;
    });
    await AppPreferences.clearSession();
  }

  Future<void> _onTopNavSelected(IndustrialTopBarItem item) async {
    if (_screen == _AppScreen.login) return;
    if (item == IndustrialTopBarItem.connection) {
      setState(() => _screen = _AppScreen.connection);
      await AppPreferences.setSavedScreen('connection');
      return;
    }
    setState(() {
      _screen = _AppScreen.main;
      _activeMainTab = item;
    });
    await AppPreferences.setSavedScreen('main');
  }

  Future<void> _loadAsyncPreferences() async {
    final languageCode = await AppPreferences.getLanguageCode();
    final themeMode = await AppPreferences.getThemeMode();

    if (!mounted) return;
    setState(() {
      _languageCode = languageCode;
      _themeMode = themeMode;
    });

    await _checkLiveSession();
  }

  Future<void> _checkLiveSession() async {
    if (_screen == _AppScreen.login || !mounted) return;
    try {
      final isValid = await AuthStorage.isSessionValid();
      if (!isValid && mounted && _screen != _AppScreen.login) {
        await _onLogout();
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.t('Mật khẩu đã bị thay đổi từ thiết bị khác. Vui lòng đăng nhập lại.'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SessionCheck] Error checking live session: $e');
    }
  }

  Future<void> _setLanguageCode(String languageCode) async {
    final normalized = languageCode == 'en' ? 'en' : 'vi';
    setState(() => _languageCode = normalized);
    await AppPreferences.setLanguageCode(normalized);
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    final normalized = themeMode == ThemeMode.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    setState(() => _themeMode = normalized);
    await AppPreferences.setThemeMode(normalized);
  }

  Widget _buildScreen() {
    if (!_prefsLoaded) {
      return const ColoredBox(color: Color(0xFF07111F));
    }

    switch (_screen) {
      case _AppScreen.login:
        return LoginScreen(onLogin: _onLogin);
      case _AppScreen.connection:
        return ConnectionScreen(
          controller: _controller,
          username: _username,
          languageCode: _languageCode,
          onConnected: _onConnected,
          onLogout: _onLogout,
          onTopNavSelected: _onTopNavSelected,
        );
      case _AppScreen.main:
        return OhtManualScreen(
          controller: _controller,
          username: _username,
          activeItem: _activeMainTab,
          languageCode: _languageCode,
          themeMode: _themeMode,
          onLanguageChanged: _setLanguageCode,
          onThemeModeChanged: _setThemeMode,
          onTopNavSelected: _onTopNavSelected,
          onDisconnect: _onDisconnect,
          onLogout: _onLogout,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(_themeMode == ThemeMode.dark);
    AppLocale.setLanguage(_languageCode);
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'OHT Control System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: Locale(_languageCode),
      builder: (context, child) {
        return _AndroidWindowsViewport(
          enabled: widget.forceAndroidViewport ??
              (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _buildScreen(),
    );
  }
}

class _AndroidWindowsViewport extends StatelessWidget {
  const _AndroidWindowsViewport({required this.enabled, required this.child});

  static const Size _designSize = Size(1920, 1080);

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    final media = MediaQuery.of(context);
    final canvasSize = _resolveCanvasSize(media.size);
    return ColoredBox(
      key: const Key('android_windows_viewport'),
      color: AppColors.background,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            key: const Key('android_windows_canvas'),
            width: canvasSize.width,
            height: canvasSize.height,
            child: MediaQuery(
              data: media.copyWith(
                size: canvasSize,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                textScaler: TextScaler.noScaling,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Size _resolveCanvasSize(Size screenSize) {
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return _designSize;
    }

    final screenAspect = screenSize.width / screenSize.height;
    final designAspect = _designSize.width / _designSize.height;
    if (screenAspect < designAspect) {
      return Size(_designSize.width, _designSize.width / screenAspect);
    }

    return Size(_designSize.height * screenAspect, _designSize.height);
  }
}
