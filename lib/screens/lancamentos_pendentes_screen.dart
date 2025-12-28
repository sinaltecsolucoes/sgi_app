// lib/screens/lancamentos_pendentes_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class LancamentosPendentesScreen extends StatefulWidget {
  const LancamentosPendentesScreen({super.key});
  @override
  State<LancamentosPendentesScreen> createState() =>
      _LancamentosPendentesScreenState();
}

class _LancamentosPendentesScreenState
    extends State<LancamentosPendentesScreen> {
  late ApiService _apiService;
  List<Map<String, dynamic>> _pendentes = [];
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(Provider.of<AuthProvider>(context, listen: false));
    _carregarPendentes();
  }

  Future<void> _carregarPendentes() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lancamentos_pendentes') ?? [];
    setState(() {
      _pendentes = lista
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
    });
  }

  /*  Future<void> _enviarTodos() async {
    setState(() => _sincronizando = true);
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lancamentos_pendentes') ?? [];
    final restantes = <String>[];

    int enviados = 0;

    for (String item in lista) {
      final dados = jsonDecode(item) as Map<String, dynamic>;
      final lancamentos = List<Map<String, dynamic>>.from(dados['lancamentos']);
      final res = await _apiService.salvarLancamentoMassa(lancamentos);

      if (res['success'] == true) {
        enviados++;
      } else {
        restantes.add(item);
      }
    }

    await prefs.setStringList('lancamentos_pendentes', restantes);
    await _carregarPendentes();

    setState(() => _sincronizando = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sincronização concluída! $enviados enviados com sucesso.',
        ),
        backgroundColor: enviados > 0 ? Colors.green : Colors.orange,
      ),
    );

    Navigator.pop(context, true);
  }

*/

  Future<void> _enviarTodos() async {
    setState(() => _sincronizando = true);

    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lancamentos_pendentes') ?? [];

    List<String> falhas = [];
    int sucessos = 0;

    for (String itemJson in lista) {
      final Map<String, dynamic> dados = jsonDecode(itemJson);

      // Recupera o ID único que geramos no momento do salvamento
      // final String? loteId = dados['lote_id'];

      try {
        // Enviamos os lançamentos.
        // DICA: Se o seu backend for ajustado, envie o loteId junto no mapa
        final res = await _apiService.salvarLancamentoMassa(
          List<Map<String, dynamic>>.from(dados['lancamentos']),
        );

        if (res['success'] == true) {
          sucessos++;
          // Se o servidor respondeu sucesso, esse UUID foi "baixado"
        } else {
          // Se o servidor deu erro (ex: 500), mantemos na lista de falhas
          dados['motivo_falha'] = res['message'] ?? 'Erro no servidor';
          falhas.add(jsonEncode(dados));
        }
      } catch (e) {
        dados['motivo_falha'] = 'Erro de conexão: $e';
        falhas.add(jsonEncode(dados));
      }
    }

    // Atualiza o SharedPreferences apenas com o que realmente falhou
    await prefs.setStringList('lancamentos_pendentes', falhas);

    if (mounted) {
      setState(() {
        _sincronizando = false;
        _pendentes = falhas
            .map((e) => jsonDecode(e) as Map<String, dynamic>)
            .toList();
      });

      _showSnackBar(
        sucessos > 0
            ? '$sucessos lotes enviados com sucesso!'
            : 'Não foi possível sincronizar.',
        isError: sucessos == 0,
      );

      if (falhas.isEmpty) {
        Navigator.pop(context);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _excluir(int index) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento offline?'),
        content: const Text(
          'Esta ação não pode ser desfeita.\nO lançamento será apagado permanentemente.',
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

    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList('lancamentos_pendentes') ?? [];
    lista.removeAt(index);
    await prefs.setStringList('lancamentos_pendentes', lista);
    await _carregarPendentes();

    if (!mounted) return; // ← PROTEGE TUDO ABAIXO

    if (_pendentes.isEmpty) {
      Navigator.pop(context, true);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lançamento excluído (não será enviado)'),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatarDataHora() {
    return DateTime.now().toString().substring(0, 19).replaceAll('T', ' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos Offline'),
        actions: [
          if (_pendentes.isNotEmpty)
            _sincronizando
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    onPressed: _enviarTodos,
                    tooltip: 'Enviar tudo agora',
                  ),
        ],
      ),
      body: _pendentes.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum lançamento pendente',
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    'Tudo sincronizado!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _pendentes.length,
              itemBuilder: (ctx, i) {
                final item = _pendentes[i];
                final lancamentos = List<Map<String, dynamic>>.from(
                  item['lancamentos'],
                );
                final totalPessoas = lancamentos.length;
                final totalKg = lancamentos.fold(
                  0.0,
                  (s, l) => s + (l['quantidade'] ?? 0),
                );

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange[100],
                      child: const Icon(Icons.cloud_off, color: Colors.orange),
                    ),
                    title: Text('Lançamentos Produção'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalPessoas funcionários • ${totalKg.toStringAsFixed(1)} KG',
                        ),
                        Text('Salvo offline em: ${_formatarDataHora()}'),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _excluir(i),
                      tooltip: 'Excluir permanentemente',
                    ),
                    onTap: () {
                      // Mostra detalhes completos
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Detalhes do Lançamento Offline'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: lancamentos.length,
                              itemBuilder: (_, j) {
                                final l = lancamentos[j];

                                /*   return ListTile(
                                  dense: true,
                                  title: Text(
                                    l['funcionario_nome'] ??
                                        'ID ${l['funcionario_id']}',
                                  ),
                                  trailing: Text('${l['quantidade']} KG'),
                                );*/

                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    l['funcionario_nome'] ??
                                        'ID ${l['funcionario_id']}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (l['acao'] != null)
                                        Text('Ação: ${l['acao']}'),
                                      if (l['produto'] != null)
                                        Text('Produto: ${l['produto']}'),
                                      if (l['hora_inicio'] != null &&
                                          l['hora_fim'] != null)
                                        Text(
                                          'Horário: ${l['hora_inicio']} - ${l['hora_fim']}',
                                        ),
                                    ],
                                  ),
                                  trailing: Text('${l['quantidade']} KG'),
                                );
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: _pendentes.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _sincronizando ? null : _enviarTodos,
              icon: _sincronizando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.send, color: Colors.white),
              label: const Text(
                'ENVIAR TUDO AGORA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.green[700],
            )
          : null,
    );
  }
}
