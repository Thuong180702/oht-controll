enum OhtMessageType {
  state,
  telemetry,
  manualAck,
  ack,
  nack,
  event,
  unknown;

  static OhtMessageType fromWire(String? value) {
    switch (value) {
      case 'state':
        return OhtMessageType.state;
      case 'telemetry':
        return OhtMessageType.telemetry;
      case 'manual_ack':
        return OhtMessageType.manualAck;
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
