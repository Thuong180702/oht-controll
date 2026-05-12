enum CommunicationProtocol {
  mock('Mock'),
  websocket('WebSocket'),
  mqtt('MQTT');

  const CommunicationProtocol(this.label);

  final String label;
}
