// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'config_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controladores para capturar o texto dos campos
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  bool _isLoading = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _efetuarLogin() async {
    // Acessa o AuthProvider e o ApiService (criando uma instância temporária para a chamada)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService(
      authProvider,
    ); // Cria o serviço injetando o provider

    final login = _loginController.text;
    final senha = _senhaController.text;

    if (login.isEmpty || senha.isEmpty) {
      _showSnackBar('Preencha todos os campos.', isError: true);
      return;
    }

    // Inicia o estado de loading
    setState(() => _isLoading = true);

    // Chama a API de Login
    final result = await apiService.login(login, senha);

    // Finaliza o loading
    setState(() => _isLoading = false);

    if (result['success']) {
      // 1. Atualiza o estado global com os dados do usuário (user_model.dart)
      authProvider.loginSuccess(result['user']);

      _showSnackBar(
        'Bem-vindo, ${result['user']['funcionario_nome']}!',
        isError: false,
      );

      // A navegação para a HomeScreen será automática via Widget Principal (main.dart)
    } else {
      _showSnackBar(result['message'] ?? 'Erro desconhecido', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela de login simples e responsiva
    return Scaffold(
      appBar: AppBar(
        title: const Text('SGI App - Login'),
        centerTitle: true,
        // NOVO: Botão de Configurações na AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.settings), // Ícone de configurações
            onPressed: () {
              // Navegar para a tela de configurações (ConfigScreen)
              // Note: ConfigScreen precisa ser importado
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfigScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Acesso do Apontador',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // Campo Login
              TextFormField(
                controller: _loginController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Login',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 20),

              // Campo Senha
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 40),

              // Botão Entrar
              ElevatedButton(
                onPressed: _isLoading ? null : _efetuarLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('ENTRAR', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
