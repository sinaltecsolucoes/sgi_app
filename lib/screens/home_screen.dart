// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'montar_equipe_screen.dart'; // Reutilizada para 'Chamada'
import 'lancamento_individual_screen.dart';
import 'lancamento_massa_screen.dart';
import 'registro_presenca_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // 1. Novos checks de perfil
    final userType = user?.tipo ?? '';
    final isPorteiro = userType == 'porteiro';
    final isApontadorOuAdmin = userType == 'apontador' || userType == 'admin';

    // O conteúdo da tela só é mostrado para perfis válidos
    final isValidUser = isPorteiro || isApontadorOuAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SGI - Opções Operacionais'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout(); // Ação de logout
            },
          ),
        ],
      ),
      body: Center(
        child: isValidUser
            ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bem-vindo, ${user?.nome ?? 'Usuário'}!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // LÓGICA DE BOTÕES POR PERFIL
                    if (isPorteiro) ...[
                      // REGISTRO DE PRESENÇA (EXCLUSIVO PARA PORTEIRO)
                      _buildActionButton(
                        context,
                        'REALIZAR CHAMADA',
                        Icons.check_box, // Ícone sugestivo para registro
                        () {
                          // Navega para a tela de Montar Equipe,
                          // que permite selecionar funcionários presentes.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const RegistroPresencaScreen(),
                            ),
                          );
                        },
                      ),
                    ],

                    if (isApontadorOuAdmin) ...[
                      // BOTÃO 1: Montar Equipe (para Apontador/Admin)
                      _buildActionButton(
                        context,
                        'Montar Equipe de Produção', // Nome mais claro para a função
                        Icons.groups,
                        () {
                          // Navegar para Montar Equipe
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MontarEquipeScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // BOTÃO 2: Lançamento Individual (para Apontador/Admin)
                      _buildActionButton(
                        context,
                        'Lançamento Individual',
                        Icons.add_task,
                        () {
                          // Navegar para Lançamento Individual
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LancamentoIndividualScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // BOTÃO 3: Lançamento em Massa (para Apontador/Admin)
                      _buildActionButton(
                        context,
                        'Lançamento em Massa',
                        Icons.people_alt,
                        () {
                          // Navegar para Lançamento em Massa
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LancamentoMassaScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              )
            // Acesso Restrito para outros tipos de usuários
            : Text(
                'Acesso Restrito: Seu perfil (${user?.tipo ?? 'N/A'}) não pode usar o App.',
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  // Widget para padronizar os botões
  Widget _buildActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 30),
      label: Text(title, style: const TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
