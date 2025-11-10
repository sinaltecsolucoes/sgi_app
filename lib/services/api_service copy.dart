// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'config_service.dart'; // Importamos o serviço de configuração
import '../models/acao_model.dart';
import '../models/produto_model.dart';

class ApiService {
  final AuthProvider auth;
  // Instância do serviço de configuração para buscar a URL base
  final ConfigService _configService = ConfigService();

  static const String _apiPrefix = '/sgi_erp/api';
  static const String _equipeSalvarPath =
      '/equipe/salvar'; // Apenas o path do endpoint

  ApiService(this.auth);

  /// Método auxiliar para construir a URL completa com o endpoint
  Future<Uri> _buildUri(String endpoint) async {
    // Retorna 'https://sgierp.ddns.net' ou 'http://10.0.2.2'
    final baseUrl = await _configService.getBaseUrl();

    // Constrói a URL final (Ex: https://sgierp.ddns.net/sgi_erp/api/login)
    return Uri.parse(baseUrl + _apiPrefix + endpoint);
  }

  /// Lida com a requisição de Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = await _buildUri('/login'); // Usa o helper para URL dinâmica

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
          'message':
              responseBody['message'] ?? 'Falha de autenticação desconhecida.',
        };
      }
    } catch (e) {
      // Esta mensagem será útil para o usuário ajustar o IP na tela de Configurações
      return {
        'success': false,
        'message':
            'Erro de conexão ou rede. Verifique o IP em Configurações. Erro: $e',
      };
    }
  }

  /// Registra a presença do funcionário logado
  Future<Map<String, dynamic>> registerPresence() async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    final url = await _buildUri('/presenca'); // Usa o helper para URL dinâmica

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'funcionario_id': auth.user!.id}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Falha ao registrar presença.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao registrar presença: $e',
      };
    }
  }

  /// Busca os dados da equipe
  Future<Map<String, dynamic>> getEquipeDados() async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    // O ID do apontador é necessário para a API filtrar a equipe atual
    final apontadorId = auth.user!.id;

    final url = await _buildUri('/equipe/dados');

    try {
      // Usa http.post e envia o ID do apontador
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        // ENVIAMOS o corpo JSON com o ID do apontador logado
        body: jsonEncode({'apontador_id': apontadorId}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {
          'success': true,
          'data': responseBody,
        }; // API retorna dados no root, não em 'data'
      } else {
        return {
          'success': false,
          'message':
              responseBody['message'] ?? 'Falha ao carregar dados da equipe.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao carregar dados da equipe: $e',
      };
    }
  }

  /// Salva a equipe montada pelo apontador
  Future<Map<String, dynamic>> salvarEquipe(
    String nomeEquipe,
    List<int> membrosIds,
  ) async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    final url = await _buildUri(_equipeSalvarPath);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apontador_id': auth.user!.id,
          'nome_equipe': nomeEquipe,
          'membros_ids': membrosIds, // Array de IDs
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Falha ao salvar equipe.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de rede ao salvar equipe: $e'};
    }
  }

  /// Busca as opções necessárias para a tela de Lançamento Individual.
  /// Membros da equipe, ações e produtos (com flag usaLote).
  Future<Map<String, dynamic>> getLancamentoOpcoes() async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    final apontadorId = auth.user!.id;
    final url = await _buildUri('/lancamento/opcoes'); // Rota da API

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apontador_id': apontadorId,
        }), // API espera o ID do apontador
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        // 1. Mapeia Ações
        final List<AcaoModel> acoes = (responseBody['acoes'] as List)
            .map((json) => AcaoModel.fromJson(json))
            .toList();

        // 2. Mapeia Produtos
        final List<ProdutoModel> produtos = (responseBody['produtos'] as List)
            .map((json) => ProdutoModel.fromJson(json))
            .toList();

        // 3. Retorna os dados prontos para a tela (incluindo membros e equipe_id)
        return {
          'success': true,
          'equipe_id': responseBody['equipe_id'],
          'membros': responseBody['membros'], // FuncionárioMembro
          'acoes': acoes,
          'produtos': produtos,
        };
      } else {
        return {
          'success': false,
          'message':
              responseBody['message'] ??
              'Falha ao carregar opções de lançamento.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao carregar opções: $e',
      };
    }
  }

  /// Salva um lançamento de produção individual.
  Future<Map<String, dynamic>> salvarLancamentoIndividual({
    required int funcionarioId,
    required int acaoId,
    required int produtoId,
    required String lote,
    required double quantidadeKg,
    required String horaInicio,
    required String horaFim,
  }) async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    final url = await _buildUri('/lancamento/salvar'); // Rota da API

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          // Parâmetros que a API PHP espera
          'apontador_id': auth.user!.id,
          'funcionario_id': funcionarioId,
          'acao_id': acaoId,
          'tipo_produto_id': produtoId,
          'lote_produto': lote,
          'quantidade_kg': quantidadeKg,
          'hora_inicio': horaInicio,
          'hora_fim': horaFim,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Falha ao salvar lançamento.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao salvar lançamento: $e',
      };
    }
  }

  /// Busca todos os funcionários de produção com status de presença.
  Future<Map<String, dynamic>> getFuncionariosParaChamada() async {
    final url = await _buildUri('/presenca/funcionarios'); 

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        // Não precisa de corpo (POST vazio, pois busca todos)
        body: jsonEncode({}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {
          'success': true,
          'funcionarios': responseBody['funcionarios'], // Lista de Map
        };
      } else {
        return {
          'success': false,
          'message':
              responseBody['message'] ?? 'Falha ao carregar lista de chamada.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao carregar funcionários: $e',
      };
    }
  }

  /// Salva a lista de IDs presentes no novo endpoint do App.
  Future<Map<String, dynamic>> salvarChamada(List<int> presentesIds) async {
    final url = await _buildUri('/presenca/salvar'); 

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'presentes_ids': presentesIds, // Envia apenas a lista de IDs
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'message': responseBody['message']};
      } else {
        return {
          'success': false,
          'message': responseBody['message'] ?? 'Falha ao salvar chamada.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro de rede ao salvar chamada: $e',
      };
    }
  }
}
