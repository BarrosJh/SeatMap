import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../models/user_model.dart';
import 'api_client_base.dart';

class AuthApi extends ApiClientBase {
  Future<ApiResponse<Map<String, dynamic>>> getConfigSeguranca() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/config-seguranca'),
        headers: headers(null),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, statusCode: 200);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Falha ao buscar configurações de segurança', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro ao obter configurações: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> login(String login, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: headers(null),
        body: jsonEncode({'login': login, 'senha': senha}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (body['requiresMfa'] == true) {
          return ApiResponse(
            success: true,
            data: {
              'requiresMfa': true,
              'mfaType': body['mfaType'] ?? 'TOTP',
              'tempToken': body['tempToken'],
              'emailMascarado': body['emailMascarado'],
              'expiraEmMinutos': body['expiraEmMinutos'],
              'message': body['message'] ?? 'Insira o código de verificação.',
            },
            statusCode: response.statusCode,
          );
        }

        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
            'refreshToken': body['refreshToken'],
            'user': UserModel.fromJson(body['user']),
          },
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Falha ao realizar login.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão com o servidor: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> validarLoginTotp(String tempToken, String codigo) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/totp/validar-login'),
        headers: headers(null),
        body: jsonEncode({'tempToken': tempToken, 'codigo': codigo}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
            'refreshToken': body['refreshToken'],
            'user': UserModel.fromJson(body['user']),
          },
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Código de autenticação inválido.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão com o servidor: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> validarLoginEmailMfa(String tempToken, String codigo) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/mfa/validar-login-email'),
        headers: headers(null),
        body: jsonEncode({'tempToken': tempToken, 'codigo': codigo}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
            'refreshToken': body['refreshToken'],
            'user': UserModel.fromJson(body['user']),
          },
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Código de verificação incorreto ou expirado.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão com o servidor: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/refresh-token'),
        headers: headers(null),
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
            'refreshToken': body['refreshToken'],
            'user': UserModel.fromJson(body['user']),
          },
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Sessão expirada. Faça login novamente.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão ao renovar sessão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<void>> logout(String? token, {String? refreshToken}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/logout'),
        headers: headers(token),
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      return ApiResponse(
        success: response.statusCode == 200,
        message: 'Sessão encerrada com sucesso.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getSsoConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/sso/config'),
        headers: headers(null),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao carregar SSO.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> solicitarMfa(String token) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/mfa/solicitar'),
        headers: headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body['message'] ?? 'Check-in confirmado', message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao solicitar MFA.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> validarMfa(String token, String codigo) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/mfa/validar'),
        headers: headers(token),
        body: jsonEncode({'codigo': codigo}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body['adminToken'], message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Código MFA inválido.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> solicitarRecuperacaoSenha(String login) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/esqueci-senha'),
        headers: headers(null),
        body: jsonEncode({'login': login}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: body,
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Erro ao solicitar recuperação de senha.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> redefinirSenha(String login, String codigo, String novaSenha) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/redefinir-senha'),
        headers: headers(null),
        body: jsonEncode({
          'login': login,
          'codigo': codigo,
          'novaSenha': novaSenha,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: body['message'] ?? 'Senha redefinida com sucesso.',
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Erro ao redefinir senha.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> loginSso({
    required String provider,
    required String email,
    String? name,
    String? ssoId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/sso/login'),
        headers: headers(null),
        body: jsonEncode({
          'provider': provider,
          'email': email,
          if (name != null) 'name': name,
          if (ssoId != null) 'ssoId': ssoId,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
            'refreshToken': body['refreshToken'],
            'user': UserModel.fromJson(body['user']),
          },
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Falha na autenticação SSO.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }
}
