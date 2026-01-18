import 'dart:convert';

import 'api_service.dart';

class GroupService {
  Future<List<dynamic>> fetchGroups(String token) async {
    final response = await ApiService.get('/groups', token: token);
    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> createGroup(
    String token, {
    required String name,
    String? description,
    required List<String> memberIds,
  }) async {
    final response = await ApiService.post(
      '/groups',
      token: token,
      body: {
        'name': name,
        'description': description,
        'memberIds': memberIds,
      },
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> fetchGroupDetails(
    String token,
    String groupId,
  ) async {
    final response = await ApiService.get('/groups/$groupId', token: token);
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> addExpense(
    String token,
    String groupId,
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiService.post(
      '/groups/$groupId/expenses',
      token: token,
      body: payload,
    );
    return _handleMapResponse(response);
  }

  Future<Map<String, dynamic>> updateExpense(
    String token,
    String groupId,
    String expenseId,
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiService.put(
      '/groups/$groupId/expenses/$expenseId',
      token: token,
      body: payload,
    );
    return _handleMapResponse(response);
  }

  Future<void> deleteExpense(
    String token,
    String groupId,
    String expenseId,
  ) async {
    final response = await ApiService.delete(
      '/groups/$groupId/expenses/$expenseId',
      token: token,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final message = data['message'] ?? 'Failed to delete expense';
      throw Exception(message);
    }
  }

  Future<List<dynamic>> fetchBalances(
    String token,
    String groupId,
  ) async {
    final response = await ApiService.get('/groups/$groupId/balances', token: token);
    return _handleListResponse(response);
  }

  List<dynamic> _handleListResponse(dynamic response) {
    final statusCode = response.statusCode;
    final data = jsonDecode(response.body);
    if (statusCode >= 200 && statusCode < 300) {
      return data as List<dynamic>;
    }
    final message = data is Map<String, dynamic> ? data['message'] : null;
    throw Exception(message ?? 'Request failed');
  }

  Map<String, dynamic> _handleMapResponse(dynamic response) {
    final statusCode = response.statusCode;
    final data = jsonDecode(response.body);
    if (statusCode >= 200 && statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    final message = data is Map<String, dynamic> ? data['message'] : null;
    throw Exception(message ?? 'Request failed');
  }
}
