/*
 * Package : mqtt_client
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 10/07/2017
 * Copyright :  S.Hamblett
 */

part of mqtt_client;

/// The client disconnect callback type
typedef DisconnectCallback = void Function();

/// The client Connect callback type
typedef ConnectCallback = void Function();

/// A client class for interacting with MQTT Data Packets.
/// Do not instantiate this class directly, instead instantiate
/// either a [MqttClientServer] class or an [MqttBrowserClient] as needed.
/// This class now provides common functionality between server side
/// and web based clients.
abstract class MqttClient {
  /// Initializes a new instance of the MqttClient class using the
  /// default Mqtt Port.
  /// The server hostname to connect to
  /// The client identifier to use to connect with
  MqttClient(this.server, this.clientIdentifier) {
    port = Constants.defaultMqttPort;
  }

  /// Initializes a new instance of the MqttClient class using
  /// the supplied Mqtt Port.
  /// The server hostname to connect to
  /// The client identifier to use to connect with
  /// The port to use
  MqttClient.withPort(this.server, this.clientIdentifier, this.port);

  /// Server name
  String server;

  /// Port number
  int port;

  /// Client identifier
  String clientIdentifier;

  /// The Handler that is managing the connection to the remote server.
  @protected
  IMqttConnectionHandler connectionHandler;

  /// The subscriptions manager responsible for tracking subscriptions.
  @protected
  SubscriptionsManager subscriptionsManager;

  /// Handles the connection management while idle.
  @protected
  MqttConnectionKeepAlive keepAlive;

  /// Keep alive period, seconds
  int keepAlivePeriod = Constants.defaultKeepAlive;

  /// Handles everything to do with publication management.
  @protected
  PublishingManager publishingManager;

  /// Published message stream. A publish message is added to this
  /// stream on completion of the message publishing protocol for a Qos level.
  /// Attach listeners only after connect has been called.
  Stream<MqttPublishMessage> get published =>
      publishingManager != null ? publishingManager.published.stream : null;

  /// Gets the current connection state of the Mqtt Client.
  /// Will be removed, use connectionStatus
  @Deprecated('Use ConnectionStatus, not this')
  MqttConnectionState get connectionState => connectionHandler != null
      ? connectionHandler.connectionStatus.state
      : MqttConnectionState.disconnected;

  final MqttClientConnectionStatus _connectionStatus =
      MqttClientConnectionStatus();

  Future<MqttClientConnectionStatus> connect(
      [String username, String password]);

  /// Gets the current connection status of the Mqtt Client.
  /// This is the connection state as above also with the broker return code.
  /// Set after every connection attempt.
  MqttClientConnectionStatus get connectionStatus => connectionHandler != null
      ? connectionHandler.connectionStatus
      : _connectionStatus;

  /// The connection message to use to override the default
  MqttConnectMessage connectionMessage;

  /// Client disconnect callback, called on unsolicited disconnect.
  DisconnectCallback onDisconnected;

  /// Client connect callback, called on successful connect
  ConnectCallback onConnected;

  /// Subscribed callback, function returns a void and takes a
  /// string parameter, the topic that has been subscribed to.
  SubscribeCallback _onSubscribed;

  /// On subscribed
  SubscribeCallback get onSubscribed => _onSubscribed;

  set onSubscribed(SubscribeCallback cb) {
    _onSubscribed = cb;
    subscriptionsManager?.onSubscribed = cb;
  }

  /// Subscribed failed callback, function returns a void and takes a
  /// string parameter, the topic that has failed subscription.
  /// Invoked either by subscribe if an invalid topic is supplied or on
  /// reception of a failed subscribe indication from the broker.
  SubscribeFailCallback _onSubscribeFail;

  /// On subscribed fail
  SubscribeFailCallback get onSubscribeFail => _onSubscribeFail;

  set onSubscribeFail(SubscribeFailCallback cb) {
    _onSubscribeFail = cb;
    subscriptionsManager?.onSubscribeFail = cb;
  }

  /// Unsubscribed callback, function returns a void and takes a
  /// string parameter, the topic that has been unsubscribed.
  UnsubscribeCallback _onUnsubscribed;

  /// On unsubscribed
  UnsubscribeCallback get onUnsubscribed => _onUnsubscribed;

  set onUnsubscribed(UnsubscribeCallback cb) {
    _onUnsubscribed = cb;
    subscriptionsManager?.onUnsubscribed = cb;
  }

  /// Ping response received callback.
  /// If set when a ping response is received from the broker
  /// this will be called.
  /// Can be used for health monitoring outside of the client itself.
  PongCallback _pongCallback;

  /// The ping received callback
  PongCallback get pongCallback => _pongCallback;

  set pongCallback(PongCallback cb) {
    _pongCallback = cb;
    keepAlive?.pongCallback = cb;
  }

  /// The event bus
  @protected
  events.EventBus clientEventBus;

  /// The stream on which all subscribed topic updates are published to
  Stream<List<MqttReceivedMessage<MqttMessage>>> updates;

