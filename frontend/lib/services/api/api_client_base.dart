import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../secure_storage_service.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    required this.statusCode,
  });
}

class ApiClientBase {
  static http.Client? customClient;

  // Callbacks para sincronização de estado com o AuthProvider
  static void Function(String newToken, String? newRefreshToken)? onTokenRefreshed;
  static void Function(String reason)? onSessionExpired;

  // Mutex para evitar múltiplos refresh simultâneos (Single-Flight Pattern)
  static Completer<bool>? _refreshCompleter;

  static String generateCorrelationId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Map<String, String> headers(String? token, {String? adminToken, String? correlationId}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-correlation-id': correlationId ?? generateCorrelationId(),
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    if (adminToken != null && adminToken.isNotEmpty) {
      map['x-admin-token'] = adminToken;
    }
    return map;
  }

  static String sanitizeError(dynamic e) {
    if (e is TimeoutException) {
      return 'Tempo limite de conexão excedido. O servidor demorou para responder.';
    }
    final errorStr = e.toString();
    if (e is SocketException ||
        errorStr.contains('SocketException') ||
        errorStr.contains('Failed host lookup') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('ClientException')) {
      return 'Não foi possível conectar ao servidor. Verifique sua conexão com a internet.';
    }
    if (e is FormatException) {
      return 'Resposta em formato inesperado recebida do servidor.';
    }
    return 'Erro de conexão: $e';
  }

