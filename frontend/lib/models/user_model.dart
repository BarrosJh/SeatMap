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
    final perfilStr = json['perfil']?.toString() ?? 'COLABORADOR';
    final isSuperAdmin = json['is_admin'] == true && perfilStr != 'ADMIN_TI' && perfilStr != 'ADMIN_RH';
    final hasRh = json['permissaoRh'] == true || 
                  json['permissao_rh'] == true || 
                  isSuperAdmin ||
                  perfilStr == 'ADMIN_RH';
    final hasTi = json['permissaoTi'] == true ||
                  json['permissao_ti'] == true || 
                  isSuperAdmin ||
                  perfilStr == 'ADMIN_TI';

    return UserModel(
      userId: int.tryParse(json['userId']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      nome: json['nome']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      matricula: json['matricula']?.toString() ?? '',
      perfil: perfilStr,
      permissaoRh: hasRh,
      permissaoTi: hasTi,
      departamentoId: json['departamentoId'] != null 
          ? int.tryParse(json['departamentoId'].toString()) 
          : (json['departamento_id'] != null ? int.tryParse(json['departamento_id'].toString()) : null),
      departamentoNome: json['departamentoNome']?.toString() ?? json['departamento_nome']?.toString(),
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

