// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart'; 

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const SgiApp(),
    ),
  );
}

class SgiApp extends StatelessWidget {
  const SgiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuta o estado do AuthProvider para decidir qual tela mostrar
    final authProvider = Provider.of<AuthProvider>(context);

    return MaterialApp(
      title: 'NAUTILUS App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Roteamento baseado no estado de login
      home: authProvider.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
