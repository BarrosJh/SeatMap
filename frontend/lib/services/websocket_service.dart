import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<Map<String, dynamic>> _seatUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get seatUpdates => _seatUpdateController.stream;

  int? _currentEscritorioId;
  String? _token;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _explicitlyDisconnected = false;

  void connect({required String token, int? escritorioId}) {
    _token = token;
    _currentEscritorioId = escritorioId;
    _explicitlyDisconnected = false;

    _disconnectInternal();

    try {
      final uri = Uri.parse(
        '${AppConstants.wsUrl}${escritorioId != null ? '?escritorioId=$escritorioId' : ''}',
      );

      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['Bearer', token],
      );
      _isConnected = true;
      _reconnectAttempts = 0;

      // Iniciar timer de Heartbeat (Ping a cada 25 segundos para manter a conexão ativa no Render)
      _startPingTimer();

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString());
            if (json is Map<String, dynamic>) {
              if (json['action'] == 'pong' || json['type'] == 'pong') {
                return; // Heartbeat pong ignorado
              }
              _seatUpdateController.add(json);
            }
          } catch (e) {
            debugPrint('[WS Client] Erro ao decodificar mensagem: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS Client] Erro na conexão: $error');
          _handleConnectionLoss();
        },
        onDone: () {
          debugPrint('[WS Client] Conexão encerrada pelo servidor');
          _handleConnectionLoss();
        },
      );

      debugPrint('[WS Client] Conectado com sucesso à sala $escritorioId');
    } catch (e) {
      debugPrint('[WS Client] Falha ao conectar: $e');
      _handleConnectionLoss();
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_isConnected && _channel != null) {
        _send({'action': 'ping'});
      }
    });
  }

  void _handleConnectionLoss() {
    _isConnected = false;
    _pingTimer?.cancel();
    _pingTimer = null;

    if (_explicitlyDisconnected || _token == null) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts <= 3) ? (_reconnectAttempts * 2) : 10;

    debugPrint('[WS Client] Tentando reconectar em ${delaySeconds}s (tentativa $_reconnectAttempts)...');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_explicitlyDisconnected && _token != null) {
        connect(token: _token!, escritorioId: _currentEscritorioId);
      }
    });
  }

  void switchEscritorio(int novoEscritorioId) {
    if (_channel != null && _isConnected) {
      if (_currentEscritorioId != null) {
        _send({'action': 'unsubscribe', 'escritorioId': _currentEscritorioId});
      }
      _currentEscritorioId = novoEscritorioId;
      _send({'action': 'subscribe', 'escritorioId': novoEscritorioId});
    } else if (_token != null) {
      connect(token: _token!, escritorioId: novoEscritorioId);
    }
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('[WS Client] Erro ao enviar mensagem: $e');
    }
  }

  void _disconnectInternal() {
    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
  }

  void disconnect() {
    _explicitlyDisconnected = true;
    _disconnectInternal();
    _currentEscritorioId = null;
    _token = null;
    _reconnectAttempts = 0;
  }
}
