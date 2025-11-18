// lib/screens/montar_equipe_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MontarEquipeScreen extends StatefulWidget {
  const MontarEquipeScreen({super.key});

  @override
  State<MontarEquipeScreen> createState() => _MontarEquipeScreenState();
}

class _MontarEquipeScreenState extends State<MontarEquipeScreen> {
  final TextEditingController _nomeController = TextEditingController();
  late ApiService _apiService;
  List<Map<String, dynamic>> _disponiveis = [];
  //Set<int> _selecionados = {};
  final Set<int> _selecionados = <int>{};
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = ApiService(Provider.of<AuthProvider>(context, listen: false));
    _loadDisponiveis();
  }

  Future<void> _loadDisponiveis() async {
    setState(() => _isLoading = true);
    final lista = await _apiService.buscarFuncionariosDisponiveis();
    if (mounted) {
      setState(() {
        _disponiveis = lista;
        _isLoading = false;
      });
    }
  }

  Future<void> _criarEquipe() async {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um membro.')),
      );
      return;
    }

    final nome = _nomeController.text.trim().isEmpty
        ? 'Equipe ${DateTime.now().hour}h${DateTime.now().minute.toString().padLeft(2, '0')}'
        : _nomeController.text.trim();

    setState(() => _isLoading = true);

    final result = await _apiService.salvarEquipe(nome, _selecionados.toList());

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Equipe criada com sucesso!'
              : 'Erro ao criar equipe',
        ),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );

    if (result['success'] == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Nova Equipe')),
      body: SafeArea(
        // SafeArea aqui
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da Equipe (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Selecione os membros disponíveis:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    _disponiveis.isEmpty
                        ? const Expanded(
                            child: Center(
                              child: Text(
                                'Nenhum funcionário disponível no momento.',
                              ),
                            ),
                          )
                        : Expanded(
                            child: ListView.builder(
                              itemCount: _disponiveis.length,
                              itemBuilder: (_, i) {
                                final f = _disponiveis[i];
                                final id = f['id'] as int;
                                return CheckboxListTile(
                                  title: Text(f['nome']),
                                  value: _selecionados.contains(id),
                                  /* onChanged: (v) => setState(
                                    () => v == true
                                        ? _selecionados.add(id)
                                        : _selecionados.remove(id),
                                  ),*/
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selecionados.add(id);
                                    } else {
                                      _selecionados.remove(id);
                                    }
                                  }),
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _criarEquipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'CRIAR EQUIPE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
