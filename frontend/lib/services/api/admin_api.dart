import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../models/admin_models.dart';
import '../../models/seat_model.dart';
import 'api_client_base.dart';

class AdminApi extends ApiClientBase {
  Future<ApiResponse<List<dynamic>>> getParametros(String token, String adminToken) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/parametros'),
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

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
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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

  Future<ApiResponse<List<DepartamentoModel>>> getDepartamentosAdmin(String token, String adminToken) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/departamentos'),
        headers: headers(token, adminToken: adminToken),
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
        headers: headers(token, adminToken: adminToken),
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
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

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
        headers: headers(token, adminToken: adminToken),
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
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

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
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

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
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

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
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: response.bodyBytes, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Falha ao baixar PDF (Código ${response.statusCode}).', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro ao exportar PDF: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> colocarCadeiraEmManutencao(
    String token,
    String? adminToken,
    int cadeiraId, {
    required String motivo,
    String? previsaoRetorno,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/cadeiras/$cadeiraId/manutencao'),
        headers: headers(token, adminToken: adminToken),
        body: jsonEncode({
          'motivo': motivo,
          if (previsaoRetorno != null) 'previsaoRetorno': previsaoRetorno,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Falha ao colocar assento em manutenção.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> liberarCadeiraManutencao(
    String token,
    String? adminToken,
    int cadeiraId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/admin/cadeiras/$cadeiraId/liberar'),
        headers: headers(token, adminToken: adminToken),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return ApiResponse(success: true, data: body, message: body['message'], statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: body['error'] ?? 'Falha ao liberar assento da manutenção.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<List<HistoricoReservaModel>>> getHistoricoCadeira(
    String token,
    String? adminToken,
    int cadeiraId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/admin/cadeiras/$cadeiraId/historico'),
        headers: headers(token, adminToken: adminToken),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['historico'] as List? ?? [];
        final itens = list.map((item) => HistoricoReservaModel.fromJson(item)).toList();
        return ApiResponse(success: true, data: itens, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Falha ao buscar histórico do assento.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> getCadeirasManutencao(
    String token,
    String? adminToken, {
    String? escritorioId,
    String? busca,
  }) async {
    try {
      final queryParams = {
        if (escritorioId != null && escritorioId != 'todos') 'escritorioId': escritorioId,
        if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/cadeiras/manutencao').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final kpis = AdminManutencaoKpisModel.fromJson(body['kpis'] ?? {});
        final list = body['manutencoes'] as List? ?? [];
        final itens = list.map((item) => AdminManutencaoModel.fromJson(item)).toList();
        return ApiResponse(
          success: true,
          data: {
            'kpis': kpis,
            'manutencoes': itens,
          },
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(success: false, error: 'Falha ao buscar manutenções.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<List<AdminCadeiraOptionModel>>> getTodasCadeiras(
    String token,
    String? adminToken, {
    String? escritorioId,
  }) async {
    try {
      final queryParams = {
        if (escritorioId != null && escritorioId != 'todos') 'escritorioId': escritorioId,
      };

      final uri = Uri.parse('${AppConstants.baseUrl}/admin/cadeiras/todas').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers(token, adminToken: adminToken));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List? ?? [];
        final itens = list.map((item) => AdminCadeiraOptionModel.fromJson(item)).toList();
        return ApiResponse(success: true, data: itens, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Falha ao listar cadeiras.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }
}
