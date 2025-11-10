// lib/screens/lancamento_individual_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../models/acao_model.dart';
import '../models/produto_model.dart';
import 'package:intl/intl.dart'; // Necessário para formatar a hora

// Modelo simples para os membros retornados pela API (ID e Nome)
class MembroSimples {
  final int id;
  final String nome;

  MembroSimples({required this.id, required this.nome});

  factory MembroSimples.fromJson(Map<String, dynamic> json) {
    return MembroSimples(id: json['id'] as int, nome: json['nome'] as String);
  }
}

class LancamentoIndividualScreen extends StatefulWidget {
  const LancamentoIndividualScreen({super.key});

  @override
  State<LancamentoIndividualScreen> createState() =>
      _LancamentoIndividualScreenState();
}

class _LancamentoIndividualScreenState
    extends State<LancamentoIndividualScreen> {
  late ApiService _apiService;

  // Variáveis de Estado
  bool _isLoading = true;
  int? _equipeId;
  List<MembroSimples> _membros = [];
  List<AcaoModel> _acoes = [];
  List<ProdutoModel> _produtos = [];

  // Variáveis do Formulário
  MembroSimples? _membroSelecionado;
  AcaoModel? _acaoSelecionada;
  ProdutoModel? _produtoSelecionado;
  final TextEditingController _loteController = TextEditingController();
  final TextEditingController _quantidadeController = TextEditingController();
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _apiService = ApiService(authProvider);

    if (_membros.isEmpty) {
      _loadOpcoes();
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

  // Função de carregamento das opções
  void _loadOpcoes() async {
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.getLancamentoOpcoes(); //

    if (result['success']) {
      setState(() {
        _equipeId = result['equipe_id'];

        // Mapeamento dos Membros (Retornam como lista de Map<String, dynamic>)
        _membros = (result['membros'] as List)
            .map((json) => MembroSimples.fromJson(json))
            .toList();

        _acoes = result['acoes'] as List<AcaoModel>;
        _produtos = result['produtos'] as List<ProdutoModel>;

        // Pre-selecionar o primeiro item, se houver
        _membroSelecionado = _membros.isNotEmpty ? _membros.first : null;
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
    // Para simplificar, usamos a data atual apenas para formatar o tempo
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    // Formato de hora exigido pela API (ex: 14:30:00)
    return DateFormat('HH:mm:ss').format(dt);
  }

  // Função de validação e salvamento
  void _salvarLancamento() async {
    // 1. Coletar e Validar Seleções
    if (_membroSelecionado == null ||
        _acaoSelecionada == null ||
        _produtoSelecionado == null ||
        _horaInicio == null ||
        _horaFim == null) {
      _showSnackBar(
        'Selecione o Membro, Ação, Produto e os Horários.',
        isError: true,
      );
      return;
    }

    // 2. Coletar e Validar Quantidade
    final quantidadeKgText = _quantidadeController.text.trim().replaceAll(
      ',',
      '.',
    );
    final double? quantidadeKg = double.tryParse(quantidadeKgText);

    if (quantidadeKg == null || quantidadeKg <= 0) {
      _showSnackBar(
        'Informe uma Quantidade válida (maior que zero).',
        isError: true,
      );
      return;
    }

    // 3. Validação Condicional do Lote (Baseado no Produto)
    final lote = _loteController.text.trim();
    if (_produtoSelecionado!.usaLote && lote.isEmpty) {
      _showSnackBar(
        'O Lote do Produto é obrigatório para este item.',
        isError: true,
      );
      return;
    }

    // 4. Formatar Horas (necessário para a API PHP)
    final String horaInicioFormatada = _formatTime(_horaInicio!);
    final String horaFimFormatada = _formatTime(_horaFim!);

    // 5. Iniciar Loading e Chamada da API
    setState(() {
      _isLoading = true;
    });

    final result = await _apiService.salvarLancamentoIndividual(
      //
      funcionarioId: _membroSelecionado!.id,
      acaoId: _acaoSelecionada!.id,
      produtoId: _produtoSelecionado!.id,
      lote: lote,
      quantidadeKg: quantidadeKg,
      horaInicio: horaInicioFormatada,
      horaFim: horaFimFormatada,
    );

    // 6. Finalizar Loading e Tratar Resposta
    setState(() {
      _isLoading = false;
    });

    // 1. Checagem de 'mounted' antes de usar BuildContext para navegação
    if (!mounted) return;

    if (result['success']) {
      _showSnackBar(
        result['message'] ?? 'Lançamento salvo com sucesso!',
        isError: false,
      );
      // Sucesso: Retorna para a tela principal
      Navigator.of(context).pop(); // Citação de BuildContext síncrona
    } else {
      _showSnackBar(
        result['message'] ?? 'Falha ao salvar o lançamento.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamento Individual')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_membros.isEmpty
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
                        Text(
                          'Equipe ID: ${_equipeId ?? 'N/A'}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Divider(),

                        // 1. Membro da Equipe (Dropdown)
                        DropdownButtonFormField<MembroSimples>(
                          decoration: const InputDecoration(
                            labelText: 'Membro da Equipe',
                            border: OutlineInputBorder(),
                          ),
                          value: _membroSelecionado,
                          items: _membros.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(m.nome),
                            );
                          }).toList(),
                          onChanged: (MembroSimples? newValue) {
                            setState(() {
                              _membroSelecionado = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // 2. Ação (Dropdown)
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

                        // 3. Tipo de Produto (Dropdown)
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
                            // Revalida a exibição do campo Lote
                            _loteController.clear();
                          },
                        ),
                        const SizedBox(height: 20),

                        // 4. Lote do Produto (Condicional)
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

                        // 5. Quantidade (em KG)
                        TextField(
                          controller: _quantidadeController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Quantidade (em KG)',
                            border: OutlineInputBorder(),
                            suffixText: 'kg',
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 6. Horas (Início e Fim)
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
                        const SizedBox(height: 40),

                        // Botão Salvar
                        ElevatedButton.icon(
                          onPressed: _salvarLancamento,
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'Salvar Lançamento',
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

  // Widget auxiliar para os seletores de tempo
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
