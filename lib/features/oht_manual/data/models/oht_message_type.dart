enum OhtMessageType {
  telemetry,
  ack,
  nack,
  event,
  unknown;

  static OhtMessageType fromWire(String? value) {
    switch (value) {
      case 'telemetry':
        return OhtMessageType.telemetry;
      case 'ack':
        return OhtMessageType.ack;
      case 'nack':
        return OhtMessageType.nack;
      case 'event':
        return OhtMessageType.event;
      default:
        return OhtMessageType.unknown;
    }
  }
}
