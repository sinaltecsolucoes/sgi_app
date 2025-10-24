// lib/models/user_model.dart

class UserModel {
  final int id;
  final String nome;
  final String tipo;

  UserModel({required this.id, required this.nome, required this.tipo});

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: int.parse(json['funcionario_id'].toString()),
      nome: json['funcionario_nome'] as String,
      tipo: json['funcionario_tipo'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'funcionario_id': id,
    'funcionario_nome': nome,
    'funcionario_tipo': tipo,
  };
}