  ///  Gets a pre-configured connect message if one has not been
  ///  supplied by the user.
  ///  Returns an MqttConnectMessage that can be used to connect to a
  ///  message broker.
  @protected
  MqttConnectMessage getConnectMessage(String username, String password) =>
      connectionMessage ??= MqttConnectMessage()
          .withClientIdentifier(clientIdentifier)
          // Explicitly set the will flag
          .withWillQos(MqttQos.atMostOnce)
          .keepAliveFor(Constants.defaultKeepAlive)
          .authenticateAs(username, password)
          .startClean();

  /// Initiates a topic subscription request to the connected broker
  /// with a strongly typed data processor callback.
  /// The topic to subscribe to.
  /// The qos level the message was published at.
  /// Returns the subscription or null on failure
  Subscription subscribe(String topic, MqttQos qosLevel) {
    if (connectionStatus.state != MqttConnectionState.connected) {
      throw ConnectionException(connectionHandler?.connectionStatus?.state);
    }
    return subscriptionsManager.registerSubscription(topic, qosLevel);
  }

  /// Publishes a message to the message broker.
  /// Returns The message identifer assigned to the message.
  /// Raises InvalidTopicException if the topic supplied violates the
  /// MQTT topic format rules.
  int publishMessage(
      String topic, MqttQos qualityOfService, typed.Uint8Buffer data,
      {bool retain = false}) {
    if (connectionHandler?.connectionStatus?.state !=
        MqttConnectionState.connected) {
      throw ConnectionException(connectionHandler?.connectionStatus?.state);
    }
    try {
      final pubTopic = PublicationTopic(topic);
      return publishingManager.publish(
          pubTopic, qualityOfService, data, retain);
    } on Exception catch (e) {
      throw InvalidTopicException(e.toString(), topic);
    }
  }

  /// Unsubscribe from a topic
  void unsubscribe(String topic) {
    subscriptionsManager.unsubscribe(topic);
  }

  /// Gets the current status of a subscription.
  MqttSubscriptionStatus getSubscriptionsStatus(String topic) =>
      subscriptionsManager.getSubscriptionsStatus(topic);

  /// Disconnect from the broker.
  /// This is a hard disconnect, a disconnect message is sent to the
  /// broker and the client is then reset to its pre-connection state,
  /// i.e all subscriptions are deleted, on subsequent reconnection the
  /// use must re-subscribe, also the updates change notifier is re-initialised
  /// and as such the user must re-listen on this stream.
  ///
  /// Do NOT call this in any onDisconnect callback that may be set,
  /// this will result in a loop situation.
  void disconnect() {
    _disconnect(unsolicited: false);
  }

  /// Internal disconnect
  /// This is always passed to the connection handler to allow the
  /// client to close itself down correctly on disconnect.
  @protected
  void internalDisconnect() {
    // Only call disconnect if we are connected, i.e. a connection to
    // the broker has been previously established.
    if (connectionStatus.state == MqttConnectionState.connected) {
      _disconnect(unsolicited: true);
    }
  }

  /// Actual disconnect processing
  void _disconnect({bool unsolicited = true}) {
    // Only disconnect the connection handler if the request is
    // solicited, unsolicited requests, ie broker termination don't
    // need this.
    var returnCode = MqttConnectReturnCode.unsolicited;
    if (!unsolicited) {
      connectionHandler?.disconnect();
      returnCode = MqttConnectReturnCode.solicited;
    }
    publishingManager?.published?.close();
    publishingManager = null;
    subscriptionsManager = null;
    keepAlive?.stop();
    keepAlive = null;
    connectionHandler = null;
    clientEventBus?.destroy();
    clientEventBus = null;
    // Set the connection status before calling onDisconnected
    _connectionStatus.state = MqttConnectionState.disconnected;
    _connectionStatus.returnCode = returnCode;
    if (onDisconnected != null) {
      onDisconnected();
    }
  }

  /// Check the username and password validity
  @protected
  void checkCredentials(String username, String password) {
    if (username != null) {
      MqttLogger.log("Authenticating with username '{$username}' "
          "and password '{$password}'");
      if (username.trim().length >
          Constants.recommendedMaxUsernamePasswordLength) {
        MqttLogger.log('Username length (${username.trim().length}) '
            'exceeds the max recommended in the MQTT spec. ');
      }
    }
    if (password != null &&
        password.trim().length >
            Constants.recommendedMaxUsernamePasswordLength) {
      MqttLogger.log('Password length (${password.trim().length}) '
          'exceeds the max recommended in the MQTT spec. ');
    }
  }

  /// Turn on logging, true to start, false to stop
  void logging({bool on}) {
    MqttLogger.loggingOn = false;
    if (on) {
      MqttLogger.loggingOn = true;
    }
  }

  /// Set the protocol version to V3.1 - default
  void setProtocolV31() {
    Protocol.version = Constants.mqttV31ProtocolVersion;
    Protocol.name = Constants.mqttV31ProtocolName;
  }

  /// Set the protocol version to V3.1.1
  void setProtocolV311() {
    Protocol.version = Constants.mqttV311ProtocolVersion;
    Protocol.name = Constants.mqttV311ProtocolName;
  }
}
