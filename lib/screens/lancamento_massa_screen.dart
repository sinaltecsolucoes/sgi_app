// lib/screens/lancamento_massa_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/acao_model.dart';
import '../models/produto_model.dart';

// NOVO Modelo para os membros da equipe, incluindo o controlador da quantidade
class MembroProducao {
  final int id;
  final String nome;
  // Adiciona um controlador para o campo de produção individual
  final TextEditingController quantidadeController;

  MembroProducao({required this.id, required this.nome})
    : quantidadeController =
          TextEditingController(); // Inicializa o controlador

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

  // Variáveis de Estado
  bool _isLoading = true;
  int? _equipeId;
  // Lista com os membros e seus respectivos controladores de quantidade
  List<MembroProducao> _membrosProducao = [];
  List<AcaoModel> _acoes = [];
  List<ProdutoModel> _produtos = [];

  // Variáveis do Formulário (Cabeçalho Comum)
  AcaoModel? _acaoSelecionada;
  ProdutoModel? _produtoSelecionado;
  final TextEditingController _loteController = TextEditingController();
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(authProvider);

    if (_membrosProducao.isEmpty) {
      _loadOpcoes();
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Função de carregamento das opções (Reutiliza a lógica do Individual)
  void _loadOpcoes() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.getLancamentoOpcoes();

    if (result['success']) {
      setState(() {
        _equipeId = result['equipe_id'];

        // Mapeamento dos Membros: Converte para MembroProducao (com controlador)
        _membrosProducao = (result['membros'] as List)
            .map((json) => MembroProducao.fromJson(json))
            .toList();

        _acoes = result['acoes'] as List<AcaoModel>;
        _produtos = result['produtos'] as List<ProdutoModel>;

        // Pre-selecionar o primeiro item, se houver
        _acaoSelecionada = _acoes.isNotEmpty ? _acoes.first : null;
        _produtoSelecionado = _produtos.isNotEmpty ? _produtos.first : null;
      });
    } else {
      _showSnackBar(
        result['message'] ?? 'Erro ao carregar opções de lançamento.',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Função para abrir o seletor de tempo
  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _horaInicio = picked;
        } else {
          _horaFim = picked;
        }
      });
    }
  }

  // Formata o TimeOfDay para string HH:MM:SS (padrão da API)
  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    // Note: Necessário adicionar o pacote 'intl' ao pubspec.yaml
    return DateFormat('HH:mm:ss').format(dt);
  }

  // Lógica de salvamento em loop na próxima etapa
  void _salvarLancamentoMassa() async {
    // 1. Validação do Cabeçalho
    if (_acaoSelecionada == null ||
        _produtoSelecionado == null ||
        _horaInicio == null ||
        _horaFim == null) {
      _showSnackBar(
        'Preencha Ação, Produto e Horários no cabeçalho.',
        isError: true,
      );
      return;
    }

    // 2. Validação Condicional do Lote
    final lote = _loteController.text.trim();
    if (_produtoSelecionado!.usaLote && lote.isEmpty) {
      _showSnackBar(
        'O Lote do Produto é obrigatório para este item.',
        isError: true,
      );
      return;
    }

    // 3. Formatar Horas
    final String horaInicioFormatada = _formatTime(_horaInicio!);
    final String horaFimFormatada = _formatTime(_horaFim!);

    // 4. Identificar Lançamentos Válidos e Validar Quantidade
    final List<Map<String, dynamic>> lancamentosValidos = [];
    int totalLancamentosTentados = 0;

    for (var membro in _membrosProducao) {
      final quantidadeKgText = membro.quantidadeController.text
          .trim()
          .replaceAll(',', '.');
      final double? quantidadeKg = double.tryParse(quantidadeKgText);

      // Consideramos apenas lançamentos com quantidade válida > 0
      if (quantidadeKg != null && quantidadeKg > 0) {
        totalLancamentosTentados++;
        lancamentosValidos.add({
          'funcionarioId': membro.id,
          'quantidadeKg': quantidadeKg,
        });
      }
    }

    if (lancamentosValidos.isEmpty) {
      _showSnackBar(
        'Preencha a produção (KG > 0) para ao menos um membro.',
        isError: true,
      );
      return;
    }

    // 5. Iniciar Loading e Execução do Loop de Salvamento
    setState(() {
      _isLoading = true;
    });

    int sucessos = 0;
    int falhas = 0;

    // Utilizamos Future.wait com um Future.forEach para processar sequencialmente (mais seguro)
    // ou simplesmente um loop for/await
    for (var lancamento in lancamentosValidos) {
      final result = await _apiService.salvarLancamentoIndividual(
        // Reutiliza a função individual
        funcionarioId: lancamento['funcionarioId'],
        acaoId: _acaoSelecionada!.id,
        produtoId: _produtoSelecionado!.id,
        lote: lote,
        quantidadeKg: lancamento['quantidadeKg'],
        horaInicio: horaInicioFormatada,
        horaFim: horaFimFormatada,
      );

      if (result['success']) {
        sucessos++;
      } else {
        falhas++;
        // Opcional: registrar a falha no console ou em um log
        // print('Falha ao salvar para ID ${lancamento['funcionarioId']}: ${result['message']}');
      }
    }

    // 6. Finalizar Loading e Relatar Resultado
    setState(() {
      _isLoading = false;
    });

    if (sucessos > 0) {
      _showSnackBar(
        'Salvo $sucessos lançamentos. Falhas: $falhas.',
        isError: falhas > 0,
      );
      // Sucesso: Retorna para a tela principal
      Navigator.of(context).pop();
    } else {
      _showSnackBar(
        'Nenhum lançamento foi salvo. Verifique a conexão e as quantidades.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamento em Massa (Distribuição)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_membrosProducao.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum membro na equipe. Monte a equipe antes de lançar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cabeçalho
                        Text(
                          'Equipe ID: ${_equipeId ?? 'N/A'}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Divider(),

                        // 1. Ação (Dropdown)
                        DropdownButtonFormField<AcaoModel>(
                          decoration: const InputDecoration(
                            labelText: 'Ação / Serviço',
                            border: OutlineInputBorder(),
                          ),
                          value: _acaoSelecionada,
                          items: _acoes.map((a) {
                            return DropdownMenuItem(
                              value: a,
                              child: Text(a.nome),
                            );
                          }).toList(),
                          onChanged: (AcaoModel? newValue) {
                            setState(() {
                              _acaoSelecionada = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // 2. Tipo de Produto (Dropdown)
                        DropdownButtonFormField<ProdutoModel>(
                          decoration: const InputDecoration(
                            labelText: 'Tipo de Produto / Material',
                            border: OutlineInputBorder(),
                          ),
                          value: _produtoSelecionado,
                          items: _produtos.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                '${p.nome} ${p.usaLote ? '(Lote Sim)' : '(Lote Não)'}',
                              ),
                            );
                          }).toList(),
                          onChanged: (ProdutoModel? newValue) {
                            setState(() {
                              _produtoSelecionado = newValue;
                            });
                            _loteController.clear();
                          },
                        ),
                        const SizedBox(height: 20),

                        // 3. Lote do Produto (Condicional)
                        if (_produtoSelecionado?.usaLote == true)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: TextField(
                              controller: _loteController,
                              decoration: const InputDecoration(
                                labelText: 'Lote do Produto (Obrigatório)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),

                        // 4. Horas (Início e Fim)
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimePicker(
                                label: 'Hora Início',
                                time: _horaInicio,
                                onPressed: () => _selectTime(true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTimePicker(
                                label: 'Hora Fim',
                                time: _horaFim,
                                onPressed: () => _selectTime(false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),

                        // --- LISTA DE DISTRIBUIÇÃO ---
                        Text(
                          'Produção Individual (em KG):',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),

                        // Lista de Membros com campo de quantidade ao lado
                        ..._membrosProducao.map((membro) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    membro.nome,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: membro
                                        .quantidadeController, // Usa o controlador do objeto
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                      labelText: 'KG',
                                      border: OutlineInputBorder(),
                                      isDense: true, // Torna o campo menor
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 40),

                        // Botão Salvar
                        ElevatedButton.icon(
                          onPressed: _salvarLancamentoMassa,
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'Salvar Lançamentos',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  )),
    );
  }

  // Widget auxiliar para os seletores de tempo (reutilizado)
  Widget _buildTimePicker({
    required String label,
    TimeOfDay? time,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          time == null ? 'Selecionar Hora' : time.format(context),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
