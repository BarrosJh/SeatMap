import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'api_client_base.dart';

class TiApi extends ApiClientBase {
  Future<ApiResponse<Map<String, dynamic>>> getConfiguracoesTi(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/ti/configuracoes'),
        headers: headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao carregar configurações de TI.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> updateConfiguracoesTi(String token, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/admin/ti/configuracoes'),
        headers: headers(token),
        body: jsonEncode(data),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, message: body['message'] ?? 'Configurações atualizadas.', statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao salvar configurações de TI.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> testarConexaoEmail(
    String token, {
    String? emailDestino,
    String? nomeDestino,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/ti/testar-email'),
        headers: headers(token),
        body: jsonEncode({
          if (emailDestino != null && emailDestino.isNotEmpty) 'emailDestino': emailDestino,
          if (nomeDestino != null && nomeDestino.isNotEmpty) 'nomeDestino': nomeDestino,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: body,
          message: body['message'] ?? 'E-mail de teste despachado com sucesso!',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          data: body,
          error: body['error'] ?? body['message'] ?? 'Falha ao testar conexão SMTP.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getStatusSistema(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/ti/status'),
        headers: headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao obter diagnóstico de saúde do sistema.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<List<dynamic>>> getAuditoriaMfa(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/ti/auditoria-mfa'),
        headers: headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List list = body['auditoria'] ?? [];
        return ApiResponse(success: true, data: list, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao buscar auditoria de MFA.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getAuditoriaAcessos(
    String token, {
    int pagina = 1,
    int limite = 25,
    String? tipoEvento,
    String? termo,
    bool? sucesso,
  }) async {
    try {
      final queryParams = {
        'pagina': pagina.toString(),
        'limite': limite.toString(),
        if (tipoEvento != null && tipoEvento.isNotEmpty) 'tipoEvento': tipoEvento,
        if (termo != null && termo.isNotEmpty) 'termo': termo,
        if (sucesso != null) 'sucesso': sucesso.toString(),
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/ti/auditoria-acessos').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers(token));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao buscar trilha de auditoria de acessos.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }
}
