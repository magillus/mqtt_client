import '../../mqtt_client.dart';
import '../../mqtt_browser_client.dart';

MqttClient createClientWithPort(
        String server, String clientIdentifier, int port) =>
    MqttBrowserClient.withPort('ws://$server/ws', clientIdentifier, port);
