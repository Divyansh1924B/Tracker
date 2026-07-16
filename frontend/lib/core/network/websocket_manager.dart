import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dio_client.dart';

enum WsConnectionState { disconnected, connecting, connected }

class WebSocketManager {
  final String _wsBaseUrl;
  WebSocketChannel? _channel;
  WsConnectionState _connectionState = WsConnectionState.disconnected;
  
  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WsConnectionState> _stateStreamController =
      StreamController<WsConnectionState>.broadcast();

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectDelaySeconds = 2;
  bool _shouldReconnect = true;

  WebSocketManager(this._wsBaseUrl);

  Stream<Map<String, dynamic>> get messages => _messageStreamController.stream;
  Stream<WsConnectionState> get connectionStateStream => _stateStreamController.stream;
  WsConnectionState get connectionState => _connectionState;

  void connect() {
    final token = DioClient.token;
    if (token == null) {
      _updateState(WsConnectionState.disconnected);
      return;
    }

    if (_connectionState == WsConnectionState.connected ||
        _connectionState == WsConnectionState.connecting) {
      return;
    }

    _shouldReconnect = true;
    _updateState(WsConnectionState.connecting);

    final wsUri = Uri.parse('$_wsBaseUrl?token=$token');
    
    try {
      _channel = WebSocketChannel.connect(wsUri);
      
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) => send('ping', {}));

      _channel!.stream.listen(
        (message) {
          _updateState(WsConnectionState.connected);
          _reconnectDelaySeconds = 2;
          try {
            final json = jsonDecode(message.toString()) as Map<String, dynamic>;
            _messageStreamController.add(json);
          } catch (_) {}
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateState(WsConnectionState.disconnected);
  }

  void send(String type, Map<String, dynamic> payload) {
    if (_connectionState != WsConnectionState.connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({
        'type': type,
        'payload': payload,
      }));
    } catch (_) {}
  }

  void _updateState(WsConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    _stateStreamController.add(state);
  }

  void _handleDisconnect() {
    _pingTimer?.cancel();
    _updateState(WsConnectionState.disconnected);
    _channel = null;

    if (_shouldReconnect) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () {
        if (_reconnectDelaySeconds < 60) {
          _reconnectDelaySeconds *= 2;
        }
        connect();
      });
    }
  }
}
