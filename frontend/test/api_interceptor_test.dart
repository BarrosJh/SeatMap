import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:seatmap_frontend/services/api/api_client_base.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'seatmap_jwt_token': 'old-jwt-token',
      'seatmap_refresh_token': 'valid-refresh-token',
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seatmap_jwt_token', 'old-jwt-token');
    await prefs.setString('seatmap_refresh_token', 'valid-refresh-token');
    ApiClientBase.customClient = null;
    ApiClientBase.onTokenRefreshed = null;
    ApiClientBase.onSessionExpired = null;
  });

  group('1. Sanitização de Erros de Conexão', () {
    test('deve sanitizar TimeoutException', () {
      final err = TimeoutException('Timeout');
      expect(ApiClientBase.sanitizeError(err), contains('Tempo limite de conexão'));
    });

    test('deve sanitizar SocketException', () {
      const err = SocketException('Failed host lookup');
      expect(ApiClientBase.sanitizeError(err), contains('Não foi possível conectar ao servidor'));
    });

    test('deve sanitizar FormatException', () {
      const err = FormatException('Bad format');
      expect(ApiClientBase.sanitizeError(err), contains('Resposta em formato inesperado'));
    });
  });

  group('2. HTTP Client Interceptor - Sucesso e 400', () {
    test('deve processar requisição GET 200 com parser tipado', () async {
      ApiClientBase.customClient = MockHttpClient((req) async {
        expect(req.url.path, contains('/escritorios'));
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode([{'id': 1, 'nome': 'Matriz'}]))),
          200,
        );
      });

      final client = ApiClientBase();
      final res = await client.request<List<dynamic>>(
        method: 'GET',
        path: '/escritorios',
        token: 'test-token',
      );

      expect(res.success, true);
      expect(res.statusCode, 200);
      expect(res.data, isList);
      expect(res.data!.first['nome'], 'Matriz');
    });

    test('deve processar erro 400 com mensagem amigável', () async {
      ApiClientBase.customClient = MockHttpClient((req) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'error': 'Assento já reservado'}))),
          400,
        );
      });

      final client = ApiClientBase();
      final res = await client.request(
        method: 'POST',
        path: '/reservas',
        token: 'test-token',
      );

      expect(res.success, false);
      expect(res.statusCode, 400);
      expect(res.error, 'Assento já reservado');
    });
  });

  group('3. HTTP Client Interceptor - 401 Auto-Refresh & Retry', () {
    test('deve interceptar 401, renovar token e repetir requisição original com sucesso', () async {
      int callCount = 0;
      bool refreshCalled = false;
      String? updatedToken;

      ApiClientBase.onTokenRefreshed = (newToken, newRefresh) {
        updatedToken = newToken;
      };

      ApiClientBase.customClient = MockHttpClient((req) async {
        if (req.url.path.contains('/auth/refresh-token')) {
          refreshCalled = true;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'token': 'brand-new-jwt-token',
              'refreshToken': 'brand-new-refresh-token',
            }))),
            200,
          );
        }

        callCount++;
        if (callCount == 1) {
          // Primeira tentativa falha com 401
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': 'Token expirado'}))),
            401,
          );
        } else {
          // Segunda tentativa (retry) com o novo token
          expect(req.headers['Authorization'], 'Bearer brand-new-jwt-token');
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'message': 'Sucesso após retry'}))),
            200,
          );
        }
      });

      final client = ApiClientBase();
      final res = await client.request(
        method: 'GET',
        path: '/reservas/minhas',
        token: 'expired-token',
      );

      expect(res.success, true);
      expect(res.statusCode, 200);
      expect(res.message, 'Sucesso após retry');
      expect(refreshCalled, true);
      expect(callCount, 2);
      expect(updatedToken, 'brand-new-jwt-token');
    });

    test('deve disparar onSessionExpired quando o refresh token falhar (401)', () async {
      bool sessionExpiredFired = false;

      ApiClientBase.onSessionExpired = (reason) {
        sessionExpiredFired = true;
      };

      ApiClientBase.customClient = MockHttpClient((req) async {
        if (req.url.path.contains('/auth/refresh-token')) {
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({'error': 'Refresh token inválido'}))),
            401,
          );
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'error': 'Token expirado'}))),
          401,
        );
      });

      final client = ApiClientBase();
      final res = await client.request(
        method: 'GET',
        path: '/admin/usuarios',
        token: 'expired-token',
      );

      expect(res.success, false);
      expect(res.statusCode, 401);
      expect(sessionExpiredFired, true);
    });
  });
}
