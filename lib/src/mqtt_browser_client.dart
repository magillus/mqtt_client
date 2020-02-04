/*
 * Package : mqtt_browser_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 21/01/2020
 * Copyright :  S.Hamblett
 */

part of mqtt_browser_client;

class MqttBrowserClient extends MqttClient {
  /// Initializes a new instance of the MqttServerClient class using the
  /// default Mqtt Port.
  /// The server hostname to connect to
  /// The client identifier to use to connect with
  MqttBrowserClient(String server, String clientIdentifier)
      : super(server, clientIdentifier);

  /// Initializes a new instance of the MqttServerClient class using
  /// the supplied Mqtt Port.
  /// The server hostname to connect to
  /// The client identifier to use to connect with
  /// The port to use
  MqttBrowserClient.withPort(String server, String clientIdentifier, int port)
      : super.withPort(server, clientIdentifier, port);

  /// Performs a connect to the message broker with an optional
  /// username and password for the purposes of authentication.
  /// If a username and password are supplied these will override
  /// any previously set in a supplied connection message so if you
  /// supply your own connection message and use the authenticateAs method to
  /// set these parameters do not set them again here.
  @override
  Future<MqttClientConnectionStatus> connect(
      [String username, String password]) async {
    checkCredentials(username, password);
    // Set the authentication parameters in the connection
    // message if we have one.
    connectionMessage?.authenticateAs(username, password);

    // Do the connection
    clientEventBus = events.EventBus();
    connectionHandler = SynchronousMqttBrowserConnectionHandler(clientEventBus);
    if (websocketProtocolString != null) {
      connectionHandler.websocketProtocols = websocketProtocolString;
    }
    connectionHandler.onDisconnected = internalDisconnect;
    connectionHandler.onConnected = onConnected;
    publishingManager = PublishingManager(connectionHandler, clientEventBus);
    subscriptionsManager = SubscriptionsManager(
        connectionHandler, publishingManager, clientEventBus);
    subscriptionsManager.onSubscribed = onSubscribed;
    subscriptionsManager.onUnsubscribed = onUnsubscribed;
    subscriptionsManager.onSubscribeFail = onSubscribeFail;
    updates = subscriptionsManager.subscriptionNotifier.changes;
    keepAlive = MqttConnectionKeepAlive(connectionHandler, keepAlivePeriod);
    if (pongCallback != null) {
      keepAlive.pongCallback = pongCallback;
    }
    final connectMessage = getConnectMessage(username, password);
    return connectionHandler.connect(server, port, connectMessage);
  }
}
