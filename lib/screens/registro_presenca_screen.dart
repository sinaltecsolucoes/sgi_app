// lib/screens/registro_presenca_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

// Modelo Simples para Funcionários de Presença
class FuncionarioPresenca {
  final int id;
  final String nome;
  bool estaPresente;

  FuncionarioPresenca({
    required this.id,
    required this.nome,
    required this.estaPresente,
  });

  factory FuncionarioPresenca.fromJson(Map<String, dynamic> json) {
    return FuncionarioPresenca(
      id: json['id'] as int,
      nome: json['nome'] as String,
      // A API retorna 1 ou 0
      estaPresente: (json['esta_presente'] as int) == 1,
    );
  }
}

class RegistroPresencaScreen extends StatefulWidget {
  const RegistroPresencaScreen({super.key});

  @override
  State<RegistroPresencaScreen> createState() => _RegistroPresencaScreenState();
}

class _RegistroPresencaScreenState extends State<RegistroPresencaScreen> {
  late ApiService _apiService;

  List<FuncionarioPresenca> _funcionarios = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(authProvider);

    if (_funcionarios.isEmpty) {
      _loadFuncionarios();
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

  // Carrega a lista de funcionários do novo endpoint
  void _loadFuncionarios() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.getFuncionariosParaChamada();

    if (result['success']) {
      setState(() {
        final List<Map<String, dynamic>> funcionariosApi =
            List<Map<String, dynamic>>.from(result['funcionarios'] ?? []);

        // Mapeia os dados da API para o modelo local
        _funcionarios = funcionariosApi
            .map((f) => FuncionarioPresenca.fromJson(f))
            .toList();
      });
    } else {
      _showSnackBar(
        result['message'] ?? 'Erro ao carregar lista de funcionários.',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _salvarChamada() async {
    if (_funcionarios.isEmpty) {
      _showSnackBar('Nenhum funcionário disponível.', isError: true);
      return;
    }

    // Coleta apenas os IDs dos funcionários que estão marcados como PRESENTES
    final presentesIds = _funcionarios
        .where((f) => f.estaPresente)
        .map((f) => f.id)
        .toList();

    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.salvarChamada(presentesIds);

    setState(() {
      _isLoading = false;
    });

    // 1. Checagem de 'mounted' antes de usar BuildContext para navegação
    if (!mounted) return;

    if (result['success']) {
      _showSnackBar(
        result['message'] ?? 'Chamada salva com sucesso!',
        isError: false,
      );
      // Sucesso: Retorna para a tela principal
      Navigator.of(context).pop(); // Citação de BuildContext síncrona
    } else {
      _showSnackBar(
        result['message'] ?? 'Falha ao salvar a chamada.',
        isError: true,
      );
    }
  }

  /* @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realizar Chamada'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_funcionarios.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum funcionário de produção encontrado.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _funcionarios.length,
                          itemBuilder: (context, index) {
                            final funcionario = _funcionarios[index];

                            // Estilo condicional para feedback visual
                            final color = funcionario.estaPresente
                                //? Colors.green.withOpacity(0.1)
                                // : Colors.red.withOpacity(0.1);
                                ? Colors.green.withAlpha(50)
                                : Colors.red.withAlpha(50);

                            return Card(
                              color: color,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: CheckboxListTile(
                                title: Text(
                                  funcionario.nome,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: funcionario.estaPresente
                                        ? Colors.black87
                                        : Colors.red,
                                  ),
                                ),
                                subtitle: Text(
                                  funcionario.estaPresente
                                      ? 'Presente'
                                      : 'Ausente',
                                ),
                                value: funcionario.estaPresente,
                                onChanged: (bool? newValue) {
                                  setState(() {
                                    // Atualiza o estado da lista
                                    funcionario.estaPresente =
                                        newValue ?? false;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      // Botão Salvar Fixo no rodapé
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton.icon(
                          onPressed: _salvarChamada,
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'Salvar Chamada',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ),
                    ],
                  )),
    );
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realizar Chamada'), centerTitle: true),
      body: SafeArea(
        // ← GARANTE QUE NÃO FIQUE ATRÁS DOS BOTÕES DO SISTEMA
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // === LISTA DE FUNCIONÁRIOS (EXPANDIDA) ===
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _funcionarios.length,
                        itemBuilder: (context, index) {
                          final funcionario = _funcionarios[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: CheckboxListTile(
                              title: Text(
                                funcionario.nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: funcionario.estaPresente
                                      ? Colors.black87
                                      : Colors.grey[600],
                                ),
                              ),
                              subtitle: Text(
                                funcionario.estaPresente
                                    ? 'Presente'
                                    : 'Ausente',
                                style: TextStyle(
                                  color: funcionario.estaPresente
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              value: funcionario.estaPresente,
                              onChanged: (bool? value) {
                                setState(() {
                                  funcionario.estaPresente = value ?? false;
                                });
                              },
                              secondary: Icon(
                                funcionario.estaPresente
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: funcionario.estaPresente
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // === BOTÃO FIXO NO FINAL (NUNCA MAIS ESCONDIDO!) ===
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _salvarChamada,
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'SALVAR CHAMADA',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
