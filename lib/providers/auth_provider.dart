// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  UserModel? _user;

  bool get isLoggedIn => _isLoggedIn;
  UserModel? get user => _user;

  // Getter para expor o token do usuário (ajuste o nome do campo se necessário)
  String? get token => _user?.token;

  static const String _userKey = 'sgi_user_data';

  AuthProvider() {
    _loadUserFromStorage();
  }

  void _loadUserFromStorage() async {
    final userDataJson = await _storage.read(key: _userKey);

    if (userDataJson != null) {
      try {
        final userData = jsonDecode(userDataJson);
        _user = UserModel.fromJson(userData);
        _isLoggedIn = true;
      } catch (e) {
        logout();
      }
    }
    notifyListeners();
  }

  void loginSuccess(Map<String, dynamic> userData) async {
    final userModel = UserModel.fromJson(userData);

    _isLoggedIn = true;
    _user = userModel;

    await _storage.write(key: _userKey, value: jsonEncode(userModel.toJson()));
    notifyListeners();
  }

  void logout() async {
    _isLoggedIn = false;
    _user = null;
    await _storage.delete(key: _userKey);
    notifyListeners();
  }
}
