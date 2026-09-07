import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/user_model.dart';
import '../models/seat_model.dart';
import '../models/admin_models.dart';

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

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Map<String, String> _headers(String? token, {String? adminToken}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    if (adminToken != null && adminToken.isNotEmpty) {
      map['x-admin-token'] = adminToken;
    }
    return map;
  }

  // ==========================================
  // AUTH (ENTERPRISE)
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> login(String login, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: _headers(null),
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
              'message': body['message'] ?? 'Insira o código do autenticador.',
            },
            statusCode: response.statusCode,
          );
        }

        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
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
        headers: _headers(null),
        body: jsonEncode({'tempToken': tempToken, 'codigo': codigo}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: {
            'token': body['token'],
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

  Future<ApiResponse<Map<String, dynamic>>> getSsoConfig() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/auth/sso/config'),
        headers: _headers(null),
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
        headers: _headers(token),
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
        headers: _headers(token),
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
        headers: _headers(null),
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
        headers: _headers(null),
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

  // ==========================================
  // ESCRITÓRIOS & ASSENTOS
  // ==========================================
  Future<ApiResponse<List<EscritorioModel>>> getEscritorios(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/escritorios'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        final data = list.map((e) => EscritorioModel.fromJson(e)).toList();
        return ApiResponse(success: true, data: data, statusCode: response.statusCode);
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao buscar escritórios.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<List<OcupacaoEscritorioModel>>> getOcupacaoSemanal(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/escritorios/ocupacao/semanal'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        final data = list.map((e) => OcupacaoEscritorioModel.fromJson(e)).toList();
        return ApiResponse(success: true, data: data, statusCode: response.statusCode);
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao buscar ocupação semanal.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> getAvisoGlobal(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/escritorios/aviso'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return ApiResponse(success: true, data: body['aviso']?.toString() ?? '', statusCode: response.statusCode);
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao buscar aviso global.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<MapaDataModel>> getMapa(String token, int escritorioId, String dataIso) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/escritorios/$escritorioId/mapa?data=$dataIso'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = MapaDataModel.fromJson(body);
        return ApiResponse(success: true, data: data, statusCode: response.statusCode);
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao carregar mapa de assentos.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  // ==========================================
  // RESERVAS
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> criarReserva(String token, int cadeiraId, String dataIso) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas'),
        headers: _headers(token),
        body: jsonEncode({'cadeiraId': cadeiraId, 'dataReserva': dataIso}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResponse(success: true, data: body, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao reservar assento.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> fazerCheckin(String token, int reservaId, {int? cadeiraId}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas/$reservaId/checkin'),
        headers: _headers(token),
        body: jsonEncode({'cadeiraId': cadeiraId}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao realizar check-in.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> cancelarReserva(String token, int reservaId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}/reservas/$reservaId'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = body['data'] != null ? Map<String, dynamic>.from(body['data']) : null;
        return ApiResponse(
          success: true,
          data: data,
          message: body['message'] ?? 'Reserva cancelada.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao cancelar reserva.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> enviarComprovanteEmail(String token, int reservaId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas/$reservaId/enviar-comprovante-email'),
        headers: _headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: body['email']?.toString() ?? '',
          message: body['message'] ?? 'Comprovante enviado por e-mail com sucesso.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Erro ao enviar comprovante por e-mail.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<List<ReservaModel>>> getMinhasReservas(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reservas/minhas'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        final data = list.map((e) => ReservaModel.fromJson(e)).toList();
        return ApiResponse(success: true, data: data, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Erro ao buscar histórico de reservas.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  // ==========================================
  // ADMIN: PARÂMETROS & OPERACIONAL
  // ==========================================
  Future<ApiResponse<List<dynamic>>> getParametros(String token, String adminToken) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/parametros'),
        headers: _headers(token, adminToken: adminToken),
      );

      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: jsonDecode(response.body), statusCode: response.statusCode);
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao buscar parâmetros.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> updateParametros(String token, String adminToken, dynamic configuracoes) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/admin/parametros'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode({'configuracoes': configuracoes}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao atualizar parâmetros.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> executarLimpezaNoShow(String token, String adminToken, {String? dataIso}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/limpeza-noshow'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode({'data': dataIso}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro na limpeza de no-show.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  // ==========================================
  // ADMIN: GESTÃO DE USUÁRIOS
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> getUsuariosAdmin(
    String token,
    String adminToken, {
    String? busca,
    String? departamentoId,
    String? perfil,
    String? ativo,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (busca != null && busca.trim().isNotEmpty) queryParams['busca'] = busca.trim();
      if (departamentoId != null && departamentoId != 'todos') queryParams['departamentoId'] = departamentoId;
      if (perfil != null && perfil != 'todos') queryParams['perfil'] = perfil;
      if (ativo != null && ativo != 'todos') queryParams['ativo'] = ativo;

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/usuarios').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List list = body['usuarios'] ?? [];
        final usuarios = list.map((u) => AdminUsuarioModel.fromJson(u)).toList();
        return ApiResponse(
          success: true,
          data: {
            'total': body['total'] ?? 0,
            'usuarios': usuarios,
          },
          statusCode: response.statusCode,
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao listar usuários.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<AdminUsuarioModel>> criarUsuarioAdmin(
    String token,
    String adminToken,
    Map<String, dynamic> usuarioData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/usuarios'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode(usuarioData),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: AdminUsuarioModel.fromJson(body['usuario']),
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao cadastrar usuário.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<AdminUsuarioModel>> updateUsuarioAdmin(
    String token,
    String adminToken,
    int id,
    Map<String, dynamic> usuarioData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/admin/usuarios/$id'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode(usuarioData),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: AdminUsuarioModel.fromJson(body['usuario']),
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao atualizar usuário.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<AdminUsuarioModel>> toggleStatusUsuarioAdmin(
    String token,
    String adminToken,
    int id, {
    bool? ativo,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/admin/usuarios/$id'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode(ativo != null ? {'ativo': ativo} : {}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: AdminUsuarioModel.fromJson(body['usuario']),
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao alterar status do usuário.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> resetSenhaUsuarioAdmin(
    String token,
    String adminToken,
    int id,
    String novaSenha,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/usuarios/$id/reset-senha'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode({'novaSenha': novaSenha}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao redefinir senha.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> importarLoteUsuariosAdmin(
    String token,
    String adminToken,
    List<Map<String, dynamic>> usuarios, {
    String defaultSenha = 'Mudar@123',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/usuarios/importar-lote'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode({'usuarios': usuarios, 'defaultSenha': defaultSenha}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao importar usuários em lote.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  // ==========================================
  // ADMIN: DEPARTAMENTOS
  // ==========================================
  Future<ApiResponse<List<DepartamentoModel>>> getDepartamentosAdmin(String token, String adminToken) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/departamentos'),
        headers: _headers(token, adminToken: adminToken),
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        final deps = list.map((d) => DepartamentoModel.fromJson(d)).toList();
        return ApiResponse(success: true, data: deps, statusCode: response.statusCode);
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao listar departamentos.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<DepartamentoModel>> criarDepartamentoAdmin(String token, String adminToken, String nome) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/departamentos'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode({'nome': nome}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return ApiResponse(
          success: true,
          data: DepartamentoModel.fromJson(body['departamento']),
          message: body['message'],
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao criar departamento.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  // ==========================================
  // ADMIN: GESTÃO GLOBAL DE RESERVAS
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> getReservasAdmin(
    String token,
    String adminToken, {
    String? dataInicio,
    String? dataFim,
    String? escritorioId,
    String? departamentoId,
    String? status,
    String? busca,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (dataInicio != null && dataInicio.isNotEmpty) queryParams['dataInicio'] = dataInicio;
      if (dataFim != null && dataFim.isNotEmpty) queryParams['dataFim'] = dataFim;
      if (escritorioId != null && escritorioId != 'todos') queryParams['escritorioId'] = escritorioId;
      if (departamentoId != null && departamentoId != 'todos') queryParams['departamentoId'] = departamentoId;
      if (status != null && status != 'todos') queryParams['status'] = status;
      if (busca != null && busca.trim().isNotEmpty) queryParams['busca'] = busca.trim();

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/reservas').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List list = body['reservas'] ?? [];
        final reservas = list.map((r) => AdminReservaModel.fromJson(r)).toList();
        return ApiResponse(
          success: true,
          data: {
            'total': body['total'] ?? 0,
            'reservas': reservas,
          },
          statusCode: response.statusCode,
        );
      } else {
        final body = jsonDecode(response.body);
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao listar reservas.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> cancelarReservaAdmin(
    String token,
    String adminToken,
    int reservaId, {
    String? justificativa,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/reservas/$reservaId/cancelar'),
        headers: _headers(token, adminToken: adminToken),
        body: jsonEncode({'justificativa': justificativa ?? ''}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao cancelar reserva.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  // ==========================================
  // TI: INFRAESTRUTURA & SEGURANÇA
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> getConfiguracoesTi(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/ti/configuracoes'),
        headers: _headers(token),
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
        headers: _headers(token),
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
        headers: _headers(token),
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
        headers: _headers(token),
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
        headers: _headers(token),
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
      final response = await http.get(uri, headers: _headers(token));

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

  // ==========================================
  // RELATÓRIOS E BI DO RH
  // ==========================================

  Future<ApiResponse<Map<String, dynamic>>> getRelatoriosAnalytics(
    String token,
    String adminToken, {
    required String dataInicio,
    required String dataFim,
    String? escritorioId,
    String? departamentoId,
    String? status,
    String? checkinStatus,
    String? busca,
  }) async {
    try {
      final queryParams = {
        'dataInicio': dataInicio,
        'dataFim': dataFim,
        if (escritorioId != null && escritorioId != 'todos') 'escritorioId': escritorioId,
        if (departamentoId != null && departamentoId != 'todos') 'departamentoId': departamentoId,
        if (status != null && status != 'todos') 'status': status,
        if (checkinStatus != null && checkinStatus != 'todos') 'checkinStatus': checkinStatus,
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/relatorios/analytics').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers(token, adminToken: adminToken));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(body), statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao carregar analytics.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getRelatoriosDados(
    String token,
    String adminToken, {
    required String dataInicio,
    required String dataFim,
    String? escritorioId,
    String? departamentoId,
    String? status,
    String? checkinStatus,
    String? busca,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = {
        'dataInicio': dataInicio,
        'dataFim': dataFim,
        if (escritorioId != null && escritorioId != 'todos') 'escritorioId': escritorioId,
        if (departamentoId != null && departamentoId != 'todos') 'departamentoId': departamentoId,
        if (status != null && status != 'todos') 'status': status,
        if (checkinStatus != null && checkinStatus != 'todos') 'checkinStatus': checkinStatus,
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/relatorios/dados').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers(token, adminToken: adminToken));

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: Map<String, dynamic>.from(body), statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Erro ao carregar dados do relatório.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Uint8List>> downloadRelatorioXlsx(
    String token,
    String adminToken, {
    required String dataInicio,
    required String dataFim,
    String? escritorioId,
    String? departamentoId,
    String? status,
    String? checkinStatus,
    String? busca,
  }) async {
    try {
      final queryParams = {
        'dataInicio': dataInicio,
        'dataFim': dataFim,
        if (escritorioId != null && escritorioId != 'todos') 'escritorioId': escritorioId,
        if (departamentoId != null && departamentoId != 'todos') 'departamentoId': departamentoId,
        if (status != null && status != 'todos') 'status': status,
        if (checkinStatus != null && checkinStatus != 'todos') 'checkinStatus': checkinStatus,
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/relatorios/exportar/xlsx').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.bodyBytes, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Falha ao baixar planilha Excel (Código ${response.statusCode}).', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro ao exportar Excel: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Uint8List>> downloadRelatorioPdf(
    String token,
    String adminToken, {
    required String dataInicio,
    required String dataFim,
    String? escritorioId,
    String? departamentoId,
    String? status,
    String? checkinStatus,
    String? busca,
  }) async {
    try {
      final queryParams = {
        'dataInicio': dataInicio,
        'dataFim': dataFim,
        if (escritorioId != null && escritorioId != 'todos') 'escritorioId': escritorioId,
        if (departamentoId != null && departamentoId != 'todos') 'departamentoId': departamentoId,
        if (status != null && status != 'todos') 'status': status,
        if (checkinStatus != null && checkinStatus != 'todos') 'checkinStatus': checkinStatus,
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/relatorios/exportar/pdf').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.bodyBytes, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Falha ao baixar PDF (Código ${response.statusCode}).', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro ao exportar PDF: $e', statusCode: 0);
    }
  }
}
