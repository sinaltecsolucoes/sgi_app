// lib/screens/registro_presenca_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

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
  List<FuncionarioPresenca> _funcionariosFiltrados = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarFuncionarios);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarFuncionarios);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(authProvider);

    if (_funcionarios.isEmpty) {
      _loadFuncionarios();
    }
  }

  void _filtrarFuncionarios() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _funcionariosFiltrados = _funcionarios
          .where((f) => f.nome.toLowerCase().contains(query))
          .toList();
    });
  }

  void _loadFuncionarios() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getFuncionariosParaChamada();

    if (!mounted) return;

    if (result['success']) {
      final lista = (result['funcionarios'] as List)
          .map((f) => FuncionarioPresenca.fromJson(f))
          .toList();

      setState(() {
        _funcionarios = lista;
        _funcionariosFiltrados = lista; // inicial
      });
    } else {
      _showSnackBar(
        result['message'] ?? 'Erro ao carregar funcionários.',
        isError: true,
      );
    }
    setState(() => _isLoading = false);
  }

  void _salvarChamada() async {
    if (_funcionarios.isEmpty) {
      _showSnackBar('Nenhum funcionário disponível.', isError: true);
      return;
    }

    final presentesIds = _funcionarios
        .where((f) => f.estaPresente)
        .map((f) => f.id)
        .toList();

    setState(() => _isLoading = true);
    final result = await _apiService.salvarChamada(presentesIds);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      _showSnackBar('Chamada salva com sucesso!', isError: false);
      Navigator.of(context).pop();
    } else {
      _showSnackBar(result['message'] ?? 'Erro ao salvar.', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Realizar Chamada'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            // CAMPO DE BUSCA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar funcionário...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // LISTA FILTRADA
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _funcionariosFiltrados.isEmpty
                  ? const Center(child: Text('Nenhum funcionário encontrado'))
                  : ListView.builder(
                      itemCount: _funcionariosFiltrados.length,
                      itemBuilder: (context, index) {
                        final f = _funcionariosFiltrados[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: CheckboxListTile(
                            secondary: Icon(
                              f.estaPresente
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: f.estaPresente ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              f.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              f.estaPresente ? 'Presente' : 'Ausente',
                              style: TextStyle(
                                color: f.estaPresente
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            value: f.estaPresente,
                            onChanged: (val) {
                              setState(() {
                                // Atualiza na lista original também!
                                final original = _funcionarios.firstWhere(
                                  (e) => e.id == f.id,
                                );
                                original.estaPresente = val ?? false;
                                f.estaPresente = val ?? false;
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),

            // BOTÃO SALVAR
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
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
