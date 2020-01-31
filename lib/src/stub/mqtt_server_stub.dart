import '../../mqtt_client.dart';
import '../../mqtt_server_client.dart';

MqttClient createClientWithPort(
        String server, String clientIdentifier, int port, int wsPort) =>
    MqttServerClient.withPort(server, clientIdentifier, port);
