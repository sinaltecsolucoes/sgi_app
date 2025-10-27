// lib/models/produto_model.dart

class ProdutoModel {
  final int id;
  final String nome;
  final bool usaLote; // Flag essencial para a validação na tela

  ProdutoModel({required this.id, required this.nome, required this.usaLote});

  factory ProdutoModel.fromJson(Map<String, dynamic> json) {
    return ProdutoModel(
      id: json['id'] as int,
      nome: json['nome'] as String,
      // A API retorna 1 ou 0, convertemos para bool
      usaLote: (json['usa_lote'] as int) == 1,
    );
  }
}
