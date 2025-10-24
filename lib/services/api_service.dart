// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import 'config_service.dart';

class ApiService {
  final AuthProvider auth;
  final ConfigService _configService = ConfigService();

  ApiService(this.auth);

  /// Lida com a requisição de Login
  Future<Map<String, dynamic>> login(String username, String password) async {
    final baseUrl = await _configService.getBaseUrl();
    final url = Uri.parse(
      baseUrl + ConfigService.apiPrefix + '/login',
    ); // URL Dinâmica

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
      return {
        'success': false,
        'message':
            'Erro de rede ou JSON. Verifique o IP em Configurações. Erro: $e',
      };
    }
  }
}
