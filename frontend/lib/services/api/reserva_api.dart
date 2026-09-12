import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../models/seat_model.dart';
import 'api_client_base.dart';

class ReservaApi extends ApiClientBase {
  Future<ApiResponse<List<EscritorioModel>>> getEscritorios(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/escritorios'),
        headers: headers(token),
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
        Uri.parse('${AppConstants.baseUrl}/escritorios/ocupacao-semanal'),
        headers: headers(token),
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
        headers: headers(token),
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
        headers: headers(token),
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

  Future<ApiResponse<Map<String, dynamic>>> criarReserva(String token, int cadeiraId, String dataIso) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas'),
        headers: headers(token),
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

  Future<ApiResponse<Map<String, dynamic>>> fazerCheckin(String token, int reservaId, {int? cadeiraId}) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas/$reservaId/checkin'),
        headers: headers(token),
        body: jsonEncode({'cadeiraId': cadeiraId}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = body is Map<String, dynamic> ? body : (body != null ? Map<String, dynamic>.from(body) : null);
        return ApiResponse(success: true, data: data, message: body['message'], statusCode: response.statusCode);
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
        headers: headers(token),
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

  Future<ApiResponse<Map<String, dynamic>>> liberarMesa(String token, int reservaId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas/$reservaId/liberar'),
        headers: headers(token),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = body['reserva'] != null
            ? Map<String, dynamic>.from(body['reserva'])
            : (body is Map<String, dynamic> ? body : null);
        return ApiResponse(
          success: true,
          data: data,
          message: body['message'] ?? 'Mesa liberada com sucesso.',
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          success: false,
          error: body['error'] ?? 'Erro ao liberar mesa.',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }

  Future<ApiResponse<String>> enviarComprovanteEmail(String token, int reservaId) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/reservas/$reservaId/enviar-comprovante-email'),
        headers: headers(token),
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
        headers: headers(token),
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

  Future<ApiResponse<List<HistoricoReservaModel>>> getHistoricoReservasUsuario(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/reservas/historico'),
        headers: headers(token),
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List? ?? [];
        final itens = list.map((item) => HistoricoReservaModel.fromJson(item)).toList();
        return ApiResponse(success: true, data: itens, statusCode: response.statusCode);
      } else {
        return ApiResponse(success: false, error: 'Falha ao buscar histórico do usuário.', statusCode: response.statusCode);
      }
    } catch (e) {
      return ApiResponse(success: false, error: 'Erro de conexão: $e', statusCode: 0);
    }
  }
}
