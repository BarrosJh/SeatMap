import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppConstants {
  // Global Navigator Key para controle centralizado de rotas e logout seguro
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // URLs configuráveis dinamicamente via --dart-define ou detecção de host na Web
  static const String _definedBaseUrl = String.fromEnvironment('API_URL');
  static const String _definedWsUrl = String.fromEnvironment('WS_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('file:') && !origin.contains('localhost')) {
        return '$origin/api';
      }
    }
    return 'http://localhost:3000/api';
  }

  static String get wsUrl {
    if (_definedWsUrl.isNotEmpty) return _definedWsUrl;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.startsWith('file:') && !origin.contains('localhost')) {
        final wsProtocol = origin.startsWith('https:') ? 'wss:' : 'ws:';
        final host = Uri.base.host;
        final port = Uri.base.hasPort ? ':${Uri.base.port}' : '';
        return '$wsProtocol//$host$port/ws';
      }
    }
    return 'ws://localhost:3000/ws';
  }

  // Chaves de SharedPreferences & SecureStorage
  static const String keyToken = 'seatmap_jwt_token';
  static const String keyRefreshToken = 'seatmap_refresh_token';
  static const String keyAdminToken = 'seatmap_admin_token';
  static const String keyUserData = 'seatmap_user_data';

  // Cores de Assentos e Estados
  static const Color seatLivre = Color(0xFF43A047);       // Verde
  static const Color seatOcupada = Color(0xFFE53935);     // Vermelho
  static const Color seatMinhaReserva = Color(0xFF1E88E5);// Azul
  static const Color seatExpirada = Color(0xFF9E9E9E);    // Cinza
  static const Color seatSameDeptBorder = Color(0xFFFFB300); // Amarelo/Dourado destaque mesmo departamento

  // Cores de Tema
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color secondaryColor = Color(0xFF26A69A);
  static const Color backgroundColor = Color(0xFFF4F6F9);
  static const Color surfaceColor = Colors.white;
}
