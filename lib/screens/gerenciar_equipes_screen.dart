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

  final Map<int, Set<int>> _membrosParaRemover = {}; //equipeId -> {membroId}
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
    _tabController.removeListener(_handleTabChange);
    _loadDados();
  }

  void _handleTabChange() {
    if (_tabController.index == _equipes.length) {
      _tabController.animateTo(_tabController.previousIndex);
      _navigateToMontarEquipe();
    }
  }

  Future<void> _navigateToMontarEquipe() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MontarEquipeScreen()),
    );
    if (result == true && mounted) {
      _loadDados(); // Recarrega ao voltar
    }
  }

  /* void _loadDados() async {
  if (!mounted) return;
  setState(() => _isLoading = true);

  final result = await _apiService.getEquipeDados(
    apontadorId: Provider.of<AuthProvider>(context, listen: false).user!.id,
  );

  if (!mounted) return;

  if (result['success']) {
    List<Map<String, dynamic>> data = [];

    // Verifica se 'data' é uma lista diretamente
    if (result['data'] is List) {
      data = List<Map<String, dynamic>>.from(result['data']);
    }
    // Verifica se 'data' é um Map com a chave 'equipes'
    else if (result['data'] is Map && result['data']['equipes'] is List) {
      data = List<Map<String, dynamic>>.from(result['data']['equipes']);
    }
    // Caso inesperado
    else {
      _showSnackBar('Formato de dados inválido.');
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _equipes = data;
      _tabController = TabController(length: _equipes.length + 1, vsync: this);
      _tabController.addListener(_handleTabChange);
      _isLoading = false;
    });
  } else {
    setState(() => _isLoading = false);
    _showSnackBar('Erro: ${result['message']}');
  }
}*/

  Future<void> _loadDados() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final result = await _apiService.getEquipeDados(
      apontadorId: Provider.of<AuthProvider>(context, listen: false).user!.id,
    );

    if (!mounted) return;

    if (result['success']) {
      List<Map<String, dynamic>> data = [];

      if (result['data'] is List) {
        data = List<Map<String, dynamic>>.from(result['data']);
      } else if (result['data'] is Map<String, dynamic> &&
          result['data']['equipes'] is List) {
        data = List<Map<String, dynamic>>.from(result['data']['equipes']);
      } else {
        _showSnackBar('Formato de dados inválido.');
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _equipes = data;

        // Recria o TabController
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
      _showSnackBar('Erro: ${result['message']}');
    }

    await _apiService.buscarEquipesOutrosApontadores();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // 1. MOVER MEMBRO
  Future<void> _moverMembro(int equipeId, int membroId, String nome) async {
    final equipes = await _apiService.buscarEquipesOutrosApontadores();
    if (!mounted) return;

    if (equipes.isEmpty) {
      _showSnackBar('Nenhuma equipe disponível.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mover $nome'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: equipes.length,
            itemBuilder: (_, i) {
              final e = equipes[i];
              return ListTile(
                title: Text(e['nome']),
                subtitle: Text('Apontador: ${e['apontador_nome']}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final res = await _apiService.moverMembro(
                    membroId: membroId,
                    equipeOrigemId: equipeId,
                    equipeDestinoId: e['id'],
                  );
                  if (!mounted) return;
                  _showSnackBar(
                    res['success'] ? 'Movido!' : 'Erro: ${res['message']}',
                  );
                  if (res['success']) _loadDados();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // 2. RETIRAR MEMBRO
  Future<void> _retirarMembro(int equipeId, int membroId) async {
    final res = await _apiService.retirarMembro(
      equipeId: equipeId,
      membroId: membroId,
    );
    if (!mounted) return;
    _showSnackBar(res['success'] ? 'Retirado!' : 'Erro: ${res['message']}');
    if (res['success']) _loadDados();
  }

  // 3. EDITAR EQUIPE
  /* Future<void> _editarEquipe(int equipeId, String nomeAtual) async {
    final nomeCtrl = TextEditingController(text: nomeAtual);
    final disponiveis = await _apiService.buscarFuncionariosDisponiveis();
    if (!mounted) return;

    final selecionados = <int>[];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Equipe'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 16),
              const Text('Adicionar membros:'),
              Expanded(
                child: ListView.builder(
                  itemCount: disponiveis.length,
                  itemBuilder: (_, i) {
                    final f = disponiveis[i];
                    return CheckboxListTile(
                      title: Text(f['nome']),
                      value: selecionados.contains(f['id']),
                      onChanged: (v) {
                        if (v == true) {
                          selecionados.add(f['id']);
                        } else {
                          selecionados.remove(f['id']);
                        }
                        (ctx as Element).markNeedsBuild();
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
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _apiService.editarEquipe(
                equipeId: equipeId,
                novoNome: nomeCtrl.text,
                novosMembrosIds: selecionados,
              );
              if (!mounted) return;
              _showSnackBar(
                res['success'] ? 'Editado!' : 'Erro: ${res['message']}',
              );
              if (res['success']) _loadDados();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
*/

  Future<void> _editarEquipe(int equipeId, String nomeAtual) async {
    final nomeCtrl = TextEditingController(text: nomeAtual);
    final disponiveis = await _apiService.buscarFuncionariosDisponiveis();
    if (!mounted) return;

    final selecionados = <int>{}; // Usar Set para evitar duplicatas

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
                'Adicionar novos membros:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: disponiveis.isEmpty
                    ? const Center(child: Text('Nenhum funcionário disponível'))
                    : ListView.builder(
                        itemCount: disponiveis.length,
                        itemBuilder: (_, i) {
                          final f = disponiveis[i];
                          return CheckboxListTile(
                            title: Text(f['nome']),
                            value: selecionados.contains(f['id']),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  selecionados.add(f['id']);
                                } else {
                                  selecionados.remove(f['id']);
                                }
                              });
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
              Navigator.pop(ctx);
              final res = await _apiService.editarEquipe(
                equipeId: equipeId,
                novoNome: nomeCtrl.text.trim(),
                novosMembrosIds: selecionados.toList(),
              );
              if (!mounted) return;
              _showSnackBar(
                res['success']
                    ? 'Equipe atualizada!'
                    : 'Erro: ${res['message']}',
              );
              if (res['success']) await _loadDados();
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

 /* Future<void> _salvaAlteracoesEquipe(int equipeId) async {
    final removendo = _membrosParaRemover[equipeId] ?? {};
    if (removendo.isEmpty) return;

    setState(() => _isLoading = true);

    for (final membroId in removendo) {
      final res = await _apiService.retirarMembro(
        equipeId: equipeId,
        membroId: membroId,
      );
      if (!res['success']) {
        _showSnackBar('Erro ao remover: ${res['message']}');
        setState(() => _isLoading = false);
        return;
      }
    }

    // Limpa alterações
    _membrosParaRemover.remove(equipeId);
    _temAlteracoes = false;

    await _loadDados(); // Recarrega
    _showSnackBar('Alterações salvas!');
  }*/

Future<void> _salvaAlteracoesEquipe(int equipeId) async {
  final removendo = Set<int>.from(_membrosParaRemover[equipeId] ?? {});
  if (removendo.isEmpty) return;

  setState(() => _isLoading = true);

  bool tudoOk = true;
  for (final membroId in removendo) {
    final res = await _apiService.retirarMembro(
      equipeId: equipeId,
      membroId: membroId,
    );
    if (!res['success']) {
      tudoOk = false;
      _showSnackBar('Erro ao remover: ${res['message']}');
      break;
    }
  }

  if (tudoOk) {
    _membrosParaRemover.remove(equipeId);
    _temAlteracoes = false;
    await _loadDados();
    _showSnackBar('Alterações salvas com sucesso!');
  }

  setState(() => _isLoading = false);
}


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Minhas Equipes')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Equipes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            ..._equipes.map((e) => Tab(text: e['nome'] ?? 'Sem nome')),
            const Tab(icon: Icon(Icons.add)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [..._equipes.map(_buildEquipeTab), _buildNovaEquipeTab()],
      ),
    );
  }

  Widget _buildEquipeTab(Map<String, dynamic> equipe) {
    final membros = List<Map<String, dynamic>>.from(equipe['membros'] ?? []);
    final equipeId = equipe['id'];
    final removendo = _membrosParaRemover[equipeId] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              equipe['nome'] ?? 'Sem nome',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editarEquipe(equipe['id'], equipe['nome']),
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
            final estaRemovendo = removendo.contains(m['id']);
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(m['nome']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /*Switch(
                    value: true,
                    onChanged: (_) => _retirarMembro(equipe['id'], m['id']),
                  ),*/
                  /* Switch(
                    value: !estaRemovendo,
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          removendo.remove(m['id']);
                        } else {
                          removendo.add(m['id']);
                        }
                        _temAlteracoes = _membrosParaRemover.values.any(
                          (s) => s.isNotEmpty,
                        );
                      });
                    },
                  ),*/
                  Switch(
                    value: !removendo.contains(m['id']),
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          removendo.remove(m['id']);
                        } else {
                          removendo.add(m['id']);
                        }
                        _temAlteracoes = _membrosParaRemover.values.any(
                          (s) => s.isNotEmpty,
                        );
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: estaRemovendo
                        ? null
                        : () => _moverMembro(equipe['id'], m['id'], m['nome']),
                  ),
                ],
              ),
            );
          }),

        //BOTAO SALVAR
        /*  if (_temAlteracoes && _membrosParaRemover.containsKey(equipeId))
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton(
              onPressed: () => _salvaAlteracoesEquipe(equipeId),
              child: const Text('SALVAR MODIFICAÇÕES'),
            ),
          ),*/
        if (_membrosParaRemover.containsKey(equipeId) && removendo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _salvaAlteracoesEquipe(equipeId),
              child: const Text('SALVAR MODIFICAÇÕES'),
            ),
          ),
      ],
    );
  }

  Widget _buildNovaEquipeTab() {
    return Center(
      child: ElevatedButton(
        onPressed: _navigateToMontarEquipe,
        child: const Text('Criar Nova Equipe'),
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
