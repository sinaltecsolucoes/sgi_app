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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(auth);
    _tabController.removeListener(_handleTabChange);
    _loadDados();
  }

  // Método para tratar a mudança de aba
  void _handleTabChange() {
    if (_tabController.index == _equipes.length) {
      // Se a aba "adicionar" for selecionada
      _tabController.animateTo(
        _tabController.previousIndex,
      ); // Volta para a aba anterior
      _navigateToMontarEquipe();
    }
  }

  // Método para encapsular a navegação
  void _navigateToMontarEquipe() async {
    final novaEquipe = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MontarEquipeScreen()),
    );
    // Recarrega os dados após criar/editar a equipe
    if (novaEquipe == true) _loadDados();
  }

  void _loadDados() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getEquipeDados(
      apontadorId: Provider.of<AuthProvider>(context, listen: false).user!.id,
    );

    // DEBUG: imprimir tudo que veio da API
    debugPrint('RESULTADO getEquipeDados: $result');

    if (result['success']) {
      final data = result['data'];

      debugPrint('DATA: $data');

      // Obter a lista completa de equipes.
      final equipesDoApontador = data['equipes_do_apontador'] as List?;
      final equipeAtual = data['equipe_atual'];
      final membrosIds = List<int>.from(data['membros_equipe_ids'] ?? []);

      setState(() {
        // Prioriza a lista completa de equipes do apontador
        if (equipesDoApontador != null) {
          _equipes = List<Map<String, dynamic>>.from(equipesDoApontador);
        } else {
          // Lógica de fallback se o PHP não foi atualizado ou só encontrou uma equipe
          _equipes = [if (equipeAtual != null) equipeAtual];
        }

        // 1. Crie um NOVO TabController com o novo tamanho
        _tabController.dispose(); // Descarte o antigo
        _tabController = TabController(
          length: _equipes.length + 1, // +1 para a aba de adição
          vsync: this,
        );
        // 2. Adicione o listener (que usa o novo _tabController)
        _tabController.addListener(_handleTabChange);

        _isLoading = false;
      });
    } else {
      debugPrint('ERRO: ${result['message']}');
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
            onPressed: _navigateToMontarEquipe, // CHAMA A NOVA FUNÇÃO
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
                    onPressed:
                        _navigateToMontarEquipe, // Usa o método de navegação
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
                   /* const Tab(
                      icon: Icon(Icons.add),
                    ),*/ // Apenas o ícone para indicar "Nova"
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

  /* Widget _buildEquipeTab(Map<String, dynamic> equipe) {
    // Implementar edição inline ou modal
    return Center(child: Text('Equipe: ${equipe['nome']}'));
  } */

  /* Widget _buildEquipeTab(Map<String, dynamic> equipe) {
    final membros = List<Map<String, dynamic>>.from(equipe['membros'] ?? []);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${equipe['nome']}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...membros.map(
          (m) => ListTile(
            leading: const Icon(Icons.person),
            title: Text(m['nome']),
          ),
        ),
      ],
    );
  } */

  Widget _buildEquipeTab(Map<String, dynamic> equipe) {
    final membros = List<Map<String, dynamic>>.from(equipe['membros'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nome da equipe
        Text(
          equipe['nome'] ?? 'Equipe sem nome',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Subtítulo
        const Text(
          'Membros da equipe:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Divider(),

        // Lista de membros ou mensagem de vazio
        if (membros.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Nenhum membro nesta equipe.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...membros.map(
            (m) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(m['nome']),
            ),
          ),
      ],
    );
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
    _tabController.removeListener(_handleTabChange); // REMOVE O LISTENER
    _tabController.dispose();
    super.dispose();
  }
}
