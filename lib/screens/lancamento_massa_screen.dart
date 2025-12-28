// lib/screens/lancamento_massa_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MembroProducao {
  final int id;
  final String nome;
  final TextEditingController quantidadeController = TextEditingController();

  MembroProducao({required this.id, required this.nome});
  factory MembroProducao.fromJson(Map<String, dynamic> json) {
    return MembroProducao(id: json['id'] as int, nome: json['nome'] as String);
  }
}

class LancamentoMassaScreen extends StatefulWidget {
  const LancamentoMassaScreen({super.key});
  @override
  State<LancamentoMassaScreen> createState() => _LancamentoMassaScreenState();
}

class _LancamentoMassaScreenState extends State<LancamentoMassaScreen> {
  late ApiService _apiService;
  bool _isLoading = true;

  // Dados principais
  List<Map<String, dynamic>> _equipes = [];
  Map<String, dynamic>? _equipeSelecionada;
  List<MembroProducao> _membros = [];

  List<Map<String, dynamic>> _acoes = [];
  List<Map<String, dynamic>> _produtos = [];

  Map<String, dynamic>? _acaoSelecionada;
  Map<String, dynamic>? _produtoSelecionado;
  bool _produtoUsaLote = false;

  final TextEditingController _loteController = TextEditingController();
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _apiService = ApiService(Provider.of<AuthProvider>(context, listen: false));
    _loadOpcoes();
    _syncPending();
  }

  Future<void> _loadOpcoes() async {
    setState(() => _isLoading = true);
    final result = await _apiService.getLancamentoOpcoesCompleto();

    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _equipes = List<Map<String, dynamic>>.from(result['equipes']);
        _acoes = List<Map<String, dynamic>>.from(result['acoes']);
        _produtos = List<Map<String, dynamic>>.from(result['produtos']);

        if (_equipes.isNotEmpty) {
          _equipeSelecionada = _equipes.first;
          _carregarMembrosDaEquipe();
        }
        if (_acoes.isNotEmpty) _acaoSelecionada = _acoes.first;
        if (_produtos.isNotEmpty) _produtoSelecionado = _produtos.first;
      });
    } else {
      _showSnackBar(
        result['message'] ?? 'Erro ao carregar dados',
        isError: true,
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _carregarMembrosDaEquipe() async {
    if (_equipeSelecionada == null) return;
    setState(() => _isLoading = true);

    final result = await _apiService.getMembrosEquipe(
      _equipeSelecionada!['id'],
    );
    if (!mounted) return;

    if (result['success']) {
      setState(() {
        _membros = (result['membros'] as List)
            .map((j) => MembroProducao.fromJson(j))
            .toList();
      });
    }
    setState(() => _isLoading = false);
  }

  void _onProdutoChanged(Map<String, dynamic>? produto) {
    setState(() {
      _produtoSelecionado = produto;
      _produtoUsaLote = produto?['usa_lote'] == 1;
      if (!_produtoUsaLote) _loteController.clear();
    });
  }

  // === OFFLINE-FIRST (igual antes) ===
  Future<bool> _isOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.vpn);
  }

  Future<void> _salvarLocalmente(Map<String, dynamic> dados) async {
    final prefs = await SharedPreferences.getInstance();
    final pendentes = prefs.getStringList('lancamentos_pendentes') ?? [];
    pendentes.add(jsonEncode(dados));
    await prefs.setStringList('lancamentos_pendentes', pendentes);
  }

  Future<void> _syncPending() async {
    final prefs = await SharedPreferences.getInstance();
    final pendentes = prefs.getStringList('lancamentos_pendentes') ?? [];
    if (pendentes.isEmpty || !await _isOnline()) return;

    final restantes = <String>[];
    for (String item in pendentes) {
      final dados = jsonDecode(item) as Map<String, dynamic>;
      final lancamentos = List<Map<String, dynamic>>.from(dados['lancamentos']);
      final res = await _apiService.salvarLancamentoMassa(lancamentos);
      if (!res['success']) restantes.add(item);
    }
    await prefs.setStringList('lancamentos_pendentes', restantes);
    if (restantes.isEmpty && mounted) {
      _showSnackBar('Lançamentos offline sincronizados!');
    }
  }

  /*  Future<void> _salvarLancamentoMassa() async {
    // Validações...
    if (_equipeSelecionada == null ||
        _acaoSelecionada == null ||
        _produtoSelecionado == null) {
      _showSnackBar('Preencha todos os campos obrigatórios', isError: true);
      return;
    }

    final lancamentos = <Map<String, dynamic>>[];
    for (var m in _membros) {
      final qtd =
          double.tryParse(m.quantidadeController.text.replaceAll(',', '.')) ??
          0;
      if (qtd > 0) {
        lancamentos.add({
          'funcionario_id': m.id,
          'funcionario_nome': m.nome,
          'acao_id': _acaoSelecionada!['id'],
          'acao': _acaoSelecionada!['nome'],
          'produto_id': _produtoSelecionado!['id'],
          'produto': _produtoSelecionado!['nome'],
          'quantidade': qtd,
          if (_produtoUsaLote && _loteController.text.trim().isNotEmpty)
            'lote': _loteController.text.trim(),
          if (_horaInicio != null) 'hora_inicio': _formatTime(_horaInicio!),
          if (_horaFim != null) 'hora_fim': _formatTime(_horaFim!),
        });
      }
    }

    if (lancamentos.isEmpty) {
      _showSnackBar('Informe pelo menos uma produção', isError: true);
      return;
    }

    final dados = {
      'equipe_id': _equipeSelecionada!['id'],
      'lancamentos': lancamentos,
    };

    final online = await _isOnline();
    if (online) {
      final res = await _apiService.salvarLancamentoMassa(lancamentos);
      if (res['success'] == true) {
        if (!mounted) return;
        _showSnackBar('Lançamento salvo com sucesso!');
        Navigator.pop(context);
        return;
      }
    }

    await _salvarLocalmente(dados);
    if (!mounted) return;
    _showSnackBar(
      online
          ? 'Erro no servidor. Salvo offline.'
          : 'Sem internet. Salvo offline e será sincronizado.',
    );
  }
*/

  Future<void> _salvarLancamentoMassa() async {
    // 1. BLOQUEIO DE INTERFACE: Impede cliques duplos imediatamente
    setState(() => _isLoading = true);

    try {
      // Validações básicas
      if (_equipeSelecionada == null ||
          _acaoSelecionada == null ||
          _produtoSelecionado == null) {
        _showSnackBar('Preencha todos os campos obrigatórios', isError: true);
        return;
      }

      // 2. GERAÇÃO DE ID ÚNICO: Identifica esta transação específica
      final String loteId = const Uuid().v4();
      final String dataHoraCriacao = DateTime.now().toIso8601String();

      final lancamentos = <Map<String, dynamic>>[];
      for (var m in _membros) {
        final qtd =
            double.tryParse(m.quantidadeController.text.replaceAll(',', '.')) ??
            0;
        if (qtd > 0) {
          lancamentos.add({
            'uuid_transacao':
                loteId, // ID único para o backend checar duplicidade
            'funcionario_id': m.id,
            'funcionario_nome': m.nome,
            'acao_id': _acaoSelecionada!['id'],
            'acao': _acaoSelecionada!['nome'],
            'produto_id': _produtoSelecionado!['id'],
            'produto': _produtoSelecionado!['nome'],
            'quantidade': qtd,
            if (_produtoUsaLote && _loteController.text.trim().isNotEmpty)
              'lote': _loteController.text.trim(),
            if (_horaInicio != null) 'hora_inicio': _formatTime(_horaInicio!),
            if (_horaFim != null) 'hora_fim': _formatTime(_horaFim!),
          });
        }
      }

      if (lancamentos.isEmpty) {
        _showSnackBar('Informe pelo menos uma produção', isError: true);
        return;
      }

      // Estrutura completa para salvar localmente ou enviar
      final dadosParaEnvio = {
        'lote_id': loteId,
        'data_criacao': dataHoraCriacao,
        'equipe_id': _equipeSelecionada!['id'],
        'lancamentos': lancamentos,
        'tentativas': 0,
      };

      final online = await _isOnline();

      if (online) {
        // Tentativa de envio ao servidor
        final res = await _apiService.salvarLancamentoMassa(lancamentos);

        if (res['success'] == true) {
          if (!mounted) return;
          _showSnackBar('Lançamento enviado com sucesso!');
          Navigator.pop(
            context,
            true,
          ); // Retorna true para atualizar telas anteriores
          return;
        }
      }

      // 3. FALLBACK: Se estiver offline OU se o servidor falhar
      await _salvarLocalmente(dadosParaEnvio);

      if (!mounted) return;
      _showSnackBar(
        online
            ? 'Erro no servidor. Salvo para sincronização posterior.'
            : 'Sem internet. Salvo offline.',
        isError: !online,
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Erro inesperado: $e', isError: true);
    } finally {
      // 4. LIBERAÇÃO DA INTERFACE: Garante que o loading pare mesmo em caso de erro
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  void _showSnackBar(String msg, {bool isError = false}) {
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
      appBar: AppBar(title: const Text('Lançamentos Produção')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Seleção de Equipe
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownSearch<Map<String, dynamic>>(
                        popupProps: const PopupProps.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: "Buscar equipe...",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        items: _equipes,
                        itemAsString: (item) => item['nome'],
                        selectedItem: _equipeSelecionada,
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Equipe *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        onChanged: (eq) {
                          setState(() {
                            _equipeSelecionada = eq;
                            _carregarMembrosDaEquipe();
                          });
                        },
                      ),
                    ),

                    // 2. Ação
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownSearch<Map<String, dynamic>>(
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        items: _acoes,
                        itemAsString: (item) => item['nome'],
                        selectedItem: _acaoSelecionada,
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Ação *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        onChanged: (v) => setState(() => _acaoSelecionada = v),
                      ),
                    ),
                    // 3. Produto
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownSearch<Map<String, dynamic>>(
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        items: _produtos,
                        itemAsString: (item) => item['nome'],
                        selectedItem: _produtoSelecionado,
                        dropdownDecoratorProps: const DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Produto *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        onChanged: _onProdutoChanged,
                      ),
                    ),

                    // 4. Lote (condicional)
                    if (_produtoUsaLote)
                      TextField(
                        controller: _loteController,
                        decoration: const InputDecoration(
                          labelText: 'Lote *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    if (_produtoUsaLote) const SizedBox(height: 16),

                    // 5. Horários
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePicker(
                            'Início',
                            _horaInicio,
                            () => _selectTime(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePicker(
                            'Fim',
                            _horaFim,
                            () => _selectTime(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Produção Individual (KG):',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),

                    // Lista de membros
                    ..._membros.map(
                      (m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(m.nome)),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: m.quantidadeController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: '0.0',
                                  suffixText: 'KG',
                                  border: OutlineInputBorder(),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _salvarLancamentoMassa,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send),
                        label: const Text(
                          'SALVAR LANÇAMENTOS',
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

  Widget _buildTimePicker(String label, TimeOfDay? time, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(time?.format(context) ?? 'Selecionar'),
      ),
    );
  }

  Future<void> _selectTime(bool inicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() => inicio ? _horaInicio = picked : _horaFim = picked);
    }
  }
}
