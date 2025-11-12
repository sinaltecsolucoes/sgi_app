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

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      _showSnackBar('Usuário não autenticado.', isError: true);
      return;
    }

    final result = await _apiService.getEquipeDados(apontadorId: user.id);

    debugPrint('RESULTADO montarEquipeScreen: $result');

    if (result['success']) {
      final data = result['data'];
      debugPrint('DATA montarEquipeScreen: $data');
      final equipeAtual = data['equipe_atual'];
      final membrosIdsAtuais = List<int>.from(data['membros_equipe_ids'] ?? []);
      final funcionariosApi = List<Map<String, dynamic>>.from(
        data['funcionarios_producao'] ?? [],
      );

      _nomeEquipeAtual =
          equipeAtual?['nome'] ??
          'Equipe ${DateTime.now().day}/${DateTime.now().month}';
      _nomeEquipeController.text = _nomeEquipeAtual;

      /*_membrosDisponiveis = funcionariosApi
          .map(
            (f) => FuncionarioMembro.fromJson(
              f,
              membrosIdsAtuais.contains(f['id']),
            ),
          )
          .toList();*/
      _membrosDisponiveis = funcionariosApi
          .where((f) => f['presente'] == 1 && f['na_minha_equipe'] == false)
          .map((f) => FuncionarioMembro.fromJson(f, false))
          .toList();
    } else {
      debugPrint('ERRO montarEquipeScreen: ${result['message']}');
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

    final nomeEquipe = _nomeEquipeController.text.trim();
    final nomeFinal = nomeEquipe.isEmpty
        ? 'Equipe ${DateTime.now().hour}h${DateTime.now().minute.toString().padLeft(2, '0')}'
        : nomeEquipe;

    setState(() => _isLoading = true);

    final result = await _apiService.salvarEquipe(
      nomeFinal,
      membrosSelecionadosIds,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showSnackBar(
      result['message'] ??
          (result['success'] ? 'Equipe salva!' : 'Erro ao salvar.'),
      isError: !(result['success'] ?? false),
    );

    if (result['success']) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Montar Equipe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // ← ADICIONADO
              child: Column(
                children: [
                  // === Cabeçalho ===
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _nomeEquipeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Equipe',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Funcionários Disponíveis:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(),

                  // === Lista com rolagem ===
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _membrosDisponiveis.length,
                      itemBuilder: (context, index) {
                        final membro = _membrosDisponiveis[index];
                        return Card(
                          child: CheckboxListTile(
                            title: Text(membro.nome),
                            subtitle: Text(
                              membro.presente ? 'Presente' : 'Ausente',
                            ),
                            value: membro.isSelecionado,
                            onChanged: (bool? newValue) {
                              setState(() {
                                membro.isSelecionado = newValue ?? false;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // === Botão fixo na parte inferior ===
                  SafeArea(
                    // ← SEGUNDO SafeArea (opcional, mas seguro)
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: _salvarEquipe,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'Salvar Equipe',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
