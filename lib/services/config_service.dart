// lib/services/config_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  // Chave do storage para o IP de teste local
  static const String _localIpKey = 'local_base_ip';

  // URL de Produção (que será usada se o _localIpKey estiver vazio)
  static const String productionUrl = 'https://sgierp.ddns.net';

  // Prefixo da API (fixo)
  static const String apiPrefix = '/sgi_erp/api';

  // Busca o IP de teste salvo. Retorna nulo se não houver.
  Future<String?> getLocalIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localIpKey);
  }

  // Salva o novo IP local informado pelo usuário
  Future<void> saveLocalIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localIpKey, ip);
  }

  // Limpa o IP local (voltando para o de produção)
  Future<void> clearLocalIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localIpKey);
  }

  // Retorna a URL Base correta (IP Local ou Produção)
  Future<String> getBaseUrl() async {
    final localIp = await getLocalIp();

    // Se o IP local foi salvo (para testes), usamos ele
    if (localIp != null && localIp.isNotEmpty) {
      return localIp;
    }
    // Caso contrário, usamos o endereço de produção
    return productionUrl;
  }
}
