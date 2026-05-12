import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/oht_manual/presentation/controllers/oht_manual_controller.dart';
import 'features/oht_manual/presentation/screens/connection_screen.dart';
import 'features/oht_manual/presentation/screens/login_screen.dart';
import 'features/oht_manual/presentation/screens/oht_manual_screen.dart';

enum _AppScreen { login, connection, main }

class OhtManualApp extends StatefulWidget {
  const OhtManualApp({super.key});

  @override
  State<OhtManualApp> createState() => _OhtManualAppState();
}

class _OhtManualAppState extends State<OhtManualApp> {
  late final OhtManualController _controller;
  _AppScreen _screen = _AppScreen.login;
  String _username = '';

  @override
  void initState() {
    super.initState();
    _controller = OhtManualController();
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

  void _onConnected() => setState(() => _screen = _AppScreen.main);

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
          onConnected: _onConnected,
          onLogout: _onLogout,
        );
      case _AppScreen.main:
        return OhtManualScreen(
          controller: _controller,
          username: _username,
          onDisconnect: _onDisconnect,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OHT Control System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: _buildScreen(),
    );
  }
}
