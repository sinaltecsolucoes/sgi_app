// ...existing code...
// lib/models/user_model.dart

class UserModel {
  final int id;
  final String nome;
  final String tipo;
  final String? token;

  UserModel({
    required this.id,
    required this.nome,
    required this.tipo,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.parse(json['funcionario_id'].toString()),
      nome: json['funcionario_nome'] as String,
      tipo: json['funcionario_tipo'] as String,
      token:
          (json['token'] ?? json['access_token'] ?? json['funcionario_token'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'funcionario_id': id,
    'funcionario_nome': nome,
    'funcionario_tipo': tipo,
    if (token != null) 'token': token,
  };
}
