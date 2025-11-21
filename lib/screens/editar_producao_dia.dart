// lib/screens/editar_producao_dia.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class Lancamento {
  final int id;
  final String funcionarioNome;
  int acaoId;
  String acaoNome;
  int produtoId;
  String produtoNome;
  double quantidadeKg;
  String? lote;
  String horaInicio;
  String horaFim;

  Lancamento({
    required this.id,
    required this.funcionarioNome,
    required this.acaoId,
    required this.acaoNome,
    required this.produtoId,
    required this.produtoNome,
    required this.quantidadeKg,
    this.lote,
    required this.horaInicio,
    required this.horaFim,
  });

  String get intervalo => '$horaInicio - $horaFim';

  Map<String, dynamic> toJson() => {
    'id': id,
    'acao_id': acaoId,
    'produto_id': produtoId,
    'quantidade_kg': quantidadeKg,
    'lote_produto': lote,
    'hora_inicio': horaInicio,
    'hora_fim': horaFim,
  };
}

class EditarProducaoScreen extends StatefulWidget {
  const EditarProducaoScreen({super.key});
  @override
  State<EditarProducaoScreen> createState() => _EditarProducaoScreenState();
}

class _EditarProducaoScreenState extends State<EditarProducaoScreen> {
  late ApiService _api;
  List<Lancamento> _lancamentos = [];
  List<String> _intervalos = [];
  String? _filtroIntervalo;
  bool _carregando = true;

  List<Map<String, dynamic>> _acoes = [];
  List<Map<String, dynamic>> _produtos = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = ApiService(Provider.of<AuthProvider>(context, listen: false));
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    final opcoes = await _api.getLancamentoOpcoesCompleto();
    if (opcoes['success'] == true) {
      _acoes = List.from(opcoes['acoes']);
      _produtos = List.from(opcoes['produtos']);
    }

    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final result = await _api.getLancamentosDoDiaApontador(hoje);

    if (!mounted) return;

