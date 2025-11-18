// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'registro_presenca_screen.dart';
import 'gerenciar_equipes_screen.dart';
import 'lancamento_individual_screen.dart';
import 'lancamento_massa_screen.dart';
import 'lancamentos_pendentes_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        body: Center(child: Text('Erro: Usuário não encontrado')),
      );
    }

    final tipo = user.tipo.toLowerCase();
    final isPorteiro = tipo == 'porteiro';
    final isApontadorOuAdmin = ['apontador', 'admin'].contains(tipo);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.factory, size: 28),
            SizedBox(width: 12),
            Text('NAUTILUS App', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmarLogout(context, authProvider),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ==================== PORTEIRO ====================
              if (isPorteiro) ...[
                const Icon(Icons.front_hand, size: 80, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  'Olá, ${user.nome.split(' ').first}!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vamos ver quem veio hoje?',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                _buildBotaoGrande(
                  context: context,
                  titulo: 'REALIZAR CHAMADA',
                  subtitulo: 'Registrar presença dos funcionários',
                  icone: Icons.how_to_reg,
                  cor: Colors.green[700]!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroPresencaScreen(),
                    ),
                  ),
                ),
              ]
              // ==================== APONTADOR / ADMIN ====================
              else if (isApontadorOuAdmin) ...[
                const Icon(Icons.waving_hand, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Olá, ${user.nome.split(' ').first}!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seja bem-vindo ao controle da produção',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                _buildBotao(
                  context: context,
                  titulo: 'MINHAS EQUIPES',
                  icone: Icons.groups,
                  cor: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GerenciarEquipesScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
               /* _buildBotao(
                  context: context,
                  titulo: 'LANÇAMENTO INDIVIDUAL',
                  icone: Icons.person_add,
                  cor: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LancamentoIndividualScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),*/
                _buildBotao(
                  context: context,
                  titulo: 'LANÇAMENTOS PRODUÇÃO',
                  icone: Icons.group_add,
                  cor: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LancamentoMassaScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<int>(
                  future: _getQuantidadePendentes(),
                  builder: (context, snapshot) {
                    final qtd = snapshot.data ?? 0;
                    return _buildBotao(
                      context: context,
                      titulo: 'LANÇAMENTOS OFFLINE',
                      icone: Icons.cloud_off,
                      cor: qtd > 0 ? Colors.red[700]! : Colors.grey[600]!,
                      badge: qtd > 0 ? '$qtd' : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LancamentosPendentesScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ]
              // ==================== PERFIL SEM ACESSO ====================
              else ...[
                const Icon(Icons.lock, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Acesso não autorizado',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seu perfil não tem permissão para usar este aplicativo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Botão gigante pro porteiro
  Widget _buildBotaoGrande({
    required BuildContext context,
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 140,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 50, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitulo,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Botão padrão dos apontadores
  Widget _buildBotao({
    required BuildContext context,
    required String titulo,
    required IconData icone,
    required Color cor,
    String? badge,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
        ),
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 32, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                right: 16,
                top: 12,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white,
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<int> _getQuantidadePendentes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('lancamentos_pendentes') ?? []).length;
  }

  void _confirmarLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              authProvider.logout();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
