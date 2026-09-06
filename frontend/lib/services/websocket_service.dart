import 'dart:async';
import 'dart:convert';
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

  void connect({required String token, int? escritorioId}) {
    _token = token;
    _currentEscritorioId = escritorioId;

    _disconnectInternal();

    try {
      final uri = Uri.parse(
        '${AppConstants.wsUrl}?token=$token${escritorioId != null ? '&escritorioId=$escritorioId' : ''}',
      );

      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString());
            _seatUpdateController.add(json);
          } catch (e) {
            print('[WS Client] Erro ao decodificar mensagem: $e');
          }
        },
        onError: (error) {
          print('[WS Client] Erro na conexão: $error');
          _isConnected = false;
        },
        onDone: () {
          print('[WS Client] Conexão encerrada pelo servidor');
          _isConnected = false;
        },
      );

      print('[WS Client] Conectado com sucesso à sala $escritorioId');
    } catch (e) {
      print('[WS Client] Falha ao conectar: $e');
      _isConnected = false;
    }
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
      print('[WS Client] Erro ao enviar mensagem: $e');
    }
  }

  void _disconnectInternal() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void disconnect() {
    _disconnectInternal();
    _currentEscritorioId = null;
    _token = null;
  }
}

