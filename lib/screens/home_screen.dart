// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user; // O tipo é UserModel?

    // Acesso direto às propriedades do objeto user.tipo (user?.tipo)
    final isApontador = user?.tipo == 'apontador' || user?.tipo == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SGI - Opções Operacionais'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
            },
          ),
        ],
      ),
      body: Center(
        child: isApontador
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Bem-vindo, ${user?.nome ?? 'Apontador'}!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 40),

                    // BOTÃO 1: Montar Equipe
                    _buildActionButton(
                      context,
                      'Montar Equipe',
                      Icons.group,
                      () {
                        // TODO: Navegar para Montagem de Equipe
                      },
                    ),
                    const SizedBox(height: 15),

                    // BOTÃO 2: Lançamento Individual
                    _buildActionButton(
                      context,
                      'Lançamento Individual',
                      Icons.person,
                      () {
                        // TODO: Navegar para Lançamento Individual
                      },
                    ),
                    const SizedBox(height: 15),

                    // BOTÃO 3: Lançamento em Massa
                    _buildActionButton(
                      context,
                      'Lançamento em Massa',
                      Icons.people_alt,
                      () {
                        // TODO: Navegar para Lançamento em Massa
                      },
                    ),
                  ],
                ),
              )
            // Acesso à propriedade 'tipo'
            : Text(
                'Acesso Restrito: Seu perfil (${user?.tipo ?? 'N/A'}) não pode usar o App.',
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
