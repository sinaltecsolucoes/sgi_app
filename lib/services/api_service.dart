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
  // DADOS DA EQUIPE (só apontador/admin)
  // ==========================================
  Future<Map<String, dynamic>> getEquipeDados({
    required int apontadorId,
  }) async {
    final url = await _buildUri('/equipe/dados');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
          _addUserData({
            'apontador_id': apontadorId, // ← ENVIA O ID DO APONTADOR LOGADO
          }),
        ),
      );

      /* final responseBody = jsonDecode(response.body);
      return responseBody;*/
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Erro de rede: $e'};
    }
  }

  // ==========================================
  // SALVAR EQUIPE (só apontador/admin)
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

      final body = {
        'apontador_id': user.id,
        'funcionario_id': user.id, 
        'funcionario_tipo': user.tipo,
        'nome_equipe': nomeEquipe,
        'membros_ids': membrosIds,
      };

      print('SALVAR EQUIPE → $body'); // DEBUG

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
  // OPÇÕES DE LANÇAMENTO (ações, produtos, membros)
  // ==========================================
  Future<Map<String, dynamic>> getLancamentoOpcoes() async {
    final url = await _buildUri('/lancamento/opcoes');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );

      final responseBody = jsonDecode(response.body);
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar opções: $e'};
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

      final responseBody = jsonDecode(response.body);
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Erro ao salvar: $e'};
    }
  }

  // ==========================================
  // FUNCIONÁRIOS PARA CHAMADA (só porteiro)
  // ==========================================
  Future<Map<String, dynamic>> getFuncionariosParaChamada() async {
    final url = await _buildUri('/presenca');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({})),
      );

      final responseBody = jsonDecode(response.body);
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Erro ao carregar funcionários: $e'};
    }
  }

  // ==========================================
  // SALVAR CHAMADA (só porteiro)
  // ==========================================
  Future<Map<String, dynamic>> salvarChamada(List<int> presentesIds) async {
    final url = await _buildUri('/presenca/salvar');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(_addUserData({'presentes_ids': presentesIds})),
      );

      final responseBody = jsonDecode(response.body);
      return responseBody;
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

      final responseBody = jsonDecode(response.body);
      return responseBody;
    } catch (e) {
      return {'success': false, 'message': 'Erro ao salvar em massa: $e'};
    }
  }
}
