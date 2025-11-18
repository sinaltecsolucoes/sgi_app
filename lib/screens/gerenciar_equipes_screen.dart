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

  // equipeId -> Set de membros marcados para remoção
  final Map<int, Set<int>> _membrosParaRemover = {};

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
      await _loadDados();
    }
  }

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
        _membrosParaRemover.clear();

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
  }

  // MOVER MEMBRO
  Future<void> _moverMembro(
    int equipeOrigemId,
    int membroId,
    String nomeMembro,
  ) async {
    final todasEquipes = await _apiService.buscarTodasEquipesAtivas();
    if (!mounted) return;

    if (todasEquipes.isEmpty) {
      _showSnackBar('Nenhuma equipe disponível hoje.');
      return;
    }

    int? equipeDestinoId;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mover: $nomeMembro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('De:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              _equipes.firstWhere(
                (e) => e['id'] == equipeOrigemId,
                orElse: () => {'nome': 'Equipe atual'},
              )['nome'],
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Para:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                hint: const Text('-- Selecione a Equipe de Destino --'),
                initialValue:
                    equipeDestinoId, // ← corrigido (value estava deprecated)
                items: todasEquipes.map<DropdownMenuItem<int>>((e) {
                  final nomeEquipe = e['nome'] ?? 'Sem nome';
                  final nomeApontador = e['apontador_nome'] ?? 'Desconhecido';
                  final id = e['id'] as int;

                  return DropdownMenuItem<int>(
                    value: id,
                    enabled: id != equipeOrigemId,
                    child: Text(
                      '$nomeEquipe ($nomeApontador)',
                      style: TextStyle(
                        color: id == equipeOrigemId ? Colors.grey : null,
                        fontStyle: id == equipeOrigemId
                            ? FontStyle.italic
                            : null,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  equipeDestinoId = value;
                  (ctx as Element).markNeedsBuild(); // rebuild do dialog
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Mover'),
            onPressed: equipeDestinoId == null
                ? null
                : () async {
                    Navigator.pop(ctx);
                    final res = await _apiService.moverMembro(
                      membroId: membroId,
                      equipeOrigemId: equipeOrigemId,
                      equipeDestinoId: equipeDestinoId!,
                    );
                    if (!mounted) return;
                    _showSnackBar(
                      res['success']
                          ? 'Membro movido com sucesso!'
                          : 'Erro: ${res['message']}',
                    );
                    if (res['success']) await _loadDados();
                  },
          ),
        ],
      ),
    );
  }

  // REMOVER MEMBRO
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
      await _loadDados();
      _showSnackBar('Membros removidos com sucesso!');
    }

    setState(() => _isLoading = false);
  }

  // EDITAR EQUIPE – MOSTRA SÓ DISPONÍVEIS (presentes + não alocados)
  Future<void> _editarEquipe(int equipeId, String nomeAtual) async {
    final nomeCtrl = TextEditingController(text: nomeAtual);
    final disponiveis = await _apiService.buscarFuncionariosDisponiveis();
    if (!mounted) return;

    final Set<int> selecionados = <int>{};

    // Variável para forçar rebuild do dialog
    void rebuild() => setState(() {});

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        // ← ESSA É A MÁGICA
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Editar Equipe'),
            content: SizedBox(
              width: double.maxFinite,
              height: 520,
              child: Column(
                children: [
                  TextField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome da equipe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Adicionar membros disponíveis:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: disponiveis.isEmpty
                        ? const Center(
                            child: Text('Nenhum funcionário disponível hoje'),
                          )
                        : ListView.builder(
                            itemCount: disponiveis.length,
                            itemBuilder: (_, i) {
                              final f = disponiveis[i];
                              final id = f['id'] as int;
                              final nome = f['nome'] as String;

                              return CheckboxListTile(
                                title: Text(nome),
                                value: selecionados.contains(id),
                                onChanged: (bool? v) {
                                  setStateDialog(() {
                                    // ← usa o setState do dialog
                                    if (v == true) {
                                      selecionados.add(id);
                                    } else {
                                      selecionados.remove(id);
                                    }
                                  });
                                  rebuild(); // opcional: atualiza o botão "Salvar" se quiser
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
                onPressed:
                    selecionados.isEmpty && nomeCtrl.text.trim() == nomeAtual
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final res = await _apiService.editarEquipe(
                          equipeId: equipeId,
                          novoNome: nomeCtrl.text.trim().isEmpty
                              ? nomeAtual
                              : nomeCtrl.text.trim(),
                          novosMembrosIds: selecionados.toList(),
                        );
                        if (!mounted) return;
                        _showSnackBar(
                          res['success']
                              ? 'Equipe atualizada com sucesso!'
                              : 'Erro: ${res['message']}',
                        );
                        if (res['success']) await _loadDados();
                      },
                child: const Text('Salvar Alterações'),
              ),
            ],
          );
        },
      ),
    );
  }

  // EXCLUIR EQUIPE
  Future<void> _excluirEquipe(int equipeId, String nomeEquipe) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Equipe'),
        content: Text(
          'Tem certeza que deseja excluir a equipe "$nomeEquipe"?\nEsta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );

    if (confirmou != true) return;

    setState(() => _isLoading = true);
    final res = await _apiService.excluirEquipe(equipeId: equipeId);
    setState(() => _isLoading = false);

    _showSnackBar(
      res['success'] ? 'Equipe excluída!' : 'Erro: ${res['message']}',
    );
    if (res['success']) await _loadDados();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue[700]),
    );
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
    final equipeId = equipe['id'] as int;
    final Set<int> removendo = _membrosParaRemover[equipeId] ??= <int>{};

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
            Row(
              children: [
                // BOTÃO EDITAR
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      _editarEquipe(equipe['id'] as int, equipe['nome']),
                ),
                // BOTÃO EXCLUIR (novo!)
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Excluir equipe',
                  onPressed: () =>
                      _excluirEquipe(equipe['id'] as int, equipe['nome']),
                ),
              ],
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
            final estaMarcadoParaRemover = removendo.contains(m['id']);
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(m['nome']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: !estaMarcadoParaRemover,
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          removendo.remove(m['id']);
                        } else {
                          removendo.add(m['id']);
                        }
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                    onPressed: estaMarcadoParaRemover
                        ? null
                        : () => _moverMembro(equipeId, m['id'], m['nome']),
                  ),
                ],
              ),
            );
          }),

        // BOTÃO REMOVER MARCADOS
        if (removendo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              label: const Text(
                'REMOVER MARCADOS DA EQUIPE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _salvaAlteracoesEquipe(equipeId),
            ),
          ),
      ],
    );
  }

  Widget _buildNovaEquipeTab() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: _navigateToMontarEquipe,
        icon: const Icon(Icons.add),
        label: const Text('Criar Nova Equipe', style: TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
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
