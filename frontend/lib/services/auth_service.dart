import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiService.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return _handleAuthResponse(response);
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await ApiService.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    return _handleAuthResponse(response);
  }

  Future<void> persistSession({required String token, required Map<String, dynamic> user}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> loadPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userRaw = prefs.getString(_userKey);
    if (token == null || userRaw == null) return null;
    return {
      'token': token,
      'user': jsonDecode(userRaw) as Map<String, dynamic>,
    };
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Map<String, dynamic> _handleAuthResponse(dynamic response) {
    final statusCode = response.statusCode;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (statusCode >= 200 && statusCode < 300) {
      return data;
    }
    final message = data['message'] ?? 'Authentication failed';
    throw Exception(message);
  }
}
