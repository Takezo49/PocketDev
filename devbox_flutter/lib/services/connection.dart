import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

enum ConnectionStatus { disconnected, connecting, connected, paired }

class DevBoxConnection extends ChangeNotifier {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _hostname = '';
  String _host = '';
  int _port = 0;
  String _secret = '';
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  ConnectionStatus get status => _status;
  String get hostname => _hostname;
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Force status for preview/testing
  void mockStatus(ConnectionStatus s) {
    _status = s;
    _hostname = 'Preview';
    notifyListeners();
  }

  void connect(String host, int port, String secret) {
    _host = host;
    _port = port;
    _secret = secret;
    _doConnect();
  }

  Future<bool> autoConnect() async {
    try {
      final resp = await http.get(Uri.parse('http://localhost:7778/api/info'))
          .timeout(const Duration(seconds: 3));
      final info = jsonDecode(resp.body);
      connect('localhost', info['port'], info['secret']);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _doConnect() {
    disconnect(reconnect: false);
    _setStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://$_host:$_port');
      _channel = WebSocketChannel.connect(uri);

      _channel!.ready.then((_) {
        _setStatus(ConnectionStatus.connected);
        send({'type': 'pair:verify', 'token': _secret});
      }).catchError((_) {
        _setStatus(ConnectionStatus.disconnected);
        _scheduleReconnect();
      });

      _channelSub = _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            if (msg['type'] == 'paired' && msg['success'] == true) {
              _setStatus(ConnectionStatus.paired);
            }
            if (msg['type'] == 'status') {
              _hostname = msg['hostname'] ?? '';
              notifyListeners();
            }
            _messageController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _setStatus(ConnectionStatus.disconnected);
          _scheduleReconnect();
        },
        onError: (_) {
          _setStatus(ConnectionStatus.disconnected);
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _setStatus(ConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void send(Map<String, dynamic> msg) {
    _channel?.sink.add(jsonEncode(msg));
  }

  void disconnect({bool reconnect = false}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    if (!reconnect) {
      _setStatus(ConnectionStatus.disconnected);
    }
  }

  void _setStatus(ConnectionStatus s) {
    if (_status != s) {
      _status = s;
      notifyListeners();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    super.dispose();
  }
}
