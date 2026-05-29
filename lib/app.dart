import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/utils/app_locale.dart';
import 'core/utils/app_preferences.dart';
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
  _AppScreen _screen = _AppScreen.login;
  IndustrialTopBarItem _activeMainTab = IndustrialTopBarItem.dashboard;
  String _username = '';
  String _languageCode = AppPreferences.defaultLanguageCode;
  ThemeMode _themeMode = AppPreferences.defaultThemeMode;

  @override
  void initState() {
    super.initState();
    _controller = OhtManualController();
    _loadPreferences();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLogin(String username) {
    setState(() {
      _username = username;
      _screen = _AppScreen.connection;
    });
  }

  void _onConnected() => setState(() {
    _screen = _AppScreen.main;
    _activeMainTab = IndustrialTopBarItem.dashboard;
  });

  Future<void> _onDisconnect() async {
    await _controller.disconnect();
    setState(() => _screen = _AppScreen.connection);
  }

  void _onLogout() {
    _controller.disconnect();
    setState(() {
      _username = '';
      _screen = _AppScreen.login;
    });
  }

  void _onTopNavSelected(IndustrialTopBarItem item) {
    if (_screen == _AppScreen.login) return;
    setState(() {
      if (item == IndustrialTopBarItem.connection) {
        _screen = _AppScreen.connection;
        return;
      }
      _screen = _AppScreen.main;
      _activeMainTab = item;
    });
  }

  Future<void> _loadPreferences() async {
    final languageCode = await AppPreferences.getLanguageCode();
    final themeMode = await AppPreferences.getThemeMode();
    if (!mounted) return;
    setState(() {
      _languageCode = languageCode;
      _themeMode = themeMode;
    });
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
    // Do NOT wrap in AnimatedBuilder here — OhtManualScreen manages its own
    // AnimatedBuilder internally.  Wrapping at this level would cause the root
    // to recreate the entire screen on every telemetry tick, invalidating
    // descendant BuildContexts and triggering the "ancestor == this" assertion.
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
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(_themeMode == ThemeMode.dark);
    AppLocale.setLanguage(_languageCode);
    return MaterialApp(
      title: 'OHT Control System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      locale: Locale(_languageCode),
      builder: (context, child) {
        return _AndroidWindowsViewport(
          enabled: widget.forceAndroidViewport ?? Platform.isAndroid,
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
