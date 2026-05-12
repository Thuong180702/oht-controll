enum ConnectionPhase { disconnected, connecting, connected, timeout, error }

extension ConnectionPhaseLabel on ConnectionPhase {
  String get label {
    switch (this) {
      case ConnectionPhase.disconnected:
        return 'Disconnected';
      case ConnectionPhase.connecting:
        return 'Connecting';
      case ConnectionPhase.connected:
        return 'Connected';
      case ConnectionPhase.timeout:
        return 'Timeout';
      case ConnectionPhase.error:
        return 'Error';
    }
  }
}
