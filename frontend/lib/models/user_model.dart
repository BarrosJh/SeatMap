import 'dart:convert';

class UserModel {
  final int userId;
  final String nome;
  final String email;
  final String matricula;
  final String perfil; // 'COLABORADOR' | 'GESTAO' | 'ADMIN_RH' | 'ADMIN_TI'
  final bool permissaoRh;
  final bool permissaoTi;
  final int? departamentoId;
  final String? departamentoNome;

  UserModel({
    required this.userId,
    required this.nome,
    required this.email,
    required this.matricula,
    required this.perfil,
    this.permissaoRh = false,
    this.permissaoTi = false,
    this.departamentoId,
    this.departamentoNome,
  });

  bool get isAdmin => permissaoRh || perfil == 'ADMIN_RH';
  bool get isTi => permissaoTi || perfil == 'ADMIN_TI';
  bool get isGestao => perfil == 'GESTAO';
  bool get isColaborador => perfil == 'COLABORADOR';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final perfilStr = json['perfil'] ?? 'COLABORADOR';
    final hasRh = json['permissaoRh'] == true || 
                  json['permissao_rh'] == true || 
                  json['is_admin'] == true || 
                  perfilStr == 'ADMIN_RH';
    final hasTi = json['permissaoTi'] == true ||
                  json['permissao_ti'] == true ||
                  perfilStr == 'ADMIN_TI';

    return UserModel(
      userId: json['userId'] ?? json['id'] ?? 0,
      nome: json['nome'] ?? '',
      email: json['email'] ?? '',
      matricula: json['matricula'] ?? '',
      perfil: perfilStr,
      permissaoRh: hasRh,
      permissaoTi: hasTi,
      departamentoId: json['departamentoId'] ?? json['departamento_id'],
      departamentoNome: json['departamentoNome'] ?? json['departamento_nome'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nome': nome,
      'email': email,
      'matricula': matricula,
      'perfil': perfil,
      'permissaoRh': permissaoRh,
      'permissao_rh': permissaoRh,
      'permissaoTi': permissaoTi,
      'permissao_ti': permissaoTi,
      'is_admin': permissaoRh,
      'departamentoId': departamentoId,
      'departamentoNome': departamentoNome,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonStr) {
    return UserModel.fromJson(jsonDecode(jsonStr));
  }
}

