// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'registro_presenca_screen.dart';
import 'gerenciar_equipes_screen.dart';
import 'lancamento_individual_screen.dart';
import 'lancamento_massa_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return _buildAcessoRestrito(context, '');
    }

    final tipo = user.tipo.toLowerCase();

    // === ACL: DEFINE QUAIS BOTÕES MOSTRAR ===
    final bool isPorteiro = tipo == 'porteiro';
    final bool isApontadorOuAdmin = ['apontador', 'admin'].contains(tipo);
    final bool isProducao = tipo == 'producao';

    // Validação de perfil
    if (!isPorteiro && !isApontadorOuAdmin && !isProducao) {
      return _buildAcessoRestrito(context, tipo);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SGI App'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmarLogout(context, authProvider),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === SAUDAÇÃO ===
            Text(
              'Olá, ${user.nome.split(' ').first}!',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // === BOTÕES POR PERFIL ===
            if (isPorteiro) ...[
              _buildBotaoGrande(
                context: context,
                titulo: 'REALIZAR CHAMADA',
                icone: Icons.how_to_reg,
                cor: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegistroPresencaScreen(),
                  ),
                ),
              ),
            ] else if (isApontadorOuAdmin) ...[
              _buildBotaoGrande(
                context: context,
                titulo: 'MINHAS EQUIPES',
                icone: Icons.groups, // ícone mais adequado
                cor: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GerenciarEquipesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildBotaoGrande(
                context: context,
                titulo: 'LANÇAMENTO INDIVIDUAL',
                icone: Icons.person_add_alt_1,
                cor: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LancamentoIndividualScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildBotaoGrande(
                context: context,
                titulo: 'LANÇAMENTO EM MASSA',
                icone: Icons.people_alt,
                cor: Colors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LancamentoMassaScreen(),
                  ),
                ),
              ),
            ] else if (isProducao) ...[
              // === FUTURO: RELATÓRIOS ===
              _buildBotaoGrande(
                context: context,
                titulo: 'TOTAL PRODUZIDO',
                icone: Icons.bar_chart,
                cor: Colors.teal,
                onTap: () => _emBreve(context),
              ),
              const SizedBox(height: 16),
              _buildBotaoGrande(
                context: context,
                titulo: 'TOTAL PAGAMENTO',
                icone: Icons.attach_money,
                cor: Colors.amber,
                onTap: () => _emBreve(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // === WIDGETS AUXILIARES ===
  Widget _buildBotaoGrande({
    required BuildContext context,
    required String titulo,
    required IconData icone,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icone, size: 32),
      label: Text(
        titulo,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: cor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  Widget _buildAcessoRestrito(BuildContext context, String tipo) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Acesso Restrito',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Seu perfil ($tipo) não tem permissão para usar este app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Provider.of<AuthProvider>(context, listen: false).logout(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _emBreve(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidade em desenvolvimento')),
    );
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
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
