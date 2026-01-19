import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Use http://10.0.2.2:5000 for Android Emulator
  // Use http://localhost:5000 for iOS Simulator / Web
  // Use your machine's IP address for physical devices
  static const String baseUrl = 'http://localhost:5000/api/auth';

  Future<Map<String, dynamic>> signup({
    required String firstName,
    required String lastName,
    required String username,
    required String dob,
    required String gender,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'dob': dob,
        'gender': gender,
        'email': email,
        'mobile': mobile,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Signup failed');
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Login failed');
    }
  }
}
