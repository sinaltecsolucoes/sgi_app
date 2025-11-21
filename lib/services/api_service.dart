// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'config_service.dart';

class ApiService {
  final AuthProvider auth;
  final ConfigService _configService = ConfigService();

  static const String _apiPrefix = '/sgi_erp/api';

  ApiService(this.auth);

  // ==========================================
  // MÉTODO AUXILIAR: Adiciona dados do usuário em todas as requisições
  // ==========================================
  Map<String, dynamic> _addUserData(Map<String, dynamic> body) {
    if (auth.user != null) {
      body['funcionario_id'] = auth.user!.id;
      body['funcionario_tipo'] = auth.user!.tipo;
    }
    return body;
  }

  // ==========================================
  // Construção da URL com IP local ou produção
  // ==========================================
  Future<Uri> _buildUri(String endpoint) async {
    final baseUrl = await _configService.getBaseUrl();
    return Uri.parse('$baseUrl$_apiPrefix$endpoint');
  }

  // ==========================================
  // LOGIN
  // ==========================================
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = await _buildUri('/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': username, 'senha': password}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'user': responseBody};
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Credenciais inválidas.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
            'Erro de conexão. Verifique o IP em Configurações.\nErro: $e',
      };
    }
  }

  // ==========================================
  // DADOS DA EQUIPE (usa _addUserData + headers + POST)
  // ==========================================
  Future<Map<String, dynamic>> getEquipeDados({
    required int apontadorId,
  }) async {
    final url = await _buildUri('/equipe/dados');

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (auth.token != null) {
        headers['Authorization'] = 'Bearer ${auth.token}';
      }

      final body = _addUserData({'apontador_id': apontadorId});

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        String msg = 'Erro ${response.statusCode}';
        try {
          final err = jsonDecode(response.body);
          msg = err['message'] ?? msg;
        } catch (_) {}
        return {'success': false, 'message': msg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de rede: $e'};
    }
  }

  // ==========================================
  // SALVAR EQUIPE
  // ==========================================
  Future<Map<String, dynamic>> salvarEquipe(
    String nomeEquipe,
    List<int> membrosIds,
  ) async {
    final url = await _buildUri('/equipe/salvar');
    try {
      final user = auth.user;
      if (user == null) {
        return {'success': false, 'message': 'Usuário não autenticado.'};
      }

      final body = _addUserData({
        'apontador_id': user.id,
        'nome_equipe': nomeEquipe,
        'membros_ids': membrosIds,
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(response.body);
      return {
        'success': responseBody['success'] ?? false,
        'message': responseBody['message'] ?? 'Erro ao salvar.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // ==========================================
  // SALVAR LANÇAMENTO INDIVIDUAL
  // ==========================================
  Future<Map<String, dynamic>> salvarLancamento(
    int funcionarioId,
    int acaoId,
    int produtoId,
    String lote,
    double quantidadeKg,
    String horaInicio,
    String horaFim,
  ) async {
    final url = await _buildUri('/lancamento/salvar');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          _addUserData({
            'funcionario_id': funcionarioId,
            'acao_id': acaoId,
            'tipo_produto_id': produtoId,
            'lote_produto': lote,
            'quantidade_kg': quantidadeKg,
            'hora_inicio': horaInicio,
            'hora_fim': horaFim,
          }),
        ),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro ao salvar: $e'};
    }
  }

  // ==========================================
  // FUNCIONÁRIOS PARA CHAMADA
  // ==========================================
  Future<Map<String, dynamic>> getFuncionariosParaChamada() async {
    final url = await _buildUri('/presenca');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar funcionários: $e'};
    }
  }

  // ==========================================
  // SALVAR CHAMADA
  // ==========================================
  Future<Map<String, dynamic>> salvarChamada(List<int> presentesIds) async {
    final url = await _buildUri('/presenca/salvar');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({'presentes_ids': presentesIds})),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro ao salvar chamada: $e'};
    }
  }

  // ==========================================
  // SALVAR LANÇAMENTO EM MASSA
  // ==========================================
  Future<Map<String, dynamic>> salvarLancamentoMassa(
    List<Map<String, dynamic>> lancamentos,
  ) async {
    final url = await _buildUri('/lancamento/salvar-massa');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({'lancamentos': lancamentos})),
      );

      final Map<String, dynamic> decoded = jsonDecode(response.body);

      // Garante que sempre retorne 'success' como bool
      if (response.statusCode == 200 && decoded['success'] == true) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Salvo com sucesso!',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Erro ao salvar no servidor.',
        };
      }
    } catch (e) {
      // Qualquer erro de rede = offline
      return {
        'success': false,
        'message': 'Sem conexão com o servidor.',
        'offline': true, // ← sinaliza que foi erro de rede
      };
    }
  }

  // ==========================================
  // BUSCAR EQUIPES DE OUTROS APONTADORES
  // ==========================================
  Future<List<Map<String, dynamic>>> buscarEquipesOutrosApontadores() async {
    final url = await _buildUri('/equipes/outros');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );
      final data = jsonDecode(response.body);
      return data['success'] == true
          ? List<Map<String, dynamic>>.from(data['equipes'])
          : [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // BUSCAR EQUIPES DE OUTROS APONTADORES
  // ==========================================
  Future<List<Map<String, dynamic>>> buscarTodasEquipesAtivas() async {
    final url = await _buildUri('/equipes/todas-ativas');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success']) {
        return List<Map<String, dynamic>>.from(data['equipes'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // MOVER MEMBRO
  // ==========================================
  Future<Map<String, dynamic>> moverMembro({
    required int membroId,
    required int equipeOrigemId,
    required int equipeDestinoId,
  }) async {
    final url = await _buildUri('/equipes/mover-membro');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          _addUserData({
            'membro_id': membroId,
            'equipe_origem_id': equipeOrigemId,
            'equipe_destino_id': equipeDestinoId,
          }),
        ),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // ==========================================
  // RETIRAR MEMBRO
  // ==========================================
  Future<Map<String, dynamic>> retirarMembro({
    required int equipeId,
    required int membroId,
  }) async {
    final url = await _buildUri('/equipes/retirar-membro');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          _addUserData({'equipe_id': equipeId, 'membro_id': membroId}),
        ),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // ==========================================
  // FUNCIONÁRIOS DISPONÍVEIS
  // ==========================================
  Future<List<Map<String, dynamic>>> buscarFuncionariosDisponiveis() async {
    final url = await _buildUri('/equipes/funcionarios-disponiveis');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );
      final data = jsonDecode(response.body);
      return data['success']
          ? List<Map<String, dynamic>>.from(data['funcionarios'])
          : [];
    } catch (e) {
      return [];
    }
  }

  // ==========================================
  // EDITAR EQUIPE
  // ==========================================
  Future<Map<String, dynamic>> editarEquipe({
    required int equipeId,
    required String novoNome,
    required List<int> novosMembrosIds,
  }) async {
    final url = await _buildUri('/equipes/editar');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          _addUserData({
            'equipe_id': equipeId,
            'novo_nome': novoNome,
            'novos_membros_ids': novosMembrosIds,
          }),
        ),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro: $e'};
    }
  }

  // ==========================================
  // EXCLUIR EQUIPE
  // ==========================================
  Future<Map<String, dynamic>> excluirEquipe({required int equipeId}) async {
    final url = await _buildUri('/equipes/excluir');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({'equipe_id': equipeId})),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão'};
    }
  }

  // ==========================================
  // OPÇÕES DE LANÇAMENTO
  // ==========================================
  Future<Map<String, dynamic>> getLancamentoOpcoes() async {
    final url = await _buildUri('/lancamento/opcoes');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar opções: $e'};
    }
  }

  // ==========================================
  // OPÇÕES COMPLETAS (COM EQUIPES)
  // ==========================================
  Future<Map<String, dynamic>> getLancamentoOpcoesCompleto() async {
    final url = await _buildUri('/lancamento/opcoes-completo');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão'};
    }
  }

  // ==========================================
  // BUSCAR MEMBROS DE UMA EQUPE ESPECÍFICA
  // ==========================================
  Future<Map<String, dynamic>> getMembrosEquipe(int equipeId) async {
    final url = await _buildUri('/lancamento/membros-equipe');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({'equipe_id': equipeId})),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar membros'};
    }
  }

  // ==========================================
  // BUSCAR LANÇAMENTOS DO DIA DO APONTADOR (PARA EDIÇÃO)
  // ==========================================
  Future<Map<String, dynamic>> getLancamentosDoDiaApontador(String data) async {
    final url = await _buildUri('/producao/editar-dia');

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (auth.token != null) {
        headers['Authorization'] = 'Bearer ${auth.token}';
      }

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(_addUserData({'data': data})),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return {'success': true, 'lancamentos': json['lancamentos'] ?? []};
        }
      }

      // Se chegar aqui, deu erro
      String msg = 'Erro ao carregar produção';
      try {
        final err = jsonDecode(response.body);
        msg = err['message'] ?? msg;
      } catch (_) {}
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> atualizarLancamentoProducao(
    Map<String, dynamic> dados,
  ) async {
    try {
      final url = await _buildUri('/producao/atualizar');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode(_addUserData(dados)),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Sem conexão'};
    }
  }
}
