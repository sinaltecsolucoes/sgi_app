// lib/screens/montar_equipe_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

// Modelo Simples para Membros (usado apenas nesta tela)
class FuncionarioMembro {
  final int id;
  final String nome;
  final bool presente;
  bool isSelecionado;

  FuncionarioMembro({
    required this.id,
    required this.nome,
    required this.presente,
    this.isSelecionado = false,
  });

  factory FuncionarioMembro.fromJson(
    Map<String, dynamic> json,
    bool isMembroAtual,
  ) {
    return FuncionarioMembro(
      id: json['id'] as int,
      nome: json['nome'] as String,
      presente: (json['presente'] as int) == 1,
      isSelecionado: isMembroAtual,
    );
  }
}

class MontarEquipeScreen extends StatefulWidget {
  const MontarEquipeScreen({super.key});

  @override
  State<MontarEquipeScreen> createState() => _MontarEquipeScreenState();
}

class _MontarEquipeScreenState extends State<MontarEquipeScreen> {
  final TextEditingController _nomeEquipeController = TextEditingController();
  late ApiService _apiService;

  List<FuncionarioMembro> _membrosDisponiveis = [];
  String _nomeEquipeAtual = 'Equipe do Dia';
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(authProvider);

    if (_membrosDisponiveis.isEmpty) {
      _loadEquipeDados();
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    // 1. Garantir que o widget ainda está montado
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _loadEquipeDados() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.getEquipeDados();

    if (result['success']) {
      final data = result['data'];
      final equipeAtual = data['equipe_atual'];
      final membrosIdsAtuais = List<int>.from(data['membros_equipe_ids'] ?? []);
      final funcionariosApi = List<Map<String, dynamic>>.from(
        data['funcionarios_producao'] ?? [],
      );

      _nomeEquipeAtual =
          equipeAtual?['nome'] ??
          'Equipe ${DateTime.now().day}/${DateTime.now().month}';
      _nomeEquipeController.text = _nomeEquipeAtual;

      _membrosDisponiveis = funcionariosApi
          .where((f) => f['presente'] == 1)
          .map(
            (f) => FuncionarioMembro.fromJson(
              f,
              membrosIdsAtuais.contains(f['id']),
            ),
          )
          .toList();
    } else {
      _showSnackBar(
        result['message'] ?? 'Erro ao carregar dados.',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _salvarEquipe() async {
    if (_membrosDisponiveis.isEmpty) {
      _showSnackBar('Nenhum funcionário disponível.', isError: true);
      return;
    }

    final membrosSelecionadosIds = _membrosDisponiveis
        .where((m) => m.isSelecionado)
        .map((m) => m.id)
        .toList();

    if (membrosSelecionadosIds.isEmpty) {
      _showSnackBar(
        'Selecione ao menos um membro para a equipe.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.salvarEquipe(
      _nomeEquipeController.text,
      membrosSelecionadosIds,
    );

    setState(() {
      _isLoading = false;
    });

    // 1. Checagem de 'mounted' antes de usar BuildContext para navegação
    if (!mounted) return;

    if (result['success']) {
      _showSnackBar(
        result['message'] ?? 'Equipe salva com sucesso!',
        isError: false,
      );
      Navigator.of(context).pop(); // Citação de BuildContext síncrona
    } else {
      _showSnackBar(
        result['message'] ?? 'Falha ao salvar equipe.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Montagem de Equipe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nomeEquipeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Equipe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Funcionários Presentes:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  ..._membrosDisponiveis.map((membro) {
                    return Card(
                      child: CheckboxListTile(
                        title: Text(membro.nome),
                        subtitle: Text(membro.presente ? 'Presente' : 'Faltou'),
                        value: membro.isSelecionado,
                        onChanged: (bool? newValue) {
                          setState(() {
                            membro.isSelecionado = newValue ?? false;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _salvarEquipe,
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Salvar Equipe',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
