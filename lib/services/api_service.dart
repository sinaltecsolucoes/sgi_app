// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'config_service.dart'; // Importamos o serviço de configuração

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
  /*  Future<Map<String, dynamic>> getEquipeDados() async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    final url = await _buildUri('/equipe/dados');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == true) {
        return {'success': true, 'data': responseBody['data']};
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
*/

  /// Busca os dados da equipe
  Future<Map<String, dynamic>> getEquipeDados() async {
    if (auth.user == null) {
      return {'success': false, 'message': 'Usuário não autenticado.'};
    }

    // O ID do apontador é necessário para a API filtrar a equipe atual
    final apontadorId = auth.user!.id;

    final url = await _buildUri('/equipe/dados');

    try {
      // MUDANÇA: Usar http.post e enviar o ID do apontador
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
    /* final baseUrl = await _configService.getBaseUrl();
    final url = Uri.parse(baseUrl + equipeSalvarUrl);*/

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
}
