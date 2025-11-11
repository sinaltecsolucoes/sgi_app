// lib/screens/gerenciar_equipes_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'montar_equipe_screen.dart';

class GerenciarEquipesScreen extends StatefulWidget {
  const GerenciarEquipesScreen({super.key});

  @override
  State<GerenciarEquipesScreen> createState() => _GerenciarEquipesScreenState();
}

class _GerenciarEquipesScreenState extends State<GerenciarEquipesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late ApiService _apiService;
  List<Map<String, dynamic>> _equipes = [];
  List<FuncionarioMembro> _disponiveis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(auth);
    _loadDados();
  }

  void _loadDados() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getEquipeDados(
      apontadorId: Provider.of<AuthProvider>(context, listen: false).user!.id,
    );

    if (result['success']) {
      final data = result['data'];
      final equipeAtual = data['equipe_atual'];
      final membrosIds = List<int>.from(data['membros_equipe_ids'] ?? []);

      setState(() {
        _equipes = [if (equipeAtual != null) equipeAtual];
        _disponiveis = (data['funcionarios_producao'] as List)
            .map(
              (f) =>
                  FuncionarioMembro.fromJson(f, membrosIds.contains(f['id'])),
            )
            .toList();

        _tabController = TabController(
          length: _equipes.length + 1,
          vsync: this,
        );
        _isLoading = false;
      });
    } else {
      _showSnackBar(result['message'], isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Equipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final novaEquipe = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MontarEquipeScreen()),
              );
              if (novaEquipe == true) _loadDados();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _equipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.group_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Nenhuma equipe criada hoje.'),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MontarEquipeScreen(),
                      ),
                    ),
                    child: const Text('Criar Primeira Equipe'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    ..._equipes.map((e) => Tab(text: e['nome'])),
                    const Tab(icon: Icon(Icons.add)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ..._equipes.map((e) => _buildEquipeTab(e)),
                      _buildNovaEquipeTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEquipeTab(Map<String, dynamic> equipe) {
    // Implementar edição inline ou modal
    return Center(child: Text('Equipe: ${equipe['nome']}'));
  }

  Widget _buildNovaEquipeTab() {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MontarEquipeScreen()),
        ),
        child: const Text('Criar Nova Equipe'),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
