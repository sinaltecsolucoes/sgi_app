// lib/views/login_view.dart
import 'package:flutter/material.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Controladores para capturar o texto dos campos
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  // Função que será chamada ao clicar em Entrar (simulação por enquanto)
  void _efetuarLogin() {
    String login = _loginController.text;
    String senha = _senhaController.text;

    // TODO:
    // 1. Chamar o serviço de API (a ser criado em 'services/')
    // 2. Verificar a resposta do servidor.

    print('Tentativa de Login: $login com Senha: $senha');

    // Simulação: Se o login for 'apontador.geral', simula sucesso
    if (login == 'apontador.geral' && senha == '123456') {
      // Navegar para a próxima tela (Dashboard/Presença)
      // Substituiremos este 'print' pela navegação real.
      print('Login SIMULADO de Sucesso!');
    } else {
      // Mostrar uma mensagem de erro simples
      print('Login SIMULADO de Falha!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SGI App - Login do Apontador'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          // Permite rolar se o teclado aparecer
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
                keyboardType: TextInputType.emailAddress,
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
                obscureText: true, // Esconde o texto para a senha
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 40),

              // Botão Entrar
              ElevatedButton(
                onPressed: _efetuarLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('ENTRAR', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