  /// Executa renovação de token garantindo single-flight / mutex
  static Future<bool> _refreshAuthToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final storage = SecureStorageService();
      final currentRefreshToken = await storage.getRefreshToken();

      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        debugPrint('[ApiClientBase] Nenhum refresh token disponível no storage.');
        _refreshCompleter!.complete(false);
        onSessionExpired?.call('Sessão expirada. Faça login novamente.');
        return false;
      }

      final client = customClient ?? http.Client();
      final uri = Uri.parse('${AppConstants.baseUrl}/auth/refresh-token');
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-correlation-id': generateCorrelationId(),
        },
        body: jsonEncode({'refreshToken': currentRefreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final String newToken = body['token'];
        final String? newRefreshToken = body['refreshToken'];

        await storage.saveToken(newToken);
        if (newRefreshToken != null) {
          await storage.saveRefreshToken(newRefreshToken);
        }

        onTokenRefreshed?.call(newToken, newRefreshToken);
        debugPrint('[ApiClientBase] Token renovado com sucesso via auto-refresh interceptor.');
        _refreshCompleter!.complete(true);
        return true;
      } else {
        debugPrint('[ApiClientBase] Falha ao renovar token (HTTP ${response.statusCode}).');
        await storage.clearAll();
        _refreshCompleter!.complete(false);
        onSessionExpired?.call('Sua sessão expirou. Faça login novamente.');
        return false;
      }
    } catch (e) {
      debugPrint('[ApiClientBase] Exceção durante auto-refresh: $e');
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      onSessionExpired?.call('Erro ao restabelecer sessão.');
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Executor Central Resiliente de Requisições HTTP com Interceptor 401 & Auto-Retry
  Future<ApiResponse<T>> request<T>({
    required String method,
    required String path,
    Map<String, String>? queryParams,
    dynamic body,
    String? token,
    String? adminToken,
    T Function(dynamic json)? parser,
    bool autoRefresh = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final client = customClient ?? http.Client();
    String? currentToken = token;

    Future<http.Response> executeCall(String? authToken) {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      var uri = Uri.parse('${AppConstants.baseUrl}$cleanPath');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final reqHeaders = headers(authToken, adminToken: adminToken);
      final encodedBody = body != null ? (body is String ? body : jsonEncode(body)) : null;

      switch (method.toUpperCase()) {
        case 'GET':
          return client.get(uri, headers: reqHeaders).timeout(timeout);
        case 'POST':
          return client.post(uri, headers: reqHeaders, body: encodedBody).timeout(timeout);
        case 'PUT':
          return client.put(uri, headers: reqHeaders, body: encodedBody).timeout(timeout);
        case 'PATCH':
          return client.patch(uri, headers: reqHeaders, body: encodedBody).timeout(timeout);
        case 'DELETE':
          return client.delete(uri, headers: reqHeaders, body: encodedBody).timeout(timeout);
        default:
          throw UnsupportedError('Método HTTP não suportado: $method');
      }
    }

    try {
      var response = await executeCall(currentToken);

      // 1. Interceptor de 401 Unauthorized (Auto-Refresh + Retry)
      final isAuthEndpoint = path.contains('/auth/login') || path.contains('/auth/refresh-token');
      if (response.statusCode == 401 && autoRefresh && !isAuthEndpoint) {
        debugPrint('[ApiClientBase] HTTP 401 detectado em $path. Disparando Auto-Refresh...');
        final refreshed = await _refreshAuthToken();
        if (refreshed) {
          final storage = SecureStorageService();
          currentToken = await storage.getToken();
          debugPrint('[ApiClientBase] Repetindo requisição original em $path com novo token...');
          response = await executeCall(currentToken);
        }
      }

      // 2. Processamento da Resposta
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.bodyBytes.isEmpty) {
          return ApiResponse(success: true, statusCode: response.statusCode);
        }

        try {
          final decodedString = utf8.decode(response.bodyBytes);
          final dynamic decoded = jsonDecode(decodedString);
          T? parsedData;
          if (parser != null) {
            parsedData = parser(decoded);
          } else if (decoded is T) {
            parsedData = decoded;
          }

          final String? msg = (decoded is Map && decoded.containsKey('message')) ? decoded['message']?.toString() : null;
          return ApiResponse(
            success: true,
            data: parsedData,
            message: msg,
            statusCode: response.statusCode,
          );
        } catch (_) {
          final decodedString = utf8.decode(response.bodyBytes, allowMalformed: true);
          return ApiResponse(
            success: true,
            data: (decodedString is T) ? (decodedString as T) : null,
            statusCode: response.statusCode,
          );
        }
      } else {
        String errorMsg = 'Erro na requisição (HTTP ${response.statusCode})';
        try {
          final decodedString = utf8.decode(response.bodyBytes);
          final dynamic decoded = jsonDecode(decodedString);
          if (decoded is Map) {
            errorMsg = decoded['error'] ?? decoded['message'] ?? errorMsg;
          }
        } catch (_) {
          if (response.bodyBytes.isNotEmpty && response.bodyBytes.length < 200) {
            errorMsg = utf8.decode(response.bodyBytes, allowMalformed: true);
          }
        }
        return ApiResponse(
          success: false,
          error: errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: sanitizeError(e),
        statusCode: 0,
      );
    }
  }

  /// Executor especializado para downloads de arquivos binários (Excel, PDF) com Interceptor
  Future<ApiResponse<Uint8List>> requestBytes({
    required String path,
    Map<String, String>? queryParams,
    String? token,
    String? adminToken,
    bool autoRefresh = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final client = customClient ?? http.Client();
    String? currentToken = token;

    Future<http.Response> executeCall(String? authToken) {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      var uri = Uri.parse('${AppConstants.baseUrl}$cleanPath');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final reqHeaders = headers(authToken, adminToken: adminToken);
      return client.get(uri, headers: reqHeaders).timeout(timeout);
    }

    try {
      var response = await executeCall(currentToken);

      if (response.statusCode == 401 && autoRefresh) {
        final refreshed = await _refreshAuthToken();
        if (refreshed) {
          final storage = SecureStorageService();
          currentToken = await storage.getToken();
          response = await executeCall(currentToken);
        }
      }

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: response.bodyBytes,
          statusCode: 200,
        );
      } else {
        String errorMsg = 'Falha ao baixar arquivo (HTTP ${response.statusCode})';
        try {
          final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            errorMsg = decoded['error'] ?? decoded['message'] ?? errorMsg;
          }
        } catch (_) {}
        return ApiResponse(
          success: false,
          error: errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        error: sanitizeError(e),
        statusCode: 0,
      );
    }
  }
}

