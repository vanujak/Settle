import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService) {
    _initialize();
  }

  final AuthService _authService;
  AppUser? _currentUser;
  String? _token;
  bool _initializing = true;

  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get initializing => _initializing;

  Future<void> _initialize() async {
    try {
      final session = await _authService.loadPersistedSession();
      if (session != null) {
        _token = session['token'] as String;
        _currentUser = AppUser.fromJson(session['user'] as Map<String, dynamic>);
      }
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final result = await _authService.login(email, password);
    await _completeAuth(result);
  }

  Future<void> register(String name, String email, String password) async {
    final result = await _authService.register(name, email, password);
    await _completeAuth(result);
  }

  Future<void> logout() async {
    await _authService.clearSession();
    _currentUser = null;
    _token = null;
    notifyListeners();
  }

  void loginAsGuest() {
    _currentUser = const AppUser(
      id: 'guest',
      name: 'Guest User',
      email: 'guest@example.com',
    );
    _token = 'guest-token';
    notifyListeners();
  }

  Future<void> _completeAuth(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final userJson = data['user'] as Map<String, dynamic>;
    _token = token;
    _currentUser = AppUser.fromJson(userJson);
    await _authService.persistSession(token: token, user: userJson);
    notifyListeners();
  }
}
