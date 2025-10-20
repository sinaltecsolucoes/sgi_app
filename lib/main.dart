// lib/main.dart
import 'package:flutter/material.dart';
import 'views/login_view.dart'; // Importa a nossa tela de Login

void main() {
  runApp(const SgiApp());
}

class SgiApp extends StatelessWidget {
  const SgiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SGI App - Produção',
      debugShowCheckedModeBanner: false, // Remove a faixa 'Debug'
      theme: ThemeData(
        primarySwatch: Colors.blueGrey, // Uma cor neutra para o tema
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginView(), // Define a primeira tela
    );
  }
}
