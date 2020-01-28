import '../../mqtt_client.dart';

MqttClient createClientWithPort(
        String server, String clientIdentifier, int port) =>
    throw UnsupportedError(
        'Cannot create a client without dart:html or dart:io.');
