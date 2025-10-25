// test/widget_test.dart
//import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sgi_app/main.dart';
import 'package:sgi_app/providers/auth_provider.dart';
import 'package:sgi_app/screens/login_screen.dart';

void main() {
  testWidgets('SgiApp shows LoginScreen when not logged in', (
    WidgetTester tester,
  ) async {
    // Cria um AuthProvider mockado com estado inicial de não logado
    final authProvider = AuthProvider();

    // Constrói o aplicativo com o AuthProvider
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => authProvider,
        child: const SgiApp(),
      ),
    );

    // Aguarda a renderização
    await tester.pumpAndSettle();

    // Verifica se a LoginScreen é exibida (baseado em algum elemento único da tela)
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('SGI App Mobile'),
      findsOneWidget,
    ); // Ajuste conforme o conteúdo real da LoginScreen
  });
}
