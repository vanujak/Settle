import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static const String baseUrl = 'http://10.0.2.2:3000';
  static final http.Client _client = http.Client();

  static Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query?.map(
      (key, value) => MapEntry(key, value?.toString()),
    ));
  }

  static Future<http.Response> get(
    String path, {
    String? token,
    Map<String, dynamic>? query,
  }) {
    return _client.get(
      _buildUri(path, query),
      headers: _headers(token: token),
    );
  }

  static Future<http.Response> post(
    String path, {
    String? token,
    Map<String, dynamic>? query,
    Object? body,
  }) {
    return _client.post(
      _buildUri(path, query),
      headers: _headers(token: token),
      body: body == null ? null : jsonEncode(body),
    );
  }

  static Future<http.Response> put(
    String path, {
    String? token,
    Map<String, dynamic>? query,
    Object? body,
  }) {
    return _client.put(
      _buildUri(path, query),
      headers: _headers(token: token),
      body: body == null ? null : jsonEncode(body),
    );
  }

  static Future<http.Response> delete(
    String path, {
    String? token,
    Map<String, dynamic>? query,
  }) {
    return _client.delete(
      _buildUri(path, query),
      headers: _headers(token: token),
    );
  }

  static Map<String, String> _headers({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
