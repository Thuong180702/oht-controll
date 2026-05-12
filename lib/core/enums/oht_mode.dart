enum OhtMode { manual, auto, maintenance, error }

extension OhtModeLabel on OhtMode {
  String get label {
    switch (this) {
      case OhtMode.manual:
        return 'Manual';
      case OhtMode.auto:
        return 'Auto';
      case OhtMode.maintenance:
        return 'Maintenance';
      case OhtMode.error:
        return 'Error';
    }
  }

  static OhtMode fromWire(String? value) {
    switch (value) {
      case 'manual':
        return OhtMode.manual;
      case 'maintenance':
        return OhtMode.maintenance;
      case 'error':
        return OhtMode.error;
      case 'auto':
      default:
        return OhtMode.auto;
    }
  }
}
