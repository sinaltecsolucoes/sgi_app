// lib/screens/config_screen.dart
import 'package:flutter/material.dart';
import '../services/config_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final TextEditingController _ipController = TextEditingController();
  final ConfigService _configService = ConfigService();

  String _currentSavedIp = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentIp();
  }

  void _loadCurrentIp() async {
    final ip = await _configService.getLocalIp();
    setState(() {
      _currentSavedIp = ip ?? 'Não configurado (Usando Produção)';
      _ipController.text = ip ?? '';
    });
  }

  void _saveIp() async {
    final newIp = _ipController.text.trim();
    if (newIp.isEmpty) {
      await _configService.clearLocalIp();
      _loadCurrentIp();
      _showSnackBar('Conexão resetada! Usando URL de Produção.');
    } else {
      // Adiciona 'http://' se não estiver presente (para evitar erro de Uri)
      final safeIp = newIp.startsWith('http') ? newIp : 'http://$newIp';
      await _configService.saveLocalIp(safeIp);
      _loadCurrentIp();
      _showSnackBar('Novo IP de Teste salvo: $safeIp');
    }
    // O App precisa ser reiniciado para o novo IP ser usado em todas as requisições.
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações de Conexão')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ajuste de IP Local (Para Testes)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),

            Text(
              'URL de Produção: ${ConfigService.productionUrl}',
              style: const TextStyle(color: Colors.blue),
            ),
            const SizedBox(height: 10),
            Text(
              'IP Salvo: $_currentSavedIp',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Novo IP/URL Local (Ex: 10.0.2.2 ou 192.168.1.100)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _saveIp,
              child: const Text('Salvar e Aplicar (Reinicie o App)'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                _ipController.clear();
                _saveIp();
              },
              child: const Text('Resetar para Produção (HTTPS)'),
            ),
          ],
        ),
      ),
    );
  }
}
