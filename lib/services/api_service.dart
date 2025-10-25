// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'config_service.dart'; // Importamos o serviço de configuração

class ApiService {
  
  final AuthProvider auth;
  // Instância do serviço de configuração para buscar a URL base
  final ConfigService _configService = ConfigService(); 
  
  ApiService(this.auth);

  /// Método auxiliar para construir a URL completa com o endpoint
  Future<Uri> _buildUri(String endpoint) async {
    // Retorna 'https://sgierp.ddns.net' ou 'http://10.0.2.2'
    final baseUrl = await _configService.getBaseUrl(); 
    
    // Constrói a URL final (Ex: https://sgierp.ddns.net/sgi_erp/api/login)
    return Uri.parse(baseUrl + ConfigService.apiPrefix + endpoint);
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
          'message': responseBody['message'] ?? 'Falha de autenticação desconhecida.',
        };
      }
    } catch (e) {
      // Esta mensagem será útil para o usuário ajustar o IP na tela de Configurações
      return {
        'success': false,
        'message': 'Erro de conexão ou rede. Verifique o IP em Configurações. Erro: $e',
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
          'message':
              responseBody['message'] ?? 'Falha ao registrar presença.',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de rede ao registrar presença: $e'};
    }
  }
}