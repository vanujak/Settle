import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';

class BillService {
  String get baseUrl => '${Config.apiUrl}/bills';

  Future<void> createBillSplit(String token, String name, List<String> friendIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'friendIds': friendIds,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to create bill split');
    }
  }

  Future<List<dynamic>> getMyBillSplits(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/my?t=${DateTime.now().millisecondsSinceEpoch}'), // Cache bust
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load bills');
    }
  }

  Future<Map<String, dynamic>> getBillDetails(String token, String billId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$billId?t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to load bill details');
    }
  }

  Future<void> addExpense(String token, String billId, String description, double amount, List<Map<String, dynamic>> splitAmong) async {
    final response = await http.post(
      Uri.parse('$baseUrl/$billId/expense'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'description': description,
        'amount': amount,
        'splitAmong': splitAmong,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to add expense');
    }
  }

  Future<void> deleteBillSplit(String token, String billId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$billId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to delete bill');
    }
  }

  Future<void> deleteExpense(String token, String billId, String expenseId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$billId/expense/$expenseId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to delete expense');
    }
  }
}
