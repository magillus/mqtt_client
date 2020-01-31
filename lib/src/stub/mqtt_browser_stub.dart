import '../../mqtt_client.dart';
import '../../mqtt_browser_client.dart';

MqttClient createClientWithPort(
        String server, String clientIdentifier, int port, int wsPort) =>
    MqttBrowserClient.withPort(
        'ws://$server/ws', clientIdentifier, wsPort ?? port);
