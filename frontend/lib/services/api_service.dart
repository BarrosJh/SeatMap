import 'dart:typed_data';
import '../models/seat_model.dart';
import '../models/admin_models.dart';
import 'api/api_client_base.dart';
import 'api/auth_api.dart';
import 'api/reserva_api.dart';
import 'api/admin_api.dart';
import 'api/ti_api.dart';

export 'api/api_client_base.dart' show ApiResponse;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final AuthApi _authApi = AuthApi();
  final ReservaApi _reservaApi = ReservaApi();
  final AdminApi _adminApi = AdminApi();
  final TiApi _tiApi = TiApi();

  AuthApi get auth => _authApi;
  ReservaApi get reservas => _reservaApi;
  AdminApi get admin => _adminApi;
  TiApi get ti => _tiApi;

  // ==========================================
  // AUTENTICAÇÃO, SSO & MFA
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> getConfigSeguranca() =>
      _authApi.getConfigSeguranca();

  Future<ApiResponse<Map<String, dynamic>>> login(String login, String senha) =>
      _authApi.login(login, senha);

  Future<ApiResponse<Map<String, dynamic>>> validarLoginTotp(String tempToken, String codigo) =>
      _authApi.validarLoginTotp(tempToken, codigo);

  Future<ApiResponse<Map<String, dynamic>>> validarLoginEmailMfa(String tempToken, String codigo) =>
      _authApi.validarLoginEmailMfa(tempToken, codigo);

  Future<ApiResponse<Map<String, dynamic>>> refreshToken(String refreshToken) =>
      _authApi.refreshToken(refreshToken);

  Future<ApiResponse<void>> logout(String? token, {String? refreshToken}) =>
      _authApi.logout(token, refreshToken: refreshToken);

  Future<ApiResponse<Map<String, dynamic>>> getSsoConfig() =>
      _authApi.getSsoConfig();

  Future<ApiResponse<Map<String, dynamic>>> solicitarMfa(String token) =>
      _authApi.solicitarMfa(token);

  Future<ApiResponse<String>> validarMfa(String token, String codigo) =>
      _authApi.validarMfa(token, codigo);

  Future<ApiResponse<Map<String, dynamic>>> solicitarRecuperacaoSenha(String login) =>
      _authApi.solicitarRecuperacaoSenha(login);

  Future<ApiResponse<String>> redefinirSenha(String login, String codigo, String novaSenha) =>
      _authApi.redefinirSenha(login, codigo, novaSenha);

  Future<ApiResponse<Map<String, dynamic>>> loginSso({
    required String provider,
    required String email,
    String? name,
    String? ssoId,
  }) =>
      _authApi.loginSso(provider: provider, email: email, name: name, ssoId: ssoId);

  // ==========================================
  // ESCRITÓRIOS & MAPA
  // ==========================================
  Future<ApiResponse<List<EscritorioModel>>> getEscritorios(String token) =>
      _reservaApi.getEscritorios(token);

  Future<ApiResponse<List<OcupacaoEscritorioModel>>> getOcupacaoSemanal(String token) =>
      _reservaApi.getOcupacaoSemanal(token);

  Future<ApiResponse<String>> getAvisoGlobal(String token) =>
      _reservaApi.getAvisoGlobal(token);

  Future<ApiResponse<MapaDataModel>> getMapa(String token, int escritorioId, String dataIso) =>
      _reservaApi.getMapa(token, escritorioId, dataIso);

  // ==========================================
  // RESERVAS
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> criarReserva(String token, int cadeiraId, String dataIso) =>
      _reservaApi.criarReserva(token, cadeiraId, dataIso);

  Future<ApiResponse<Map<String, dynamic>>> fazerCheckin(String token, int reservaId, {int? cadeiraId}) =>
      _reservaApi.fazerCheckin(token, reservaId, cadeiraId: cadeiraId);

  Future<ApiResponse<Map<String, dynamic>>> cancelarReserva(String token, int reservaId) =>
      _reservaApi.cancelarReserva(token, reservaId);

  Future<ApiResponse<String>> enviarComprovanteEmail(String token, int reservaId) =>
      _reservaApi.enviarComprovanteEmail(token, reservaId);

  Future<ApiResponse<List<ReservaModel>>> getMinhasReservas(String token) =>
      _reservaApi.getMinhasReservas(token);

  Future<ApiResponse<List<HistoricoReservaModel>>> getHistoricoReservasUsuario(String token) =>
      _reservaApi.getHistoricoReservasUsuario(token);

  // ==========================================
  // ADMIN: PARÂMETROS & OPERACIONAL
  // ==========================================
  Future<ApiResponse<List<dynamic>>> getParametros(String token, String adminToken) =>
      _adminApi.getParametros(token, adminToken);

  Future<ApiResponse<String>> updateParametros(String token, String adminToken, dynamic configuracoes) =>
      _adminApi.updateParametros(token, adminToken, configuracoes);

  Future<ApiResponse<Map<String, dynamic>>> executarLimpezaNoShow(String token, String adminToken, {String? dataIso}) =>
      _adminApi.executarLimpezaNoShow(token, adminToken, dataIso: dataIso);

  // ==========================================
  // ADMIN: USUÁRIOS & DEPARTAMENTOS
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
  }) =>
      _adminApi.getUsuariosAdmin(token, adminToken,
          busca: busca, departamentoId: departamentoId, perfil: perfil, ativo: ativo, limit: limit, offset: offset);

  Future<ApiResponse<AdminUsuarioModel>> criarUsuarioAdmin(
    String token,
    String adminToken,
    Map<String, dynamic> usuarioData,
  ) =>
      _adminApi.criarUsuarioAdmin(token, adminToken, usuarioData);

  Future<ApiResponse<AdminUsuarioModel>> updateUsuarioAdmin(
    String token,
    String adminToken,
    int id,
    Map<String, dynamic> usuarioData,
  ) =>
      _adminApi.updateUsuarioAdmin(token, adminToken, id, usuarioData);

  Future<ApiResponse<AdminUsuarioModel>> toggleStatusUsuarioAdmin(
    String token,
    String adminToken,
    int id, {
    bool? ativo,
  }) =>
      _adminApi.toggleStatusUsuarioAdmin(token, adminToken, id, ativo: ativo);

  Future<ApiResponse<String>> resetSenhaUsuarioAdmin(
    String token,
    String adminToken,
    int id,
    String novaSenha,
  ) =>
      _adminApi.resetSenhaUsuarioAdmin(token, adminToken, id, novaSenha);

  Future<ApiResponse<Map<String, dynamic>>> importarLoteUsuariosAdmin(
    String token,
    String adminToken,
    List<Map<String, dynamic>> usuarios, {
    String defaultSenha = 'Mudar@123',
  }) =>
      _adminApi.importarLoteUsuariosAdmin(token, adminToken, usuarios, defaultSenha: defaultSenha);

  Future<ApiResponse<List<DepartamentoModel>>> getDepartamentosAdmin(String token, String adminToken) =>
      _adminApi.getDepartamentosAdmin(token, adminToken);

  Future<ApiResponse<DepartamentoModel>> criarDepartamentoAdmin(String token, String adminToken, String nome) =>
      _adminApi.criarDepartamentoAdmin(token, adminToken, nome);

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
  }) =>
      _adminApi.getReservasAdmin(token, adminToken,
          dataInicio: dataInicio, dataFim: dataFim, escritorioId: escritorioId, departamentoId: departamentoId, status: status, busca: busca, limit: limit, offset: offset);

  Future<ApiResponse<String>> cancelarReservaAdmin(
    String token,
    String adminToken,
    int reservaId, {
    String? justificativa,
  }) =>
      _adminApi.cancelarReservaAdmin(token, adminToken, reservaId, justificativa: justificativa);

  // ==========================================
  // ADMIN: RELATÓRIOS E BI
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
  }) =>
      _adminApi.getRelatoriosAnalytics(token, adminToken,
          dataInicio: dataInicio, dataFim: dataFim, escritorioId: escritorioId, departamentoId: departamentoId, status: status, checkinStatus: checkinStatus, busca: busca);

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
  }) =>
      _adminApi.getRelatoriosDados(token, adminToken,
          dataInicio: dataInicio, dataFim: dataFim, escritorioId: escritorioId, departamentoId: departamentoId, status: status, checkinStatus: checkinStatus, busca: busca, page: page, limit: limit);

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
  }) =>
      _adminApi.downloadRelatorioXlsx(token, adminToken,
          dataInicio: dataInicio, dataFim: dataFim, escritorioId: escritorioId, departamentoId: departamentoId, status: status, checkinStatus: checkinStatus, busca: busca);

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
  }) =>
      _adminApi.downloadRelatorioPdf(token, adminToken,
          dataInicio: dataInicio, dataFim: dataFim, escritorioId: escritorioId, departamentoId: departamentoId, status: status, checkinStatus: checkinStatus, busca: busca);

  // ==========================================
  // FACILITIES & ASSENTOS OPERACIONAIS
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> colocarCadeiraEmManutencao(
    String token,
    String? adminToken,
    int cadeiraId, {
    required String motivo,
    String? previsaoRetorno,
  }) =>
      _adminApi.colocarCadeiraEmManutencao(token, adminToken, cadeiraId, motivo: motivo, previsaoRetorno: previsaoRetorno);

  Future<ApiResponse<Map<String, dynamic>>> liberarCadeiraManutencao(
    String token,
    String? adminToken,
    int cadeiraId,
  ) =>
      _adminApi.liberarCadeiraManutencao(token, adminToken, cadeiraId);

  Future<ApiResponse<List<HistoricoReservaModel>>> getHistoricoCadeira(
    String token,
    String? adminToken,
    int cadeiraId,
  ) =>
      _adminApi.getHistoricoCadeira(token, adminToken, cadeiraId);

  Future<ApiResponse<Map<String, dynamic>>> getCadeirasManutencao(
    String token,
    String? adminToken, {
    String? escritorioId,
    String? busca,
  }) =>
      _adminApi.getCadeirasManutencao(token, adminToken, escritorioId: escritorioId, busca: busca);

  Future<ApiResponse<List<AdminCadeiraOptionModel>>> getTodasCadeiras(
    String token,
    String? adminToken, {
    String? escritorioId,
  }) =>
      _adminApi.getTodasCadeiras(token, adminToken, escritorioId: escritorioId);

  // ==========================================
  // TI: INFRAESTRUTURA & AUDITORIA
  // ==========================================
  Future<ApiResponse<Map<String, dynamic>>> getConfiguracoesTi(String token) =>
      _tiApi.getConfiguracoesTi(token);

  Future<ApiResponse<String>> updateConfiguracoesTi(String token, Map<String, dynamic> data) =>
      _tiApi.updateConfiguracoesTi(token, data);

  Future<ApiResponse<Map<String, dynamic>>> testarConexaoEmail(
    String token, {
    String? emailDestino,
    String? nomeDestino,
  }) =>
      _tiApi.testarConexaoEmail(token, emailDestino: emailDestino, nomeDestino: nomeDestino);

  Future<ApiResponse<Map<String, dynamic>>> getStatusSistema(String token) =>
      _tiApi.getStatusSistema(token);

  Future<ApiResponse<List<dynamic>>> getAuditoriaMfa(String token) =>
      _tiApi.getAuditoriaMfa(token);

  Future<ApiResponse<Map<String, dynamic>>> getAuditoriaAcessos(
    String token, {
    int pagina = 1,
    int limite = 25,
    String? tipoEvento,
    String? termo,
    bool? sucesso,
  }) =>
      _tiApi.getAuditoriaAcessos(token, pagina: pagina, limite: limite, tipoEvento: tipoEvento, termo: termo, sucesso: sucesso);
}
