// lib/models/acao_model.dart

class AcaoModel {
  final int id;
  final String nome;

  AcaoModel({required this.id, required this.nome});

  factory AcaoModel.fromJson(Map<String, dynamic> json) {
    return AcaoModel(id: json['id'] as int, nome: json['nome'] as String);
  }
}