    if (result['success'] == true) {
      final dados = result['lancamentos'] as List? ?? [];
      final lancs = dados
          .map(
            (j) => Lancamento(
              id: j['id'] ?? 0,
              funcionarioNome: j['funcionario_nome'] ?? 'Sem nome',
              acaoId: j['acao_id'] ?? 0,
              acaoNome: j['acao_nome'] ?? '',
              produtoId: j['tipo_produto_id'] ?? 0,
              produtoNome: j['produto_nome'] ?? '',
              quantidadeKg:
                  double.tryParse(j['quantidade_kg'].toString()) ?? 0.0,
              lote: j['lote_produto'],
              horaInicio:
                  (j['hora_inicio'] as String?)?.substring(0, 5) ?? '--:--',
              horaFim: (j['hora_fim'] as String?)?.substring(0, 5) ?? '--:--',
            ),
          )
          .toList();

      final intervalos = <String>{};
      for (var l in lancs) {
        if (l.horaInicio != '--:--' && l.horaFim != '--:--') {
          intervalos.add(l.intervalo);
        }
      }

      final ordenados = intervalos.toList()..sort();

      setState(() {
        _lancamentos = lancs;
        _intervalos = ['Todos os intervalos', ...ordenados];
        _filtroIntervalo = 'Todos os intervalos';
        _carregando = false;
      });
    } else {
      setState(() => _carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Erro ao carregar')),
      );
    }
  }

  double get _totalDia => _lancamentos.fold(0.0, (s, l) => s + l.quantidadeKg);

  double get _totalIntervalo {
    if (_filtroIntervalo == null || _filtroIntervalo == 'Todos os intervalos') {
      return _totalDia;
    }
    return _lancamentos
        .where((l) => l.intervalo == _filtroIntervalo)
        .fold(0.0, (s, l) => s + l.quantidadeKg);
  }

  List<Lancamento> get _filtrados {
    if (_filtroIntervalo == null || _filtroIntervalo == 'Todos os intervalos') {
      return _lancamentos;
    }
    return _lancamentos.where((l) => l.intervalo == _filtroIntervalo).toList();
  }

  String _fmt(double v) => NumberFormat('#,##0.000', 'pt_BR').format(v);

  Future<void> _salvarLancamento(Lancamento l) async {
    final resultado = await _api.atualizarLancamentoProducao(l.toJson());

    if (!mounted) return;

    if (resultado['success'] == true) {
      // Mensagem de sucesso LINDA
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Lançamento atualizado com sucesso!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {}); // atualiza totais
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['message'] ?? 'Erro ao salvar'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar Produção - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // TOTAL DO DIA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange,
            child: Text(
              'TOTAL DO DIA: ${_fmt(_totalDia)} kg',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // FILTRO
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              initialValue: _filtroIntervalo,
              decoration: InputDecoration(
                labelText: 'Filtrar por horário',
                prefixIcon: const Icon(Icons.access_time),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _intervalos
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => setState(() => _filtroIntervalo = v),
            ),
          ),

          // TOTAL DO INTERVALO
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.orange[100],
            child: Text(
              'TOTAL DO INTERVALO: ${_fmt(_totalIntervalo)} kg',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // LISTA EDITÁVEL
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : _filtrados.isEmpty
                ? const Center(child: Text('Nenhum lançamento encontrado'))
                : ListView.builder(
                    itemCount: _filtrados.length,
                    itemBuilder: (context, i) {
                      final l = _filtrados[i];
                      final editando = ValueNotifier<bool>(false);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: editando,
                          builder: (context, isEditing, _) {
                            if (!isEditing) {
                              return ListTile(
                                title: Text(
                                  l.funcionarioNome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${l.acaoNome} • ${l.produtoNome}\n${l.intervalo}',
                                ),

                                trailing: Text(
                                  '${l.quantidadeKg.toStringAsFixed(3).replaceAll('.', ',')} kg',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),

                                onTap: () => editando.value = true,
                                isThreeLine: true,
                              );
                            }

                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.funcionarioNome,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // AÇÃO
                                  DropdownSearch<Map<String, dynamic>>(
                                    items: _acoes,
                                    itemAsString: (item) => item['nome'],
                                    selectedItem: _acoes.firstWhere(
                                      (a) => a['id'] == l.acaoId,
                                      orElse: () => _acoes[0],
                                    ),
                                    onChanged: (v) {
                                      l.acaoId = v!['id'];
                                      l.acaoNome = v['nome'];
                                    },
                                    dropdownDecoratorProps:
                                        const DropDownDecoratorProps(
                                          dropdownSearchDecoration:
                                              InputDecoration(
                                                labelText: 'Ação',
                                                border: OutlineInputBorder(),
                                              ),
                                        ),
                                  ),

                                  const SizedBox(height: 12),

                                  // PRODUTO
                                  DropdownSearch<Map<String, dynamic>>(
                                    items: _produtos,
                                    itemAsString: (item) => item['nome'],
                                    selectedItem: _produtos.firstWhere(
                                      (p) => p['id'] == l.produtoId,
                                      orElse: () => _produtos[0],
                                    ),
                                    onChanged: (v) {
                                      l.produtoId = v!['id'];
                                      l.produtoNome = v['nome'];
                                    },
                                    dropdownDecoratorProps:
                                        const DropDownDecoratorProps(
                                          dropdownSearchDecoration:
                                              InputDecoration(
                                                labelText: 'Produto',
                                                border: OutlineInputBorder(),
                                              ),
                                        ),
                                  ),

                                  const SizedBox(height: 12),

                                  // QUANTIDADE
                                  TextField(
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Quantidade (kg)',
                                      border: OutlineInputBorder(),
                                      suffixText: ' kg',
                                      hintText: 'Ex: 11,5 ou 11.5',
                                    ),
                                    controller:
                                        TextEditingController(
                                            text: l.quantidadeKg
                                                .toStringAsFixed(3),
                                          )
                                          ..selection =
                                              TextSelection.fromPosition(
                                                TextPosition(
                                                  offset: l.quantidadeKg
                                                      .toStringAsFixed(3)
                                                      .length,
                                                ),
                                              ),
                                    onChanged: (textoDigitado) {
                                      // REMOVE TUDO QUE NÃO É NÚMERO, VIRGULA OU PONTO
                                      String limpo = textoDigitado.replaceAll(
                                        RegExp(r'[^0-9,.]+'),
                                        '',
                                      );

                                      // SUBSTITUI VÍRGULA POR PONTO (padrão Dart)
                                      limpo = limpo.replaceAll(',', '.');

                                      // REMOVE PONTOS DUPLICADOS (evita 11..5)
                                      while (limpo.contains('..')) {
                                        limpo = limpo.replaceAll('..', '.');
                                      }

                                      // SE TIVER MAIS DE UM PONTO, REMOVE OS EXTRAS
                                      final partes = limpo.split('.');
                                      if (partes.length > 2) {
                                        limpo =
                                            '${partes[0]}.${partes.sublist(1).join()}';
                                      }

                                      // ATUALIZA O CAMPO VISUAL (com vírgula para o usuário)
                                      final valor =
                                          double.tryParse(limpo) ?? 0.0;
                                      l.quantidadeKg = valor;

                                      // Atualiza o texto no campo com vírgula (melhor UX)
                                      final controller = TextEditingController(
                                        text: valor
                                            .toStringAsFixed(3)
                                            .replaceAll('.', ','),
                                      );
                                      controller.selection =
                                          TextSelection.fromPosition(
                                            TextPosition(
                                              offset: controller.text.length,
                                            ),
                                          );
                                    },
                                  ),

                                  const SizedBox(height: 16),

                                  // HORÁRIOS
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Início: ${l.horaInicio}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.access_time,
                                          color: Colors.orange,
                                        ),
                                        onPressed: () async {
                                          final t = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );
                                          if (t != null) {
                                            l.horaInicio = t.format(context);
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Fim: ${l.horaFim}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.access_time,
                                          color: Colors.orange,
                                        ),
                                        onPressed: () async {
                                          final t = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.now(),
                                          );
                                          if (t != null) {
                                            l.horaFim = t.format(context);
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // BOTÕES
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => editando.value = false,
                                        child: const Text('Cancelar'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                        onPressed: () async {
                                          await _salvarLancamento(l);
                                          editando.value = false;
                                        },
                                        child: const Text(
                                          'SALVAR',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
