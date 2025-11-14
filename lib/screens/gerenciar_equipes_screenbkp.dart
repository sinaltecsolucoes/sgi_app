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

  final Map<int, Set<int>> _membrosParaRemover = <int, Set<int>>{};
  bool _temAlteracoes = false;

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
    _loadDados();
  }

  int _toInt(dynamic id) =>
      id is int ? id : (id is String ? int.tryParse(id) ?? 0 : 0);

  Future<void> _loadDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await _apiService.getEquipeDados(apontadorId: auth.user!.id);

    if (!mounted) return;

    if (result['success']) {
      final rawData = result['data'];
      List<Map<String, dynamic>> data = [];

      if (rawData is List) {
        data = List<Map<String, dynamic>>.from(rawData);
      } else if (rawData is Map<String, dynamic> &&
          rawData['equipes'] is List) {
        data = List<Map<String, dynamic>>.from(rawData['equipes']);
      }

      setState(() {
        _equipes = data;
        _tabController.removeListener(_handleTabChange);
        _tabController = TabController(
          length: _equipes.length + 1,
          vsync: this,
        );
        _tabController.addListener(_handleTabChange);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      _showSnackBar('Erro: ${result['message']}', isError: true);
    }
  }

  void _handleTabChange() {
    if (_tabController.index == _equipes.length) {
      _tabController.animateTo(_tabController.previousIndex);
      _criarNovaEquipe();
    }
  }

  Future<void> _criarNovaEquipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MontarEquipeScreen()),
    );
    if (result == true && mounted) await _loadDados();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // === EDITAR EQUIPE ===
  Future<void> _editarEquipe(int equipeId, String nomeAtual) async {
    final nomeCtrl = TextEditingController(text: nomeAtual);
    final Set<int> selecionados = <int>{};

    final disponiveisRes = await _apiService.buscarFuncionariosDisponiveis();
    if (!disponiveisRes['success']) {
      _showSnackBar('Erro ao carregar disponíveis.', isError: true);
      return;
    }

    final disponiveisRaw = disponiveisRes['funcionarios'];
    if (disponiveisRaw is! List) {
      _showSnackBar('Formato inválido.', isError: true);
      return;
    }

    final List<Map<String, dynamic>> disponiveis =
        List<Map<String, dynamic>>.from(disponiveisRaw);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Equipe'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: Column(
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome da equipe'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Adicionar membros (disponíveis):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: disponiveis.isEmpty
                    ? const Center(child: Text('Nenhum disponível'))
                    : ListView.builder(
                        itemCount: disponiveis.length,
                        itemBuilder: (_, i) {
                          final f = disponiveis[i];
                          final int id = _toInt(f['id']);
                          final String nome =
                              f['nome']?.toString() ?? 'Sem nome';

                          return StatefulBuilder(
                            builder: (context, setStateDialog) {
                              return CheckboxListTile(
                                title: Text(nome),
                                value: selecionados.contains(id),
                                onChanged: (bool? v) {
                                  setStateDialog(() {
                                    if (v == true) {
                                      selecionados.add(id);
                                    } else {
                                      selecionados.remove(id);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final novoNome = nomeCtrl.text.trim();
              if (novoNome.isEmpty) {
                _showSnackBar('Nome é obrigatório.', isError: true);
                return;
              }
              if (!mounted) return;
              Navigator.pop(ctx);
              final res = await _apiService.editarEquipe(
                equipeId: equipeId,
                novoNome: novoNome,
                novosMembrosIds: selecionados.toList(),
              );
              _showSnackBar(
                res['success'] ? 'Atualizado!' : 'Erro: ${res['message']}',
                isError: !res['success'],
              );
              if (res['success']) await _loadDados();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // === MOVER MEMBRO ===
  Future<void> _moverMembro(
    int equipeId,
    int membroId,
    String nomeMembro,
  ) async {
    final outrasRes = await _apiService.buscarEquipesOutrosApontadores();
    if (!outrasRes['success']) {
      _showSnackBar('Erro ao carregar equipes.', isError: true);
      return;
    }

    final outrasRaw = outrasRes['equipes'];
    if (outrasRaw is! List || outrasRaw.isEmpty) {
      _showSnackBar('Nenhuma equipe disponível.', isError: true);
      return;
    }

    final List<Map<String, dynamic>> outras =
        List<Map<String, dynamic>>.from(outrasRaw);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mover $nomeMembro'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: outras.length,
            itemBuilder: (_, i) {
              final e = outras[i];
              final int destinoId = _toInt(e['id']);
              final String nomeEquipe = e['nome']?.toString() ?? 'Sem nome';
              final String apontadorNome =
                  e['apontador_nome']?.toString() ?? 'Desconhecido';

              return ListTile(
                title: Text(nomeEquipe),
                subtitle: Text('Apontador: $apontadorNome'),
                onTap: () async {
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  final res = await _apiService.moverMembro(
                    membroId: membroId,
                    equipeOrigemId: equipeId,
                    equipeDestinoId: destinoId,
                  );
                  _showSnackBar(
                    res['success'] ? 'Movido!' : 'Erro: ${res['message']}',
                    isError: !res['success'],
                  );
                  if (res['success']) await _loadDados();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _salvarRemocoes(int equipeId) async {
    final Set<int> removendo = _membrosParaRemover[equipeId] ?? <int>{};
    if (removendo.isEmpty) return;

    bool sucesso = true;
    for (final int id in removendo) {
      final res = await _apiService.retirarMembro(
        equipeId: equipeId,
        membroId: id,
      );
      if (!res['success']) {
        sucesso = false;
        // Linha corrigida: A duplicação da linha de showSnackBar foi removida.
        _showSnackBar('Erro ao remover: ${res['message']}', isError: true);
        break;
      }
    }

    if (sucesso) {
      _membrosParaRemover.remove(equipeId);
      setState(() => _temAlteracoes = false);
      _showSnackBar('Membro(s) removido(s)!');
      await _loadDados();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Equipes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            ..._equipes.map(
              (e) => Tab(text: e['nome']?.toString() ?? 'Equipe'),
            ),
            const Tab(icon: Icon(Icons.add)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [..._equipes.map(_buildAbaEquipe), _buildAbaNovaEquipe()],
      ),
    );
  }

  Widget _buildAbaEquipe(Map<String, dynamic> equipe) {
    final int equipeId = _toInt(equipe['id']);
    final List<Map<String, dynamic>> membros =
        (equipe['membros'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final Set<int> removendo = _membrosParaRemover.putIfAbsent(
      equipeId,
      () => <int>{},
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              equipe['nome']?.toString() ?? 'Sem nome',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () =>
                  _editarEquipe(equipeId, equipe['nome']?.toString() ?? ''),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Membros:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Divider(),
        if (membros.isEmpty)
          const Text('Nenhum membro.', style: TextStyle(color: Colors.grey))
        else
          ...membros.map((m) {
            final int membroId = _toInt(m['id']);
            final String nome = m['nome']?.toString() ?? 'Sem nome';
            final bool estaRemovendo = removendo.contains(membroId);

            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(nome),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: !estaRemovendo,
                    onChanged: (bool v) {
                      setState(() {
                        if (v) {
                          removendo.remove(membroId);
                        } else {
                          removendo.add(membroId);
                        }
                        _temAlteracoes = removendo.isNotEmpty;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.orange),
                    onPressed: estaRemovendo
                        ? null
                        : () => _moverMembro(equipeId, membroId, nome),
                  ),
                ],
              ),
            );
          }),
        if (_temAlteracoes && removendo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _salvarRemocoes(equipeId),
              child: const Text(
                'SALVAR REMOÇÃO',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAbaNovaEquipe() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _criarNovaEquipe,
        icon: const Icon(Icons.add),
        label: const Text('Criar Nova Equipe'),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
}